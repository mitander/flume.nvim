#!/usr/bin/env python3
"""Validate canonical screenshot inputs before release composition."""

from pathlib import Path
import hashlib
import json
import re
import shutil
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
CAPTURES = tuple(ROOT / f"screenshot-{schema}.png" for schema in ("dusk", "opal", "mira", "mesa"))
STALE_TEXT = re.compile(r"feat/|issue[- ]?2|light-schemas|\bzls\b", re.IGNORECASE)


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


def record(schema: str, runtime_file: Path) -> None:
    image = ROOT / f"screenshot-{schema}.png"
    if image not in CAPTURES:
        raise SystemExit("Unknown capture schema: " + schema)
    runtime = json.loads(runtime_file.read_text())
    parser = Path(runtime["parser"])
    revision_file = parser.parent.parent / "parser-info/zig.revision"
    metadata = {
        "schema": schema,
        "highlighting": "treesitter",
        "nvim": runtime["nvim"],
        "parser": {
            "revision": revision_file.read_text().strip() if revision_file.exists() else None,
            "sha256": digest(parser),
        },
        "queries": [
            {"path": path.split("/queries/", 1)[-1], "sha256": digest(Path(path))}
            for path in runtime["queries"]
        ],
        "fixture_sha256": digest(ROOT / "examples/flume.zig"),
        "renderer_sha256": digest(ROOT / "examples/showcase.lua"),
        "image_sha256": digest(image),
        "theme_inputs": theme_inputs(schema),
    }
    image.with_suffix(".json").write_text(json.dumps(metadata, indent=2) + "\n")


def main() -> None:
    if len(sys.argv) == 4 and sys.argv[1] == "--record":
        record(sys.argv[2], Path(sys.argv[3]))
        return
    fixture = (ROOT / "examples/showcase.lua").read_text()
    screenshot_script = (ROOT / "scripts/screenshot-window.sh").read_text()
    if re.search(r"Gitsigns|git branch|\bzls\b|vim\.diagnostic|virtual_text|DiffAdd|Pmenu", fixture + screenshot_script, re.IGNORECASE):
        raise SystemExit("Screenshot fixture still contains Git/LSP dependencies or presentation noise")

    if "vim.treesitter.start(" not in fixture or "nvim_buf_set_extmark" in fixture:
        raise SystemExit("Canonical screenshots must use real Tree-sitter highlighting, not painted tokens")

    expected = {path.resolve() for path in CAPTURES}
    unexpected = [
        path.name
        for path in ROOT.glob("screenshot-*.png")
        if path.name != "screenshot-showcase.png" and path.resolve() not in expected
    ]
    if (ROOT / "screenshot.png").exists():
        unexpected.append("screenshot.png")
    if unexpected:
        raise SystemExit("Unexpected canonical capture names: " + ", ".join(sorted(unexpected)))

    if "--source-only" in sys.argv:
        print("Screenshot source preflight passed")
        return

    missing = [path.name for path in CAPTURES if not path.exists()]
    if missing:
        raise SystemExit("Missing canonical captures: " + ", ".join(missing))
    sizes = {path.name: dimensions(path) for path in CAPTURES}
    if len(set(sizes.values())) != 1:
        raise SystemExit("Canonical capture dimensions differ: " + repr(sizes))

    runtime_fingerprints = set()
    for path in CAPTURES:
        sidecar = path.with_suffix(".json")
        if not sidecar.exists():
            raise SystemExit(f"{path.name} has no parser-backed capture metadata; recapture it")
        metadata = json.loads(sidecar.read_text())
        if metadata["schema"] != path.stem.removeprefix("screenshot-") or metadata["highlighting"] != "treesitter":
            raise SystemExit(f"{sidecar.name} does not describe this Tree-sitter capture")
        for key, source in (
            ("image_sha256", path),
            ("fixture_sha256", ROOT / "examples/flume.zig"),
            ("renderer_sha256", ROOT / "examples/showcase.lua"),
        ):
            if metadata[key] != digest(source):
                raise SystemExit(f"{path.name} has stale {key}; recapture it")
        if metadata.get("theme_inputs") != theme_inputs(metadata["schema"]):
            raise SystemExit(f"{path.name} has stale theme inputs; recapture it")
        runtime_fingerprints.add(json.dumps({key: metadata[key] for key in ("nvim", "parser", "queries")}, sort_keys=True))
    if len(runtime_fingerprints) != 1:
        raise SystemExit("Canonical captures used different parser/query runtimes")

    tesseract = shutil.which("tesseract")
    if not tesseract:
        raise SystemExit("tesseract is required to check captures for stale branch text")
    for path in CAPTURES:
        result = subprocess.run(
            [tesseract, str(path), "stdout"], text=True, capture_output=True, check=True
        )
        match = STALE_TEXT.search(result.stdout)
        if match:
            raise SystemExit(f"{path.name} contains stale capture text: {match.group(0)!r}")

    print(f"Screenshot preflight passed: {len(CAPTURES)} captures at {next(iter(sizes.values()))}")


if __name__ == "__main__":
    main()
