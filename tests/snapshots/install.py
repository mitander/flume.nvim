"""Build the capture runtime from checksum-locked release/source archives."""

import hashlib
import json
import shutil
import subprocess
import zipfile
from pathlib import Path


def run(*command):
    subprocess.run(command, check=True)


def main():
    tools = json.loads(Path('/tmp/build/tools.json').read_text())
    for name, tool in tools.items():
        archive = Path('/tmp') / (name + '.archive')
        run('curl', '-fLsS', '--retry', '3', tool['url'], '-o', str(archive))
        if hashlib.sha256(archive.read_bytes()).hexdigest() != tool['sha256']:
            raise ValueError('Archive checksum mismatch: ' + name)
        directory = Path('/opt/tools') / name
        directory.mkdir(parents=True)
        if tool.get('format') == 'zip':
            # Extract only the locked font faces and license, not arbitrary archive paths.
            with zipfile.ZipFile(archive) as bundle:
                for filename in tool['files']:
                    if Path(filename).name != filename:
                        raise ValueError('Archive entry must be a plain filename')
                    with bundle.open(filename) as incoming, (directory / filename).open('wb') as output:
                        shutil.copyfileobj(incoming, output)
        else:
            run('tar', 'xf', str(archive), '-C', str(directory), '--strip-components=' + str(tool['strip']))
        archive.unlink()
    fonts = Path('/usr/share/fonts/truetype/maple')
    fonts.mkdir(parents=True)
    for font in (Path('/opt/tools') / 'maple-font').glob('*.ttf'):
        shutil.copyfile(font, fonts / font.name)
    run('fc-cache', '-f')
    runtime = Path('/opt/treesitter')
    (runtime / 'parser').mkdir(parents=True)
    (runtime / 'parser-info').mkdir()
    shutil.copytree('/opt/tools/treesitter/runtime/queries', runtime / 'queries')
    for name, tool in tools.items():
        if not name.startswith('parser-'):
            continue
        language = name.removeprefix('parser-')
        source = Path('/opt/tools') / name / tool.get('location', '') / 'src'
        files = [source / 'parser.c']
        if (source / 'scanner.c').exists():
            files.append(source / 'scanner.c')
        run('cc', '-O2', '-fPIC', '-shared', '-I' + str(source), *(str(file) for file in files), '-o', str(runtime / 'parser' / (language + '.so')))
        (runtime / 'parser-info' / (language + '.revision')).write_text(tool['revision'])
    run('/opt/tools/go/bin/go', 'install', 'golang.org/x/tools/gopls@v0.16.2')
    shutil.copy('/root/go/bin/gopls', '/usr/local/bin/gopls')
    for name, binary in {'nvim': 'bin/nvim', 'pi': 'pi', 'opencode': 'opencode', 'lazygit': 'lazygit', 'lsd': 'lsd', 'zls': 'zls', 'zig': 'zig', 'go': 'bin/go'}.items():
        Path('/usr/local/bin', name).symlink_to(Path('/opt/tools') / name / binary)
    for directory in ('/root/go', '/root/.cache', '/opt/tools/treesitter'):
        shutil.rmtree(directory, ignore_errors=True)
    for directory in Path('/opt/tools').glob('parser-*'):
        shutil.rmtree(directory)


if __name__ == '__main__':
    main()
