"""Capture real applications in the pinned, offline VHS environment."""

import argparse
import importlib.util
import json
import os
import subprocess
from pathlib import Path

from common import APPS, SCHEMAS, SCENES, destination, digest, environment_digest, selected_cases

ROOT = Path('/repo')
OUTPUT = Path('/output')
GEOMETRY = {'columns': 100, 'rows': 40, 'font': 'DejaVu Sans Mono', 'font_size': 16}


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


def tape(scene, schema):
    spec = SCENES[scene]
    geometry = GEOMETRY | {key: spec[key] for key in ('columns', 'rows')}
    case = f'{scene}-{schema}'
    header = '\n'.join((
        'Set Shell bash', f'Set FontFamily "{geometry["font"]}"',
        f'Set FontSize {geometry["font_size"]}', f'Set Columns {geometry["columns"]}', f'Set Rows {geometry["rows"]}',
        'Set Padding 12', 'Set Margin 0', 'Set BorderRadius 0', 'Set CursorBlink false',
        'Set TypingSpeed 0', 'Set WaitTimeout 90s', 'Set Theme ' + json.dumps(terminal_theme(schema)),
        'Env PS1 ""', f'Env FLUME_SCHEMA "{schema}"', f'Env FLUME_SHOWCASE_SCHEMA "{schema}"',
        f'Env FLUME_SHOWCASE_LANGUAGE "{spec.get("language", "")}"',
        f'Env FLUME_CAPTURE_KIND "{spec.get("kind", "syntax")}"',
        f'Env FLUME_LUALINE "{int(spec.get("lualine", False))}"',
        f'Env FLUME_SHOWCASE_METADATA "/output/{case}-runtime.json"',
    ))
    body = (ROOT / f'tests/snapshots/{spec["app"]}.tape').read_text()
    return header + '\n' + body.replace('{{schema}}', schema).replace('{{case}}', case)


def capture(case):
    from PIL import Image
    scene, schema = case.rsplit('-', 1)
    spec = SCENES[scene]
    path = Path('/tmp') / f'{case}.tape'
    path.write_text(tape(scene, schema))
    with (OUTPUT / f'{case}.log').open('w') as log:
        result = subprocess.run(['vhs', str(path)], stdout=log, stderr=subprocess.STDOUT, timeout=150)
    image_path = OUTPUT / f'{case}.png'
    if result.returncode or not image_path.is_file():
        raise RuntimeError(f'{case}: capture failed; see {case}.log')
    with Image.open(image_path) as image:
        image.load()
        dimensions = list(image.size)
    inputs = [ROOT / 'tests/snapshots/capture.py', ROOT / 'tests/snapshots/common.py', ROOT / f'tests/snapshots/{spec["app"]}.tape', ROOT / f'extras/ghostty/flume-{schema}']
    inputs += sorted((ROOT / 'tests/snapshots/fixtures').glob('*'))
    if spec['app'] == 'neovim':
        inputs += [ROOT / 'scripts/preflight-screenshots.py']
        inputs += sorted((ROOT / 'lua').rglob('*.lua')) + sorted((ROOT / 'examples').glob('*.*'))
        loader = importlib.util.spec_from_file_location('preflight', ROOT / 'scripts/preflight-screenshots.py')
        preflight = importlib.util.module_from_spec(loader)
        loader.loader.exec_module(preflight)
        preflight.record(schema, spec['language'], OUTPUT / f'{case}-runtime.json', spec['kind'], image=image_path)
    else:
        inputs += sorted((ROOT / 'extras' / spec['app']).glob('*' + schema + '*'))
    record = {
        'dimensions': dimensions, 'png_sha256': digest(image_path),
        'destination': destination(case),
        'inputs': {str(file.relative_to(ROOT)): digest(file) for file in inputs if file.is_file()},
        'environment': {
            'renderer': 'VHS v0.12.1 / ttyd / Chromium', 'platform': 'linux/amd64',
            'image_recipe_sha256': environment_digest(ROOT),
            'geometry': GEOMETRY | {key: spec[key] for key in ('columns', 'rows')},
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
