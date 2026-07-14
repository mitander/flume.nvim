#!/usr/bin/env python3
"""Compose the four-palette README showcase over Flume's original artwork."""

from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "screenshot-showcase.png"
CANVAS = (2800, 1720)
CARD = (1450, 1018)
SOURCES = (
    (ROOT / "screenshot-opal.png", 100, 35),
    (ROOT / "screenshot-mesa.png", 500, 250),
    (ROOT / "screenshot-mira.png", 900, 465),
    (ROOT / "screenshot-dusk.png", 1300, 680),
)


def run(*args: str | Path) -> None:
    subprocess.run([str(arg) for arg in args], check=True)


def main() -> None:
    magick = shutil.which("magick")
    if not magick:
        raise SystemExit("ImageMagick is required to compose the showcase")
    missing = [path.name for path, *_ in SOURCES if not path.exists()]
    if missing:
        raise SystemExit("Missing canonical captures: " + ", ".join(missing))

    with tempfile.TemporaryDirectory(prefix="flume-showcase-") as temp_dir:
        temp = Path(temp_dir)
        canvas = temp / "canvas.png"
        blend = temp / "palette-blend.png"

        # Let the album-art texture show through while the translucent palette
        # foundation preserves a light-to-dark path behind the cascade.
        run(
            magick,
            ROOT / "background.png",
            "-resize", f"{CANVAS[0]}x{CANVAS[1]}^",
            "-gravity", "center",
            "-extent", f"{CANVAS[0]}x{CANVAS[1]}",
            "-modulate", "100,100,100",
            canvas,
        )
        run(magick, "-size", f"{CANVAS[0]}x{CANVAS[1]}", "gradient:#f2eff750-#23213668", blend)
        run(magick, canvas, blend, "-compose", "over", "-composite", canvas)

        for index, (source, x, y) in enumerate(SOURCES):
            card = temp / f"card-{index}.png"
            run(
                magick,
                source,
                "-resize", f"{CARD[0]}x{CARD[1]}!",
                "-bordercolor", "#ffffff22",
                "-border", "2",
                card,
            )
            run(
                magick,
                canvas,
                "(", card, "-background", "#00000078", "-shadow", "48x14+0+16", ")",
                "-geometry", f"+{x}+{y}", "-composite",
                card, "-geometry", f"+{x}+{y}", "-composite",
                canvas,
            )


        run(magick, canvas, "-strip", "PNG24:" + str(OUTPUT))

    print(f"Saved {OUTPUT}")


if __name__ == "__main__":
    main()
