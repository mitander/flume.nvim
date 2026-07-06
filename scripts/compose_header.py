from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT_DIR = Path(__file__).resolve().parent.parent
BACKGROUND_SOURCE = ROOT_DIR / "scripts" / "assets" / "flume_glitch_bg.jpg"
RAW_SCREENSHOT = ROOT_DIR / "screenshot_raw.png"
BACKGROUND_OUTPUT = ROOT_DIR / "background.png"
SCREENSHOT_OUTPUT = ROOT_DIR / "screenshot.png"

MAX_WINDOW_WIDTH = 0.88
MAX_WINDOW_HEIGHT = 0.86
CORNER_RADIUS = 16
SHADOW_PADDING = 10
SHADOW_OFFSET_Y = 2
SHADOW_COLOR = (12, 10, 18, 30)


def crop_to_opaque_bounds(image):
    alpha = image.split()[-1]
    opaque_mask = alpha.point(lambda p: 255 if p == 255 else 0)
    bounds = opaque_mask.getbbox()
    return image.crop(bounds) if bounds else image


def fit_inside(source_size, target_size):
    source_width, source_height = source_size
    max_width, max_height = target_size
    source_ratio = source_width / source_height

    width = max_width
    height = int(width / source_ratio)

    if height > max_height:
        height = max_height
        width = int(height * source_ratio)

    return width, height


def round_corners(image, radius):
    mask = Image.new("L", image.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, image.width, image.height), radius, fill=255)

    rounded = Image.new("RGBA", image.size)
    rounded.paste(image, (0, 0), mask=mask)
    return rounded


def make_shadow(size, radius):
    width, height = size
    shadow = Image.new(
        "RGBA",
        (width + SHADOW_PADDING * 2, height + SHADOW_PADDING * 2),
        (0, 0, 0, 0),
    )
    draw = ImageDraw.Draw(shadow)
    draw.rounded_rectangle(
        (SHADOW_PADDING, SHADOW_PADDING, SHADOW_PADDING + width, SHADOW_PADDING + height),
        radius,
        fill=SHADOW_COLOR,
    )
    return shadow.filter(ImageFilter.GaussianBlur(2))


def compose_header(background, window):
    max_window_size = (
        int(background.width * MAX_WINDOW_WIDTH),
        int(background.height * MAX_WINDOW_HEIGHT),
    )
    window_size = fit_inside(window.size, max_window_size)
    window = window.resize(window_size, Image.Resampling.LANCZOS)
    window = round_corners(window, CORNER_RADIUS)
    shadow = make_shadow(window_size, CORNER_RADIUS)

    window_x = (background.width - window.width) // 2
    window_y = (background.height - window.height) // 2
    shadow_x = window_x - SHADOW_PADDING
    shadow_y = window_y - SHADOW_PADDING + SHADOW_OFFSET_Y

    background.alpha_composite(shadow, (shadow_x, shadow_y))
    background.alpha_composite(window, (window_x, window_y))
    return background


def main():
    if not RAW_SCREENSHOT.exists():
        raise SystemExit(f"Missing {RAW_SCREENSHOT}. Run scripts/screenshot-window.sh first.")

    background = Image.open(BACKGROUND_SOURCE).convert("RGBA")
    window = Image.open(RAW_SCREENSHOT).convert("RGBA")
    window = crop_to_opaque_bounds(window)

    background.convert("RGB").save(BACKGROUND_OUTPUT, "PNG", optimize=True)
    compose_header(background, window).convert("RGB").save(SCREENSHOT_OUTPUT, "PNG", optimize=True)

    print(f"Saved {SCREENSHOT_OUTPUT}")


if __name__ == "__main__":
    main()
