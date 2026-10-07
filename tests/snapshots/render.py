"""Compose raw terminal PNG layers without resizing or RGB/YUV conversion."""

from pathlib import Path

from PIL import Image, ImageDraw

FONT_DIRECTORY = Path('/usr/share/fonts/truetype/maple')
FONT_FACES = {
    'normal': ('MapleMono-NF-Medium.ttf', 'weight=regular'),
    'bold': ('MapleMono-NF-Bold.ttf', 'weight=bold'),
    'italic': ('MapleMono-NF-MediumItalic.ttf', 'weight=regular:slant=italic'),
    'bold_italic': ('MapleMono-NF-BoldItalic.ttf', 'weight=bold:slant=italic'),
}


def last_frame(frames: Path) -> tuple[Path, Path]:
    """Require the final text frame's cursor layer; never reuse an earlier pair."""
    texts = sorted(frames.glob('frame-text-*.png'))
    if not texts:
        raise ValueError('VHS did not retain raw terminal frames')
    text = texts[-1]
    cursor = text.with_name(text.name.replace('frame-text-', 'frame-cursor-', 1))
    for path in (text, cursor):
        if path.is_symlink() or not path.is_file():
            raise ValueError(f'Missing or unsafe terminal layer: {path.name}')
    return text, cursor


def window(text: Image.Image, cursor: Image.Image, theme: dict, geometry: dict) -> Image.Image:
    if text.size != cursor.size:
        raise ValueError('Terminal text and cursor dimensions differ')
    terminal = Image.new('RGBA', text.size, theme['background'])
    terminal = Image.alpha_composite(terminal, text.convert('RGBA'))
    terminal = Image.alpha_composite(terminal, cursor.convert('RGBA'))

    padding, bar = geometry['padding'], geometry['titlebar_height']
    size = (terminal.width + 2 * padding, terminal.height + 2 * padding + bar)
    result = Image.new('RGBA', size, theme['background'])
    result.alpha_composite(terminal, (padding, padding + bar))
    draw = ImageDraw.Draw(result)
    scale = geometry['backing_scale']
    for index, color in enumerate(('#ff5f57', '#febc2e', '#28c840')):
        x, y, radius = (16 + index * 16) * scale, bar / 2, 5 * scale
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)

    # Antialias only the outer silhouette; terminal pixels are never filtered.
    supersampling = 4
    mask = Image.new('L', (size[0] * supersampling, size[1] * supersampling))
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, mask.width - 1, mask.height - 1),
        radius=geometry['corner_radius'] * supersampling, fill=255,
    )
    result.putalpha(mask.resize(size, Image.Resampling.LANCZOS))
    return result
