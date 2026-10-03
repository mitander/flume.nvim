#!/usr/bin/env python3
"""Compose the same four-language grid for each Flume palette."""

from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
LANGUAGES = (("rust", "Rust"), ("tsx", "TypeScript / TSX"), ("python", "Python"), ("go", "Go"))


def run(*args: str | Path) -> None:
    subprocess.run([str(arg) for arg in args], check=True)


def main() -> None:
    run("python3", ROOT / "scripts/preflight-screenshots.py")
    magick = shutil.which("magick")
    if not magick:
        raise SystemExit("ImageMagick is required")
    font = next((path for path in (
        Path("/System/Library/Fonts/Menlo.ttc"),
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"),
    ) if path.exists()), None)
    if not font:
        raise SystemExit("A supported monospace font is required")

    for schema in ("dusk", "opal", "mira", "mesa"):
        directory = ROOT / "assets/screenshots" / schema
        with tempfile.TemporaryDirectory(prefix="flume-languages-") as temp_dir:
            temp = Path(temp_dir)
            cards = []
            for language, label in LANGUAGES:
                card = temp / f"{language}.png"
                # Preserve aspect ratio and original application colors.
                run(magick, directory / f"{language}.png", "-resize", "1400x",
                    "-background", "#1c1b20", "-gravity", "north", "-splice", "0x64",
                    "-fill", "#d9d4df", "-font", font, "-pointsize", "30",
                    "-annotate", "+0+12", label, card)
                cards.append(card)
            rows = []
            for index in (0, 2):
                row = temp / f"row-{index}.png"
                run(magick, *cards[index:index + 2], "+append", row)
                rows.append(row)
            output = directory / "languages.png"
            run(magick, *rows, "-append", "-strip", "PNG24:" + str(output))
            print(f"Saved {output}")


if __name__ == "__main__":
    main()
