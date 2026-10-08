"""Compose raw terminal PNG layers without resizing or RGB/YUV conversion."""

from pathlib import Path

from PIL import Image, ImageDraw

FONT_DIRECTORY = Path('/usr/share/fonts/truetype/maple')
FONT_FACES = {
    'normal': ('MapleMono-NF-SemiBold.ttf', 'weight=demibold'),
    'bold': ('MapleMono-NF-Bold.ttf', 'weight=bold'),
    'italic': ('MapleMono-NF-SemiBoldItalic.ttf', 'weight=demibold:slant=italic'),
    'bold_italic': ('MapleMono-NF-BoldItalic.ttf', 'weight=bold:slant=italic'),
}


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
    for index, color in enumerate(((242, 105, 90), (249, 196, 47), (109, 192, 46))):
        x, y, radius = (16 + index * 23) * scale, bar / 2, 7 * scale
        # Shaded buttons retain the native capture's chrome without importing a desktop.
        button = Image.new('RGBA', (2 * radius + 1, 2 * radius + 1))
        pixels = ImageDraw.Draw(button)
        for row in range(button.height):
            brightness = 1.12 - 0.24 * row / (button.height - 1)
            shade = tuple(min(255, round(channel * brightness)) for channel in color)
            pixels.line((0, row, button.width, row), fill=shade)
        button_mask = Image.new('L', (button.width * 4, button.height * 4))
        ImageDraw.Draw(button_mask).ellipse((0, 0, button_mask.width - 1, button_mask.height - 1), fill=255)
        button.putalpha(button_mask.resize(button.size, Image.Resampling.LANCZOS))
        result.alpha_composite(button, (int(x - radius), int(y - radius)))

    # Antialias only the outer silhouette; terminal pixels are never filtered.
    supersampling = 4
    mask = Image.new('L', (size[0] * supersampling, size[1] * supersampling))
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, mask.width - 1, mask.height - 1),
        radius=geometry['corner_radius'] * supersampling, fill=255,
    )
    result.putalpha(mask.resize(size, Image.Resampling.LANCZOS))
    return result
