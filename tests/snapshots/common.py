"""Snapshot inventory, publication paths, and dependency-free evidence checks."""

import hashlib
import json
from pathlib import Path

DIRECTORY = Path(__file__).resolve().parent
SCHEMAS = ('dusk', 'opal', 'mira', 'mesa')
INTEGRATIONS = ('delta', 'fzf', 'lazygit', 'lsd', 'opencode', 'pi', 'tmux')
LANGUAGES = ('zig', 'rust', 'tsx', 'python', 'go', 'elixir', 'toml')
APPS = (*INTEGRATIONS, 'neovim')
SCENES = {app: {'app': app, 'columns': 100, 'rows': 40} for app in INTEGRATIONS}
for app in ('fzf', 'lsd', 'tmux'):
    SCENES[app]['rows'] = 16
for language in LANGUAGES:
    SCENES['neovim-' + language] = {'app': 'neovim', 'language': language, 'kind': 'syntax', 'columns': 112 if language == 'zig' else 100, 'rows': 32 if language == 'zig' else 48}
for kind, languages in (('selection', ('go',)), ('completion', ('go',)), ('lsp', ('go', 'zig'))):
    for language in languages:
        SCENES[f'neovim-{kind}-{language}'] = {'app': 'neovim', 'language': language, 'kind': kind, 'columns': 100, 'rows': 48}
SCENES['neovim-lualine'] = {'app': 'neovim', 'language': 'go', 'kind': 'syntax', 'lualine': True, 'columns': 100, 'rows': 48}
SCENES['neovim-neotree'] = {'app': 'neovim', 'language': 'go', 'kind': 'syntax', 'neotree': True, 'columns': 132, 'rows': 44}
RAW_CASES = tuple(f'{scene}-{schema}' for scene in SCENES for schema in SCHEMAS)
CASES = (*RAW_CASES, *(f'contact-{app}' for app in INTEGRATIONS), 'showcase')


def destination(case: str) -> str:
    if case == 'showcase':
        return 'assets/screenshots/showcase.png'
    if case.startswith('contact-'):
        return f'assets/screenshots/integrations/{case.removeprefix("contact-")}/contact-sheet.png'
    scene, schema = case.rsplit('-', 1)
    spec = SCENES[scene]
    if spec['app'] != 'neovim':
        return f'assets/screenshots/integrations/{scene}/{schema}.png'
    directory = 'assets/screenshots'
    if spec.get('neotree'):
        directory += '/neotree'
    elif spec.get('lualine'):
        directory += '/lualine'
    elif spec['kind'] != 'syntax':
        directory += '/' + spec['kind']
    return f'{directory}/{schema}/{spec["language"]}.png'


def derived_cases(cases):
    derived = [f'contact-{app}' for app in INTEGRATIONS if any(case.startswith(app + '-') for case in cases)]
    if any(case.startswith('neovim-zig-') for case in cases):
        derived.append('showcase')
    return derived


def selected_cases(apps, schemas, scenes=None):
    return [f'{scene}-{schema}' for scene, spec in SCENES.items() if spec['app'] in apps and (not scenes or scene in scenes) for schema in schemas]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def environment_digest(root=None) -> str:
    directory = DIRECTORY if root is None else root / 'tests/snapshots'
    inputs = {name: digest(directory / name) for name in ('Dockerfile', 'tools.json', 'install.py')}
    return hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest()


def read_manifest(directory: Path) -> dict:
    path = directory / 'manifest.json'
    if path.is_symlink():
        raise ValueError(f'Unsafe snapshot manifest: {path}')
    if not path.exists():
        return {'format_version': 1, 'cases': {}}
    manifest = json.loads(path.read_text())
    if not isinstance(manifest, dict) or manifest.get('format_version') != 1 or not isinstance(manifest.get('cases'), dict):
        raise ValueError(f'Invalid snapshot manifest: {path}')
    if set(manifest['cases']) - set(CASES):
        raise ValueError(f'Unknown snapshot cases in {path}')
    return manifest


def verify_images(directory: Path, manifest: dict, cases: list[str]) -> None:
    for case in cases:
        record = manifest['cases'].get(case)
        if not isinstance(record, dict):
            raise ValueError(f'Missing snapshot evidence: {case}')
        image = directory / f'{case}.png'
        if image.is_symlink() or not image.is_file() or digest(image) != record.get('png_sha256'):
            raise ValueError(f'Missing or modified snapshot image: {image}')
        sidecar = image.with_suffix('.json')
        if sidecar.is_symlink():
            raise ValueError(f'Unsafe snapshot sidecar: {sidecar}')
        if case.startswith('neovim-') and 'sidecar_sha256' not in record:
            raise ValueError(f'Missing editor sidecar evidence: {case}')
        if sidecar.exists() and 'sidecar_sha256' not in record:
            raise ValueError(f'Unexpected snapshot sidecar: {sidecar}')
        if 'sidecar_sha256' in record:
            if not sidecar.is_file() or digest(sidecar) != record['sidecar_sha256']:
                raise ValueError(f'Missing or modified snapshot sidecar: {sidecar}')
        if not isinstance(record.get('environment'), dict) or not isinstance(record.get('inputs'), dict):
            raise ValueError(f'Missing snapshot provenance: {case}')
