#!/usr/bin/env python3
"""Validate canonical screenshot inputs before release composition."""

import argparse
import hashlib
import json
import re
import shutil
import struct
import subprocess
import sys
from collections.abc import Iterable
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'tests/snapshots'))
from common import environment_digest

SCHEMAS = ("dusk", "opal", "mira", "mesa")
LANGUAGES = {
    "zig": "zig", "rust": "rs", "tsx": "tsx", "python": "py", "go": "go",
    "elixir": "ex", "toml": "toml",
}
CAPTURES = tuple(
    ROOT / "assets/screenshots" / schema / f"{language}.png"
    for schema in SCHEMAS
    for language in LANGUAGES
)
STALE_TEXT = re.compile(r"feat/|issue[- ]?2|light-schemas|\bzls\b", re.IGNORECASE)
CAPTURE_ERROR = re.compile(r"\bE\d+:\s")


def dimensions(path: Path) -> tuple[int, int]:
    with path.open("rb") as image:
        if image.read(8) != b"\x89PNG\r\n\x1a\n":
            raise ValueError(f"{path.name} is not a PNG")
        length = struct.unpack(">I", image.read(4))[0]
        if image.read(4) != b"IHDR" or length < 8:
            raise ValueError(f"{path.name} has no PNG IHDR")
        return struct.unpack(">II", image.read(8))


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def theme_inputs_digest(schema: str) -> str:
    paths = [ROOT / "lua/flume/init.lua", ROOT / "lua/flume/palette.lua"]
    paths += sorted((ROOT / "lua/flume/languages").glob("*.lua"))
    paths += sorted((ROOT / "queries").rglob("*.scm"))
    paths.append(ROOT / f"extras/ghostty/flume-{schema}")
    # Hash names as well as bytes so additions, removals and renames invalidate captures.
    inputs = {str(path.relative_to(ROOT)): digest(path) for path in paths}
    return hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest()


def capture_inputs() -> dict:
    return {
        'name': 'Ghostty', 'script_sha256': digest(ROOT / 'tests/snapshots/capture.py'),
        'backend_sha256': digest(ROOT / 'tests/snapshots/ghostty.py'),
        'compositor_sha256': digest(ROOT / 'tests/snapshots/render.py'),
        'environment_sha256': environment_digest(ROOT),
        'editor_inputs': {name: digest(ROOT / name) for name in (
            'tests/snapshots/fixtures/neovim.lua', 'tests/snapshots/fixtures/neovim.sh',
            'tests/snapshots/neovim.tape', 'tests/snapshots/common.py',
        )},
    }


def integration_inputs(integration: str) -> dict[str, str]:
    names = {
        'lualine': ('lua/lualine/themes/flume.lua',),
        'neotree': ('tests/snapshots/fixtures/neotree.lua',
                    'tests/snapshots/fixtures/neotree-repository.sh'),
    }[integration]
    return {name: digest(ROOT / name) for name in names}


def validate_integration(integration: str, evidence: dict) -> None:
    if not isinstance(evidence, dict):
        raise SystemExit('Missing editor integration evidence')
    if integration == 'lualine':
        statusline, highlights = evidence.get('statusline'), evidence.get('highlights')
        if (evidence.get('plugin') != 'lualine' or evidence.get('theme') != 'flume'
                or not isinstance(statusline, str) or not statusline.strip()
                or not isinstance(highlights, dict)):
            raise SystemExit('Missing lualine statusline/theme/highlight evidence')
        applied = highlights.get('lualine_a_normal')
        if not isinstance(applied, dict) or not all(
            type(applied.get(channel)) is int and 0 <= applied[channel] <= 0xffffff
            for channel in ('fg', 'bg')
        ):
            raise SystemExit('Missing lualine applied highlight evidence')
    elif (evidence.get('plugin') != 'neo-tree' or evidence.get('source') != 'filesystem'
          or evidence.get('icons') is not True or evidence.get('git_status') is not True
          or evidence.get('selected_file') != 'src/main.go'
          or not isinstance(evidence.get('sidebar_lines'), list)
          or not all(isinstance(line, str) for line in evidence['sidebar_lines'])
          or not all(any(name in line for line in evidence.get('sidebar_lines', []))
                     for name in ('main.go', 'README.md', 'notes.md'))):
        raise SystemExit('Missing Neo-tree sidebar evidence')


def record(schema: str, language: str, runtime_file: Path, kind: str = "syntax", *, image: Path,
           integration: str | None = None, integration_evidence: dict | None = None) -> None:
    """Record parser evidence beside a staged Ghostty image; publication belongs to snapshots."""
    if kind not in ("syntax", "selection", "completion", "lsp"):
        raise SystemExit("Unknown capture kind")
    if schema not in SCHEMAS or language not in LANGUAGES:
        raise SystemExit("Unknown capture schema or language")
    runtime = json.loads(runtime_file.read_text())
    parser = Path(runtime["parser"])
    if runtime["language"] != language:
        raise SystemExit("Runtime metadata does not describe the requested language")
    revision_file = parser.parent.parent / f"parser-info/{language}.revision"
    renderer = "showcase.lua"
    fixture = f"flume.{LANGUAGES[language]}"
    if kind == "selection":
        renderer, fixture = "states.lua", "states.go"
        if runtime.get("kind") != kind or runtime.get("diagnostics") != 4 or not runtime.get("diff_text"):
            raise SystemExit("State fixture did not report its diff and diagnostics")
        if not runtime.get("visual"):
            raise SystemExit("State fixture did not render visual")
    elif kind == "completion":
        renderer, fixture = "completion.lua", "completion.go"
        if runtime.get("kind") != kind or not runtime.get("completion"):
            raise SystemExit("State fixture did not render completion")
        if not runtime.get("server") or not runtime.get("candidates") or not runtime.get("documentation"):
            raise SystemExit("Completion fixture did not report server candidates and documentation")
        if runtime.get("frontend", {}).get("name") != "blink.cmp" or not runtime.get("documentation_highlights"):
            raise SystemExit("Completion fixture did not render Blink highlighted documentation")
    elif kind == "lsp":
        renderer = "lsp-showcase.lua"
        if runtime.get("kind") != kind or not runtime.get("server", {}).get("token_counts"):
            raise SystemExit("LSP fixture did not report semantic tokens")
        if not runtime.get("hover"):
            raise SystemExit("LSP fixture did not report hover documentation")
        if runtime.get("workspace") != f"/tmp/flume-lsp-{language}":
            raise SystemExit("LSP fixture must use a stable isolated workspace")
    metadata = {
        "schema": schema,
        "language": language,
        "highlighting": "treesitter+lsp" if kind == "lsp" else "treesitter",
        "nvim": runtime["nvim"],
        "parser": {
            "revision": revision_file.read_text().strip() if revision_file.exists() else None,
            "sha256": digest(parser),
        },
        "queries": [
            {"path": path.split("/queries/", 1)[-1], "sha256": digest(Path(path))}
            for path in runtime["queries"]
        ],
        "fixture_sha256": digest(ROOT / "examples" / fixture),
        "renderer_sha256": digest(ROOT / "examples" / renderer),
        "image_sha256": digest(image),
        "theme_inputs_sha256": theme_inputs_digest(schema),
    }
    metadata['capture_renderer'] = capture_inputs()
    if integration:
        validate_integration(integration, integration_evidence or {})
        metadata['editor_integration'] = integration_evidence
        metadata['integration_inputs'] = integration_inputs(integration)
    if kind != "syntax":
        metadata["kind"] = kind
        metadata["capture_script_sha256"] = digest(ROOT / 'tests/snapshots/capture.py')
        if kind in ("lsp", "completion"):
            server = runtime["server"]
            metadata["server"] = {key: server[key] for key in ("name", "version", "settings")}
            metadata["server_executable_sha256"] = digest(Path(server["executable"]))
            if kind == "lsp":
                metadata["base_renderer_sha256"] = digest(ROOT / "examples/showcase.lua")
                metadata["server"]["token_counts"] = dict(sorted(server["token_counts"].items()))
                metadata["hover"] = runtime.get("hover", [])
                metadata["workspace"] = runtime["workspace"]
            else:
                metadata["runtime_states"] = {key: runtime[key] for key in ("completion", "candidates", "documentation", "frontend", "documentation_highlights")}
        else:
            metadata["runtime_states"] = {
                key: runtime[key] for key in ("diff_text", "diagnostics", "visual", "completion")
            }
    image.with_suffix(".json").write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n")


def validate_capture(path: Path) -> tuple[str, str]:
    sidecar = path.with_suffix(".json")
    if not sidecar.exists():
        raise SystemExit(f"{path.name} has no parser-backed capture metadata; recapture it")
    metadata = json.loads(sidecar.read_text())
    language = path.stem
    if metadata.get('capture_renderer') != capture_inputs():
        raise SystemExit(f'{path.name} has stale Ghostty capture inputs; recapture it')
    integration = path.parent.parent.name
    if integration in ('lualine', 'neotree'):
        if metadata.get('integration_inputs') != integration_inputs(integration):
            raise SystemExit(f'{path.name} has stale integration inputs; recapture it')
        validate_integration(integration, metadata.get('editor_integration', {}))
    kind = metadata.get("kind", "syntax")
    renderer = "showcase.lua"
    fixture = f"flume.{LANGUAGES[language]}"
    expected_highlighting = "treesitter"
    if kind == "selection":
        renderer, fixture = "states.lua", "states.go"
    elif kind == "completion":
        renderer, fixture = "completion.lua", "completion.go"
    elif kind == "lsp":
        renderer = "lsp-showcase.lua"
        expected_highlighting = "treesitter+lsp"
    elif kind != "syntax":
        raise SystemExit(f"{sidecar.name} has an unknown capture kind")
    if kind != "syntax":
        if path.parent.parent.name != kind:
            raise SystemExit(f"{sidecar.name} has the wrong capture kind")
        if metadata.get("capture_script_sha256") != digest(ROOT / 'tests/snapshots/capture.py'):
            raise SystemExit(f"{path.name} has a stale capture script; recapture it")
        if kind == "lsp":
            if metadata.get("base_renderer_sha256") != digest(ROOT / "examples/showcase.lua"):
                raise SystemExit(f"{path.name} has a stale base renderer; recapture it")
            if not metadata.get("server", {}).get("token_counts") or not metadata.get("server_executable_sha256"):
                raise SystemExit(f"{path.name} has no server token evidence")
            if not metadata.get("hover"):
                raise SystemExit(f"{path.name} has no hover evidence")
            if metadata.get("workspace") != f"/tmp/flume-lsp-{language}":
                raise SystemExit(f"{path.name} has no stable isolated workspace evidence")
        elif kind == "completion":
            states = metadata.get("runtime_states", {})
            if not states.get("completion") or not states.get("candidates") or not states.get("documentation"):
                raise SystemExit(f"{path.name} has incomplete completion evidence")
            if not metadata.get("server") or not metadata.get("server_executable_sha256"):
                raise SystemExit(f"{path.name} has no completion server evidence")
            if states.get("frontend", {}).get("name") != "blink.cmp" or not states.get("documentation_highlights"):
                raise SystemExit(f"{path.name} has no Blink highlighted documentation evidence")
        else:
            states = metadata.get("runtime_states", {})
            if not states.get("visual") or states.get("diagnostics") != 4 or not states.get("diff_text"):
                raise SystemExit(f"{path.name} has incomplete state evidence")
    wrong_capture = (
        metadata["schema"] != path.parent.name
        or metadata.get("language") != language
        or metadata["highlighting"] != expected_highlighting
    )
    if wrong_capture:
        raise SystemExit(f"{sidecar.name} does not describe this Tree-sitter capture")

    for key, source in (
        ("image_sha256", path),
        ("fixture_sha256", ROOT / "examples" / fixture),
        ("renderer_sha256", ROOT / "examples" / renderer),
    ):
        if metadata[key] != digest(source):
            raise SystemExit(f"{path.name} has stale {key}; recapture it")
    if metadata.get("theme_inputs_sha256") != theme_inputs_digest(metadata["schema"]):
        raise SystemExit(f"{path.name} has stale theme inputs; recapture it")

    runtime_identity = {key: metadata[key] for key in ("nvim", "parser", "queries")}
    return language, json.dumps(runtime_identity, sort_keys=True)


def check_capture_text(paths: Iterable[Path], *, check_stale_text: bool = True) -> None:
    tesseract = shutil.which("tesseract")
    if not tesseract:
        raise SystemExit("tesseract is required to check capture text")
    for path in paths:
        result = subprocess.run(
            [tesseract, str(path), "stdout"], text=True, capture_output=True, check=True
        )
        error = CAPTURE_ERROR.search(result.stdout)
        if error:
            raise SystemExit(f"{path.name} contains a Neovim error: {error.group(0).strip()}")
        if check_stale_text:
            match = STALE_TEXT.search(result.stdout)
            if match:
                raise SystemExit(f"{path.name} contains stale capture text: {match.group(0)!r}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-only', action='store_true', help='check current syntax-scene producers without reading images')
    parser.add_argument('--states', action='store_true', help='check selection, completion, and LSP captures')
    parser.add_argument('--ocr', action='store_true', help='also inspect image text with Tesseract')
    args = parser.parse_args()
    if args.states:
        paths = [
            ROOT / "assets/screenshots" / kind / schema / f"{language}.png"
            for kind, languages in (("selection", ("go",)), ("completion", ("go",)), ("lsp", ("go", "zig")))
            for schema in SCHEMAS for language in languages
        ]
        fingerprints: dict[tuple[str, str], set[str]] = {}
        for path in paths:
            if not path.exists():
                raise SystemExit(f"Missing state capture: {path.relative_to(ROOT)}")
            language, identity = validate_capture(path)
            metadata = json.loads(path.with_suffix(".json").read_text())
            if metadata["kind"] in ("lsp", "completion"):
                identity += json.dumps({
                    "server": {key: metadata["server"][key] for key in ("name", "version", "settings")},
                    "executable_sha256": metadata["server_executable_sha256"],
                }, sort_keys=True)
            fingerprints.setdefault((metadata["kind"], language), set()).add(identity)
        if any(len(identities) != 1 for identities in fingerprints.values()):
            raise SystemExit("State captures used different parser/query/server runtimes")
        if len({dimensions(path) for path in paths}) != 1:
            raise SystemExit("State capture dimensions differ")
        if args.ocr:
            # Server names are intentional in these captures, unlike specimens.
            check_capture_text(paths, check_stale_text=False)
        print(f"State capture preflight passed: {len(paths)} captures")
        return
    fixture = (ROOT / "examples/showcase.lua").read_text()
    capture_sources = '\n'.join((ROOT / name).read_text() for name in (
        'tests/snapshots/fixtures/neovim.lua',
        'tests/snapshots/fixtures/neovim.sh',
        'tests/snapshots/neovim.tape',
    ))
    presentation_noise = re.search(
        r"Gitsigns|git branch|\bzls\b|vim\.diagnostic|virtual_text|DiffAdd|Pmenu",
        fixture + capture_sources,
        re.IGNORECASE,
    )
    if presentation_noise:
        raise SystemExit(
            "Screenshot fixture still contains Git/LSP dependencies or presentation noise"
        )

    if "vim.treesitter.start(" not in fixture or "nvim_buf_set_extmark" in fixture:
        raise SystemExit(
            "Canonical screenshots must use real Tree-sitter highlighting, not painted tokens"
        )

    unexpected = [path.name for path in ROOT.glob("screenshot*.png")]
    if unexpected:
        raise SystemExit("Unexpected canonical capture names: " + ", ".join(sorted(unexpected)))

    if args.source_only:
        print("Screenshot source preflight passed")
        return

    missing = [path.name for path in CAPTURES if not path.exists()]
    if missing:
        raise SystemExit("Missing canonical captures: " + ", ".join(missing))

    sizes = {str(path.relative_to(ROOT)): dimensions(path) for path in CAPTURES}
    for language in LANGUAGES:
        language_sizes = {dimensions(path) for path in CAPTURES if path.stem == language}
        if len(language_sizes) != 1:
            raise SystemExit(f"Canonical {language} capture dimensions differ: " + repr(sizes))

    runtime_fingerprints = {language: set() for language in LANGUAGES}
    for path in CAPTURES:
        language, runtime_identity = validate_capture(path)
        runtime_fingerprints[language].add(runtime_identity)
    if any(len(fingerprints) != 1 for fingerprints in runtime_fingerprints.values()):
        raise SystemExit("Canonical captures used different parser/query runtimes")

    if args.ocr:
        check_capture_text(CAPTURES)

    # Compare only the same scene across palettes: integration viewports can differ.
    additional_count = 0
    for family, languages in (("selection", ("go",)), ("completion", ("go",)),
                              ("lsp", ("go", "zig")), ("lualine", ("go",)), ("neotree", ("go",))):
        for language in languages:
            paths = [ROOT / 'assets/screenshots' / family / schema / f'{language}.png'
                     for schema in SCHEMAS]
            identities = set()
            for path in paths:
                if not path.exists():
                    raise SystemExit(f'Missing editor capture: {path.relative_to(ROOT)}')
                _, identity = validate_capture(path)
                metadata = json.loads(path.with_suffix('.json').read_text())
                if family in ('lsp', 'completion'):
                    identity += json.dumps({
                        'server': {key: metadata['server'][key] for key in ('name', 'version', 'settings')},
                        'executable_sha256': metadata['server_executable_sha256'],
                    }, sort_keys=True)
                identities.add(identity)
            if len(identities) != 1:
                raise SystemExit(f'{family} captures used different parser/query/server runtimes')
            if len({dimensions(path) for path in paths}) != 1:
                raise SystemExit(f'{family} capture dimensions differ')
            if args.ocr:
                check_capture_text(paths, check_stale_text=False)
            additional_count += len(paths)

    print(f"Screenshot preflight passed: {len(CAPTURES) + additional_count} editor captures")


if __name__ == "__main__":
    main()
