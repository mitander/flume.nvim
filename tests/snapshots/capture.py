"""Capture real applications in the pinned, offline VHS environment."""

import argparse
import importlib.util
import json
import os
import shutil
import subprocess
from pathlib import Path

from common import APPS, SCHEMAS, SCENES, destination, digest, environment_digest, selected_cases

ROOT = Path('/repo')
OUTPUT = Path('/output')
GEOMETRY = {
    'columns': 100, 'rows': 40, 'font': 'Maple Mono NF', 'font_size': 38,
    'logical_font_size': 19, 'backing_scale': 2,
    'line_height': 1.12, 'letter_spacing': 2,
    'padding': 24, 'titlebar_height': 48, 'corner_radius': 20,
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


def tape(scene, schema):
    spec = SCENES[scene]
    geometry = GEOMETRY | {key: spec[key] for key in ('columns', 'rows')}
    case = f'{scene}-{schema}'
    header = '\n'.join((
        'Set Shell bash', f'Set FontFamily "{geometry["font"]}"',
        f'Set FontSize {geometry["font_size"]}', f'Set Columns {geometry["columns"]}', f'Set Rows {geometry["rows"]}',
        f'Set LineHeight {geometry["line_height"]}', f'Set LetterSpacing {geometry["letter_spacing"]}',
        'Set Padding 0', 'Set Margin 0', 'Set BorderRadius 0', 'Set CursorBlink false',
        'Set Framerate 10', f'Output "/tmp/{case}-frames/"',
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
    from render import last_frame, window

    scene, schema = case.rsplit('-', 1)
    spec = SCENES[scene]
    fonts = font_evidence()
    frames = Path('/tmp') / f'{case}-frames'
    if frames.exists():
        shutil.rmtree(frames)
    path = Path('/tmp') / f'{case}.tape'
    path.write_text(tape(scene, schema))
    with (OUTPUT / f'{case}.log').open('w') as log:
        result = subprocess.run(['vhs', str(path)], stdout=log, stderr=subprocess.STDOUT, timeout=150)
    if result.returncode:
        raise RuntimeError(f'{case}: capture failed; see {case}.log')
    text, cursor = last_frame(frames)
    geometry = GEOMETRY | {key: spec[key] for key in ('columns', 'rows')}
    image_path = OUTPUT / f'{case}.png'
    with Image.open(text) as text_image, Image.open(cursor) as cursor_image:
        image = window(text_image, cursor_image, terminal_theme(schema), geometry)
        image.save(image_path)
        dimensions = list(image.size)
    shutil.rmtree(frames)
    inputs = [ROOT / 'tests/snapshots/capture.py', ROOT / 'tests/snapshots/render.py', ROOT / 'tests/snapshots/common.py', ROOT / f'tests/snapshots/{spec["app"]}.tape', ROOT / f'extras/ghostty/flume-{schema}']
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
            'renderer': 'VHS v0.12.1 raw PNG / ttyd / Chromium / Pillow RGBA', 'platform': 'linux/amd64',
            'font_faces': fonts,
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
