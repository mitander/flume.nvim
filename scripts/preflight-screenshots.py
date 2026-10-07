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


def theme_inputs(schema: str) -> dict[str, str]:
    paths = [ROOT / "lua/flume/init.lua", ROOT / "lua/flume/palette.lua"]
    paths += sorted((ROOT / "lua/flume/languages").glob("*.lua"))
    paths.append(ROOT / f"extras/ghostty/flume-{schema}")
    return {str(path.relative_to(ROOT)): digest(path) for path in paths}


def record(schema: str, language: str, runtime_file: Path, kind: str = "syntax", *, image: Path) -> None:
    """Record parser evidence beside a staged VHS image; publication belongs to snapshots."""
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
    if kind in ("selection", "completion"):
        renderer, fixture = "states.lua", "states.go"
        if runtime.get("kind") != kind or runtime.get("diagnostics") != 4 or not runtime.get("diff_text"):
            raise SystemExit("State fixture did not report its diff and diagnostics")
        required_state = "visual" if kind == "selection" else "completion"
        if not runtime.get(required_state):
            raise SystemExit(f"State fixture did not render {required_state}")
    elif kind == "lsp":
        renderer = "lsp-showcase.lua"
        if runtime.get("kind") != kind or not runtime.get("server", {}).get("token_counts"):
            raise SystemExit("LSP fixture did not report semantic tokens")
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
        "theme_inputs": theme_inputs(schema),
    }
    metadata['capture_renderer'] = {
        'name': 'VHS', 'script_sha256': digest(ROOT / 'tests/snapshots/capture.py'),
        'environment_sha256': environment_digest(ROOT),
    }
    if kind != "syntax":
        metadata["kind"] = kind
        metadata["capture_script_sha256"] = digest(ROOT / 'tests/snapshots/capture.py')
        if kind == "lsp":
            metadata["base_renderer_sha256"] = digest(ROOT / "examples/showcase.lua")
            server = runtime["server"]
            metadata["server"] = {key: server[key] for key in ("name", "version", "settings")}
            metadata["server"]["token_counts"] = dict(sorted(server["token_counts"].items()))
            metadata["server_executable_sha256"] = digest(Path(server["executable"]))
        else:
            metadata["runtime_states"] = {
                key: runtime[key] for key in ("diff_text", "diagnostics", "visual", "completion")
            }
    image.with_suffix(".json").write_text(json.dumps(metadata, indent=2) + "\n")


def validate_capture(path: Path) -> tuple[str, str]:
    sidecar = path.with_suffix(".json")
    if not sidecar.exists():
        raise SystemExit(f"{path.name} has no parser-backed capture metadata; recapture it")
    metadata = json.loads(sidecar.read_text())
    language = path.stem
    expected = {'name': 'VHS', 'script_sha256': digest(ROOT / 'tests/snapshots/capture.py'), 'environment_sha256': environment_digest(ROOT)}
    if metadata.get('capture_renderer') != expected:
        raise SystemExit(f'{path.name} has stale VHS capture inputs; recapture it')
    kind = metadata.get("kind", "syntax")
    renderer = "showcase.lua"
    fixture = f"flume.{LANGUAGES[language]}"
    expected_highlighting = "treesitter"
    if kind in ("selection", "completion"):
        renderer, fixture = "states.lua", "states.go"
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
        else:
            states = metadata.get("runtime_states", {})
            required_state = "visual" if kind == "selection" else "completion"
            if not states.get(required_state) or states.get("diagnostics") != 4 or not states.get("diff_text"):
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
    if metadata.get("theme_inputs") != theme_inputs(metadata["schema"]):
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
            if metadata["kind"] == "lsp":
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

    print(f"Screenshot preflight passed: {len(CAPTURES)} captures across {len(LANGUAGES)} language viewports")


if __name__ == "__main__":
    main()
