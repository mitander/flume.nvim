"""Capture real applications in the pinned, offline Ghostty environment."""

import argparse
import importlib.util
import json
import os
import subprocess
from pathlib import Path

from common import APPS, SCHEMAS, SCENES, destination, digest, environment_digest, selected_cases

ROOT = Path('/repo')
OUTPUT = Path('/output')
GEOMETRY = {
    'columns': 100, 'rows': 40, 'font': 'Maple Mono NF', 'font_size': 28.5,
    'logical_font_size': 19, 'backing_scale': 2,
    'cell_height_adjustment': '12%', 'cell_width_adjustment': '2%',
}


def font_evidence():
    from render import FONT_DIRECTORY, FONT_FACES

    evidence = {}
    for role, (filename, pattern) in FONT_FACES.items():
        resolved = subprocess.check_output(['fc-match', '-f', '%{file}', 'Maple Mono NF:' + pattern], text=True)
        expected = FONT_DIRECTORY / filename
        if Path(resolved).resolve() != expected.resolve():
            raise ValueError(f'Terminal font fallback for {role}: {resolved}')
        evidence[role] = {'filename': filename, 'sha256': digest(expected)}
    return evidence


def terminal_theme(schema):
    values, slots = {}, {}
    for line in (ROOT / f'extras/ghostty/flume-{schema}').read_text().splitlines():
        if not line or line.startswith('#'):
            continue
        key, value = (part.strip() for part in line.split('=', 1))
        if key == 'palette':
            index, color = value.split('=', 1)
            slots[int(index)] = color
        else:
            values[key] = value
    names = ('black', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white')
    theme = {name: slots[index] for index, name in enumerate(names)}
    theme.update({'bright' + name.title(): slots[index + 8] for index, name in enumerate(names)})
    theme.update({key: values[value] for key, value in {'background': 'background', 'foreground': 'foreground', 'selection': 'selection-background', 'cursor': 'cursor-color'}.items()})
    return theme


def scene_geometry(spec):
    geometry = GEOMETRY | {key: spec[key] for key in ('columns', 'rows')}
    # The original non-hero editor captures used a smaller, compact specimen.
    if spec['app'] == 'neovim' and not (spec['language'] == 'zig' and spec['kind'] == 'syntax'):
        geometry.update(font_size=18, logical_font_size=12)
    return geometry


def capture(case):
    from PIL import Image
    from ghostty import RENDER_ENV, capture_terminal
    from render import frame_geometry, window

    scene, schema = case.rsplit('-', 1)
    spec = SCENES[scene]
    fonts = font_evidence()
    geometry = scene_geometry(spec)
    runtime = OUTPUT / f'{case}-runtime.json'
    runtime.unlink(missing_ok=True)
    Path('/tmp/neotree-ready.json').unlink(missing_ok=True)
    os.environ.update({
        'FLUME_SCHEMA': schema, 'FLUME_SHOWCASE_SCHEMA': schema,
        'FLUME_SHOWCASE_LANGUAGE': spec.get('language', ''),
        'FLUME_CAPTURE_KIND': spec.get('kind', 'syntax'),
        'FLUME_LUALINE': str(int(spec.get('lualine', False))),
        'FLUME_NEOTREE': str(int(spec.get('neotree', False))),
        'FLUME_SHOWCASE_METADATA': str(runtime),
    })
    with (OUTPUT / f'{case}.log').open('w') as log:
        terminal = capture_terminal(ROOT, OUTPUT, case, spec, geometry, log)
    image_path = OUTPUT / f'{case}.png'
    with Image.open(terminal) as text_image:
        geometry.update(frame_geometry(text_image.width))
        image = window(text_image, Image.new('RGBA', text_image.size), terminal_theme(schema), geometry)
        image.save(image_path)
        dimensions = list(image.size)
    terminal.unlink()
    inputs = [ROOT / 'tests/snapshots/capture.py', ROOT / 'tests/snapshots/ghostty.py', ROOT / 'tests/snapshots/render.py', ROOT / 'tests/snapshots/common.py', ROOT / f'tests/snapshots/{spec["app"]}.tape', ROOT / f'extras/ghostty/flume-{schema}']
    inputs += sorted((ROOT / 'tests/snapshots/fixtures').glob('*'))
    if spec['app'] == 'neovim':
        inputs += [ROOT / 'scripts/preflight-screenshots.py']
        inputs += sorted((ROOT / 'lua').rglob('*.lua')) + sorted((ROOT / 'examples').glob('*.*'))
        loader = importlib.util.spec_from_file_location('preflight', ROOT / 'scripts/preflight-screenshots.py')
        preflight = importlib.util.module_from_spec(loader)
        loader.loader.exec_module(preflight)
        preflight.record(schema, spec['language'], OUTPUT / f'{case}-runtime.json', spec['kind'], image=image_path)
        if spec.get('neotree'):
            sidecar = image_path.with_suffix('.json')
            metadata = json.loads(sidecar.read_text())
            metadata['editor_integration'] = json.loads(Path('/tmp/neotree-ready.json').read_text())
            sidecar.write_text(json.dumps(metadata, indent=2) + '\n')
    else:
        inputs += sorted((ROOT / 'extras' / spec['app']).glob('*' + schema + '*'))
    record = {
        'dimensions': dimensions, 'png_sha256': digest(image_path),
        'destination': destination(case),
        'inputs': {str(file.relative_to(ROOT)): digest(file) for file in inputs if file.is_file()},
        'environment': {
            'renderer': 'Ghostty 1.3.1 / Xvfb / Mesa llvmpipe / RGB PNG / Pillow RGBA', 'platform': 'linux/amd64',
            'font_faces': fonts,
            'render_environment': RENDER_ENV,
            'alpha_blending': 'native',
            'mesa_version': subprocess.check_output(
                ['dpkg-query', '-W', '-f=${Version}', 'libgl1-mesa-dri'], text=True).strip(),
            'image_recipe_sha256': environment_digest(ROOT),
            'geometry': geometry,
        },
    }
    if spec['app'] == 'neovim':
        record['sidecar_sha256'] = digest(image_path.with_suffix('.json'))
    return record


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--app', action='append', choices=APPS, required=True)
    parser.add_argument('--schema', action='append', choices=SCHEMAS, required=True)
    parser.add_argument('--scene', action='append', choices=SCENES)
    args = parser.parse_args()
    subprocess.run(['python3', '-m', 'unittest', 'discover', '-s', str(ROOT / 'tests/snapshots'), '-p', 'test_pixels.py'], check=True)
    Path(os.environ['HOME']).mkdir(parents=True, exist_ok=True)
    manifest = {'format_version': 1, 'cases': {}}
    for case in selected_cases(args.app, args.schema, args.scene):
        print('Capturing ' + case, flush=True)
        manifest['cases'][case] = capture(case)
    (OUTPUT / 'manifest.json').write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')


if __name__ == '__main__':
    main()
