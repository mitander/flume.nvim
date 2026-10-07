"""Deterministic showcase/contact-sheet composition; never recolor captures."""

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

from common import INTEGRATIONS, SCHEMAS, destination, digest, environment_digest, read_manifest, verify_images

ROOT = Path('/repo')


def contact_sheet(images):
    width, height = images[0].size
    if any(image.size != (width, height) for image in images):
        raise ValueError('Contact-sheet capture dimensions differ')
    sheet = Image.new('RGB', (width * 2 + 72, height * 2 + 144), '#1c1b20')
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf', 24)
    for index, (schema, image) in enumerate(zip(SCHEMAS, images)):
        x, y = 24 + (index % 2) * (width + 24), 60 + (index // 2) * (height + 60)
        draw.text((x, y - 34), schema.title(), font=font, fill='#d9d4df')
        sheet.paste(image.convert('RGB'), (x, y))
    return sheet


def showcase(images):
    size = (2800, 1720)
    with Image.open(ROOT / 'assets/background.png') as artwork:
        canvas = ImageOps.fit(artwork.convert('RGBA'), size, method=Image.Resampling.LANCZOS)
    overlay = Image.new('RGBA', (1, size[1]))
    for y in range(size[1]):
        fraction = y / (size[1] - 1)
        overlay.putpixel((0, y), tuple(round(a + (b - a) * fraction) for a, b in zip((242, 239, 247, 80), (35, 33, 54, 104))))
    canvas = Image.alpha_composite(canvas, overlay.resize(size))
    for image, (x, y) in zip(images, ((100, 35), (500, 250), (900, 465), (1300, 680))):
        card = image.convert('RGBA')
        card.thumbnail((1450, 1018), Image.Resampling.LANCZOS)
        # Resize up as well as down, preserving the terminal's aspect ratio.
        card = image.convert('RGBA').resize((1450, round(image.height * 1450 / image.width)), Image.Resampling.LANCZOS)
        shadow = Image.new('RGBA', size)
        ImageDraw.Draw(shadow).rectangle((x, y + 16, x + card.width, y + card.height + 16), fill=(0, 0, 0, 90))
        canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(14)))
        canvas.alpha_composite(card, (x, y))
    return canvas.convert('RGB')


def compose(actual, baseline, cases):
    captured, recorded = read_manifest(actual), read_manifest(baseline)
    derived = []
    for app in INTEGRATIONS:
        if any(case.startswith(app + '-') for case in cases):
            derived.append(('contact-' + app, [f'{app}-{schema}' for schema in SCHEMAS], contact_sheet))
    if any(case.startswith('neovim-zig-') for case in cases):
        derived.append(('showcase', [f'neovim-zig-{schema}' for schema in ('opal', 'mesa', 'mira', 'dusk')], showcase))
    for name, sources, renderer in derived:
        images, inputs = [], {}
        try:
            environments = set()
            for case in sources:
                directory, manifest = (actual, captured) if case in captured['cases'] else (baseline, recorded)
                verify_images(directory, manifest, [case])
                record = manifest['cases'][case]
                environments.add(record['environment']['image_recipe_sha256'])
                inputs[case] = record['png_sha256']
                images.append(Image.open(directory / f'{case}.png'))
            if environments != {environment_digest(ROOT)}:
                raise ValueError('Refresh all palettes when changing the capture environment')
            result = renderer(images)
            output = actual / f'{name}.png'
            result.save(output)
            inputs['tests/snapshots/compose.py'] = digest(ROOT / 'tests/snapshots/compose.py')
            if name == 'showcase':
                inputs['assets/background.png'] = digest(ROOT / 'assets/background.png')
            captured['cases'][name] = {'destination': destination(name), 'dimensions': list(result.size), 'png_sha256': digest(output), 'inputs': inputs,
                'environment': {'renderer': 'Pillow composition of VHS snapshots', 'image_recipe_sha256': environment_digest(ROOT)}}
        finally:
            for image in images:
                image.close()
    (actual / 'manifest.json').write_text(json.dumps(captured, indent=2, sort_keys=True) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--actual', type=Path, required=True)
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--case', action='append', required=True)
    args = parser.parse_args()
    compose(args.actual, args.baseline, args.case)
