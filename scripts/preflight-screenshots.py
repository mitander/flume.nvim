#!/usr/bin/env python3
"""Validate canonical screenshot inputs before release composition."""

from pathlib import Path
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


def main() -> None:
    fixture = (ROOT / "examples/showcase.lua").read_text()
    screenshot_script = (ROOT / "scripts/screenshot-window.sh").read_text()
    if re.search(r"Gitsigns|git branch|\bzls\b|vim\.diagnostic|virtual_text|DiffAdd|Pmenu", fixture + screenshot_script, re.IGNORECASE):
        raise SystemExit("Screenshot fixture still contains Git/LSP dependencies or presentation noise")

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
