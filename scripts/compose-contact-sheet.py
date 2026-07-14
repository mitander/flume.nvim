#!/usr/bin/env python3
"""Compose one four-schema native-integration contact sheet."""

from pathlib import Path
import json
import shutil
import struct
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
SCHEMAS = ("dusk", "mira", "opal", "mesa")
LABELS = ("Dusk", "Mira", "Opal", "Mesa")
REQUIRED_METADATA = {
    "app", "app_version", "os", "terminal", "font", "dimensions", "scale",
    "fixture_revision", "capture_date", "unsupported_regions", "manual_action",
}


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as image:
        if image.read(8) != b"\x89PNG\r\n\x1a\n":
            raise SystemExit(f"Not a PNG: {path}")
        image.read(4)
        if image.read(4) != b"IHDR":
            raise SystemExit(f"Missing IHDR: {path}")
        return struct.unpack(">II", image.read(8))


def run(*args: str) -> None:
    subprocess.run(args, check=True)


def main() -> None:
    if len(sys.argv) != 2 or not sys.argv[1].replace("-", "").isalnum():
        raise SystemExit("Usage: compose-contact-sheet.py <app>")
    app = sys.argv[1]
    directory = ROOT / "captures" / app
    images = tuple(directory / f"{schema}.png" for schema in SCHEMAS)
    missing = [path.name for path in images if not path.exists()]
    if missing:
        raise SystemExit(f"Missing {app} captures: " + ", ".join(missing))

    metadata_path = directory / "metadata.json"
    metadata = json.loads(metadata_path.read_text()) if metadata_path.exists() else {}
    missing_metadata = sorted(REQUIRED_METADATA - metadata.keys())
    if missing_metadata:
        raise SystemExit("Missing metadata fields: " + ", ".join(missing_metadata))
    if metadata["app"] != app:
        raise SystemExit(f"metadata app {metadata['app']!r} does not match {app!r}")

    sizes = {png_size(path) for path in images}
    if len(sizes) != 1:
        raise SystemExit(f"Capture dimensions differ: {sizes}")
    magick = shutil.which("magick")
    if not magick:
        raise SystemExit("ImageMagick is required")
    fonts = (
        Path("/System/Library/Fonts/SFNSMono.ttf"),
        Path("/System/Library/Fonts/Menlo.ttc"),
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"),
    )
    font = next((path for path in fonts if path.exists()), None)
    if not font:
        raise SystemExit("A supported monospace font is required")

    with tempfile.TemporaryDirectory(prefix=f"flume-{app}-") as temp_dir:
        temp = Path(temp_dir)
        canvas = temp / "canvas.png"
        run(magick, "-size", "2600x1900", "xc:#1c1b20", str(canvas))
        positions = ((80, 100), (1320, 100), (80, 970), (1320, 970))
        for index, (source, label, (x, y)) in enumerate(zip(images, LABELS, positions)):
            card = temp / f"card-{index}.png"
            run(magick, str(source), "-resize", "1200x830!", str(card))
            run(magick, str(canvas), str(card), "-geometry", f"+{x}+{y}", "-composite", str(canvas))
            run(
                magick, str(canvas), "-fill", "#d9d4df", "-font", str(font),
                "-pointsize", "30", "-gravity", "northwest", "-annotate",
                f"+{x}+{y - 42}", label, str(canvas),
            )
        run(magick, str(canvas), "-strip", "PNG24:" + str(directory / "contact-sheet.png"))

    print(f"Saved {directory / 'contact-sheet.png'}")


if __name__ == "__main__":
    main()
