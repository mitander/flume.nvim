"""Render the shared capture scenarios in Ghostty on a private X11 display."""

import os
import re
import subprocess
import time
from contextlib import ExitStack
from pathlib import Path

from PIL import Image

# Keep capture on the software backend even when the parent requests another driver.
RENDER_ENV = {
    'LIBGL_ALWAYS_SOFTWARE': '1',
    'GALLIUM_DRIVER': 'llvmpipe',
    'LP_NUM_THREADS': '1',
}


def command(*args, timeout=10):
    return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT, timeout=timeout).strip()


def start(stack, log, *args, env=None):
    process = subprocess.Popen(args, stdout=log, stderr=subprocess.STDOUT, env=env)

    def stop():
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)

    stack.callback(stop)
    return process


def start_display(stack, log):
    if Path('/tmp/.X11-unix/X99').exists() or Path('/tmp/.X99-lock').exists():
        raise RuntimeError('Private X11 display :99 is already occupied')
    display = start(stack, log, 'Xvfb', ':99', '-screen', '0', '4000x3200x24',
                    '-dpi', '96', '-ac', '-noreset', '+extension', 'GLX', '-nolisten', 'tcp')
    deadline = time.monotonic() + 10
    while True:
        if display.poll() is not None or time.monotonic() > deadline:
            raise RuntimeError('Private X11 display did not start')
        try:
            command('xdotool', 'getdisplaygeometry')
            return
        except subprocess.SubprocessError:
            time.sleep(0.05)


def screen_text(window):
    command('xdotool', 'key', '--window', window, 'ctrl+shift+F12')
    # Ghostty writes a new screen file and copies its path, without changing selection.
    time.sleep(0.08)
    try:
        path = Path(command('xclip', '-selection', 'clipboard', '-o', timeout=2))
    except subprocess.SubprocessError:
        return ''
    if not path.is_absolute() or not path.is_relative_to('/tmp') or path.is_symlink() or not path.is_file():
        return ''
    text = path.read_text()
    path.unlink()
    return text


def wait_screen(window, pattern, process, timeout=90):
    pattern = pattern.replace('[[:space:]]', r'\s')
    deadline = time.monotonic() + timeout
    text = ''
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError('Ghostty exited before the fixture was ready')
        text = screen_text(window)
        if re.search(pattern, text):
            return
        time.sleep(0.15)
    raise TimeoutError(f'Ghostty screen did not match {pattern!r}; final screen:\n{text}')


def scenario(path, app):
    lines = [line.strip() for line in path.read_text().splitlines() if line.strip() and not line.startswith('#')]
    prefix = ['Hide', f'Type "exec sh /repo/tests/snapshots/fixtures/{app}.sh"', 'Enter']
    if lines[:3] != prefix:
        raise ValueError(f'Unsupported fixture launch in {path.name}')
    return lines[3:]


def run_scenario(lines, window, process):
    for line in lines:
        if line in ('Show', 'Hide'):
            continue
        if line.startswith('Wait+Screen /') and line.endswith('/'):
            wait_screen(window, line[len('Wait+Screen /'):-1].replace(r'\/', '/'), process)
        elif re.fullmatch(r'Sleep [0-9.]+(ms|s)', line):
            duration = line.removeprefix('Sleep ')
            time.sleep(float(duration[:-2]) / 1000 if duration.endswith('ms') else float(duration[:-1]))
        elif line.startswith('Type "') and line.endswith('"'):
            command('xdotool', 'type', '--window', window, '--clearmodifiers', '--delay', '0', line[6:-1])
        else:
            raise ValueError(f'Unsupported capture instruction: {line}')


def grab(window, path):
    # X11 gives BGR pixels; PNG gets RGB directly, never an intermediate YUV frame.
    command('ffmpeg', '-v', 'error', '-f', 'x11grab', '-draw_mouse', '0', '-window_id', window,
            '-i', ':99', '-frames:v', '1', '-c:v', 'png', '-pix_fmt', 'rgb24', '-y', str(path))


def capture_terminal(root, output, case, spec, geometry, log):
    runtime = Path('/tmp/runtime')
    runtime.mkdir(mode=0o700, exist_ok=True)
    Path('/tmp/home').mkdir(exist_ok=True)
    with ExitStack() as stack:
        start_display(stack, log)
        schema = case.rsplit('-', 1)[1]
        process = start(stack, log, 'ghostty',
            '--config-default-files=false', '--alpha-blending=native',
            '--font-family=Maple Mono NF', '--font-style=SemiBold',
            '--font-style-bold=Bold', '--font-style-italic=SemiBold Italic', '--font-style-bold-italic=Bold Italic',
            f'--font-size={geometry["font_size"]}', '--adjust-cell-height=12%', '--adjust-cell-width=2%',
            f'--window-width={geometry["columns"]}', f'--window-height={geometry["rows"]}',
            '--window-padding-x=0', '--window-padding-y=0', '--window-decoration=false',
            '--gtk-single-instance=false', '--cursor-style-blink=false', '--app-notifications=false',
            '--shell-integration=none', '--confirm-close-surface=false',
            '--keybind=ctrl+shift+f12=write_screen_file:copy', f'--theme={root}/extras/ghostty/flume-{schema}',
            '-e', 'sh', str(root / f'tests/snapshots/fixtures/{spec["app"]}.sh'),
            env=os.environ | RENDER_ENV)
        window = ''
        deadline = time.monotonic() + 15
        while not window:
            if process.poll() is not None or time.monotonic() > deadline:
                raise RuntimeError('Ghostty capture window did not start')
            try:
                window = command('xdotool', 'search', '--all', '--onlyvisible', '--pid', str(process.pid), '--class', 'ghostty').splitlines()[0]
            except (subprocess.SubprocessError, IndexError):
                time.sleep(0.1)
        command('xdotool', 'mousemove', '3999', '3199')
        run_scenario(scenario(root / f'tests/snapshots/{spec["app"]}.tape', spec['app']), window, process)
        if spec.get('neotree'):
            if not Path('/tmp/neotree-ready.json').is_file():
                raise RuntimeError('Neo-tree did not report its rendered sidebar')
        terminal = output / f'{case}-terminal.png'
        previous = output / f'{case}-previous.png'
        grab(window, terminal)
        # Require a settled frame, not merely a fixture that has begun to paint.
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            time.sleep(0.2)
            grab(window, previous)
            with Image.open(terminal) as first, Image.open(previous) as second:
                if first.size == second.size and first.tobytes() == second.tobytes():
                    previous.unlink()
                    return terminal
            previous.replace(terminal)
        raise RuntimeError('Ghostty terminal pixels did not settle')
