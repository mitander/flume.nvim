"""Fast isolation checks for the manually observed native-theme trial."""

import importlib.util
import io
import json
import os
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from contextlib import redirect_stdout
from importlib.machinery import SourceFileLoader
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_loader('native_themes', SourceFileLoader('native_themes', str(ROOT / 'scripts/native-themes')))
native = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(native)


def retire_process_group(process: subprocess.Popen[bytes], *, grace_seconds: float = 1.0) -> None:
    # The caller created this group with start_new_session=True. The leader may
    # already have exited while its app still owns files or terminal descriptors.
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        process.wait(timeout=5)
        return
    deadline = time.monotonic() + grace_seconds
    while time.monotonic() < deadline:
        process.poll()  # Reap the wrapper without treating its exit as app exit.
        try:
            os.killpg(process.pid, 0)
        except ProcessLookupError:
            process.wait(timeout=5)
            return
        time.sleep(0.02)
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    process.wait(timeout=5)


class NativeThemeTrial(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name).resolve()

    def prepare(self):
        # Keep all trial artifacts inside the unittest-owned temporary directory.
        root = self.directory / 'trial'
        root.mkdir()
        with patch.object(native.tempfile, 'mkdtemp', return_value=str(root)):
            native.prepare(ROOT, 'dusk')
        return root

    def test_prepare_guidance_uses_short_shell_neutral_commands_for_available_apps(self):
        output = io.StringIO()
        root = self.directory / 'trial with spaces'
        with patch.object(native.shutil, 'which', side_effect=lambda app: '/installed/' + app if app != 'kitty' else None):
            with redirect_stdout(output):
                native.instructions(root, 'opal')
        text = output.getvalue()
        self.assertEqual(text.count(str(root)), 1)
        self.assertIn('cd ' + native.shlex.quote(str(root)), text)
        self.assertIn('./control launch ghostty', text)
        self.assertIn('./control launch pi', text)
        self.assertNotIn('./control launch kitty', text)
        self.assertIn('./control switch dusk', text)
        self.assertLess(text.index('./control launch ghostty'), text.index('Reload only'))
        self.assertIn('No applications launched', text)

    def test_prepare_guidance_without_apps_does_not_suggest_launching_or_reloading(self):
        output = io.StringIO()
        with patch.object(native.shutil, 'which', return_value=None), redirect_stdout(output):
            native.instructions(self.directory, 'dusk')
        text = output.getvalue()
        self.assertIn('Available apps: none', text)
        self.assertIn('./control show', text)
        self.assertNotIn('./control launch', text)
        self.assertNotIn('reload', text.lower())

    def test_environment_drops_credentials_and_live_routing(self):
        with patch.dict(os.environ, {
            'OPENAI_API_KEY': 'fixture-secret', 'GOOGLE_API_KEY': 'fixture-secret',
            'NODE_OPTIONS': '--require personal-hook', 'PI_CODING_AGENT_DIR': '/personal/agent',
            'TMUX': '/personal/socket', 'FLUME_DATA_DIR': '/personal/themes',
        }):
            env = native.environment(self.directory)
        for name in ('OPENAI_API_KEY', 'GOOGLE_API_KEY', 'NODE_OPTIONS', 'TMUX'):
            self.assertNotIn(name, env)
        self.assertEqual(env['HOME'], str(self.directory / 'home'))
        self.assertEqual(env['FLUME_DATA_DIR'], str(self.directory / 'data'))
        self.assertEqual(env['PI_CODING_AGENT_DIR'], str(self.directory / 'home/.pi/agent'))
        self.assertEqual(env['PI_OFFLINE'], '1')
        self.assertEqual(env['PI_TELEMETRY'], '0')

    def test_preparation_and_switching_use_only_copied_sources_and_private_state(self):
        original_link = ROOT / 'extras/current'
        before = original_link.lstat() if original_link.exists() or original_link.is_symlink() else None
        root = self.prepare()
        marker = json.loads((root / native.MARKER).read_text())
        self.assertIn('plugin/lua/flume/sync.lua', marker['source_inputs'])
        self.assertIn('control', marker['source_inputs'])
        self.assertIn('switch.lua', marker['source_inputs'])
        self.assertFalse(any('.current' in path or '/current/' in path for path in marker['source_inputs']))
        self.assertEqual((root / 'plugin/extras/current').resolve(), (root / 'data/current').resolve())
        link = root / 'home/.pi/agent/themes/flume.json'
        self.assertTrue(link.is_symlink())
        self.assertEqual(link.resolve(), (root / 'data/current/pi.json').resolve())
        session = json.loads((root / 'session.jsonl').read_text().splitlines()[0])
        self.assertEqual(session['cwd'], str(root / 'project'))
        native.switch(root, 'opal')
        palette = json.loads((root / 'data/current/palette.json').read_text())
        self.assertEqual(palette['schema'], 'opal')
        self.assertEqual(palette['colors']['bg'], '#f2eff7')
        if before:
            self.assertEqual(original_link.lstat().st_ino, before.st_ino)
            self.assertEqual(original_link.lstat().st_mtime_ns, before.st_mtime_ns)
        else:
            self.assertFalse(original_link.exists() or original_link.is_symlink())

    def test_preparation_accepts_checkout_without_obsolete_plugin_directory(self):
        source = self.directory / 'source'
        for directory in ('lua', 'colors', 'extras'):
            shutil.copytree(ROOT / directory, source / directory, ignore=native.source_filter)
        for relative in ('scripts/native-themes', 'tests/native-themes.lua',
                         'tests/snapshots/fixtures/pi-session.jsonl'):
            destination = source / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, destination)
        self.assertFalse((source / 'plugin').exists())

        root = self.directory / 'trial'
        root.mkdir()
        with patch.object(native.tempfile, 'mkdtemp', return_value=str(root)):
            self.assertEqual(native.prepare(source, 'dusk'), root)

        self.assertTrue((root / 'plugin/lua/flume/init.lua').is_file())
        self.assertFalse((root / 'plugin/plugin').exists())
        self.assertEqual((root / 'data/current/schema').read_text().strip(), 'dusk')

    def test_switch_driver_blocks_external_reload_commands(self):
        root = self.prepare()
        env = native.environment(root)
        env['FLUME_NATIVE_SCHEMA'] = 'mira'
        env['TMUX'] = '/must-not-be-used'
        guarded = root / 'guarded.lua'
        guarded.write_text('''
vim.fn.has = function(name) return name == 'mac' and 1 or 0 end
vim.fn.executable = function() return 1 end
vim.fn.system = function() error('an external command was attempted') end
dofile(vim.env.FLUME_NATIVE_ROOT .. '/switch.lua')
''')
        result = subprocess.run(
            [native.tool('nvim'), '--headless', '--clean', '-c', 'lua dofile(vim.env.FLUME_NATIVE_ROOT .. "/guarded.lua")'],
            env=env, cwd=root / 'project', capture_output=True, text=True, timeout=30,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((root / 'data/current/schema').read_text().strip(), 'mira')

    def test_workspace_rejects_redirected_private_state(self):
        root = self.prepare()
        outside = self.directory / 'personal'
        outside.mkdir()
        (outside / 'keep').write_text('personal settings')
        current = root / 'data/current'
        current.unlink()
        current.symlink_to(outside, target_is_directory=True)
        with patch.object(native, '__file__', str(root / 'control')):
            with self.assertRaisesRegex(ValueError, 'outside the trial'):
                native.workspace()
        self.assertEqual((outside / 'keep').read_text(), 'personal settings')

    def test_switch_refuses_redirected_plugin_extras_before_forwarding_legacy_links(self):
        root = self.prepare()
        outside = self.directory / 'personal-extras'
        extras = root / 'plugin/extras'
        extras.rename(outside)  # Keep real artifacts so an unguarded switch could publish.
        current = outside / 'current'
        current.unlink()
        current.symlink_to('.current-set-dusk-0000000000000000')
        before = sorted(path.name for path in outside.iterdir())
        extras.symlink_to(outside, target_is_directory=True)
        result = subprocess.run(
            [str(root / 'control'), 'switch', 'opal'], capture_output=True, text=True, timeout=30,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('outside the trial: plugin/extras', result.stderr)
        self.assertEqual(os.readlink(current), '.current-set-dusk-0000000000000000')
        self.assertEqual(sorted(path.name for path in outside.iterdir()), before)
        self.assertEqual((root / 'data/current/schema').read_text().strip(), 'dusk')
        # Negative control, entirely in owned test directories: bypassing the
        # entry-point guard really would forward this external legacy link.
        native.switch(root, 'opal')
        self.assertEqual(os.readlink(current), str(root / 'data/current'))

    def test_source_copy_does_not_follow_user_symlinks(self):
        source = self.directory / 'source'
        (source / 'lua').mkdir(parents=True)
        outside = self.directory / 'personal.lua'
        outside.write_text('personal settings')
        (source / 'lua/unexpected.lua').symlink_to(outside)
        trial = self.directory / 'trial'
        trial.mkdir()
        with (
            patch.object(native.tempfile, 'mkdtemp', return_value=str(trial)),
            patch.object(native, 'switch') as switch,
        ):
            with self.assertRaisesRegex(ValueError, 'unexpected source symlink'):
                native.prepare(source, 'dusk')
            switch.assert_not_called()
        self.assertEqual(outside.read_text(), 'personal settings')

    def test_checkout_cannot_be_used_as_a_trial(self):
        with self.assertRaisesRegex(ValueError, 'control file printed by prepare'):
            native.workspace()

    def test_launches_use_private_configs_and_disable_pi_resources(self):
        with patch.object(native, 'tool', return_value='/installed/kitty'):
            kitty = native.launch_command(self.directory, 'kitty')
        self.assertEqual(kitty[:3], ['/installed/kitty', '--config', str(self.directory / 'kitty.conf')])
        self.assertIn(str(self.directory / 'control'), kitty)
        with patch.object(native, 'tool', return_value='/installed/pi'):
            pi = native.launch_command(self.directory, 'pi')
        for flag in ('--offline', '--no-extensions', '--no-mcp', '--no-tools', '--no-context-files', '--no-approve'):
            self.assertIn(flag, pi)
        self.assertEqual(pi[pi.index('--use-theme') + 1], 'flume')
        self.assertEqual(pi[pi.index('--session') + 1], str(self.directory / 'session.jsonl'))

    def test_macos_launch_is_a_new_instance_with_explicit_environment(self):
        with (
            patch.object(native, 'tool', return_value='/Applications/Ghostty.app/Contents/MacOS/ghostty'),
            patch.object(native.sys, 'platform', 'darwin'),
        ):
            command = native.launch_command(self.directory, 'ghostty')
        self.assertEqual(command[:4], ['/usr/bin/open', '-n', '-a', '/Applications/Ghostty.app'])
        self.assertIn('HOME=' + str(self.directory / 'home'), command)
        self.assertIn('--config-default-files=false', command)
        self.assertIn('--config-file=' + str(self.directory / 'ghostty.conf'), command)
        self.assertNotIn('osascript', command)

    def test_cleanup_retires_a_child_after_the_wrapper_has_exited(self):
        read_fd, write_fd = os.pipe()
        self.addCleanup(os.close, read_fd)
        child = (
            "import os,signal,sys,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); "
            "os.write(int(sys.argv[1]), b'ready'); time.sleep(60)"
        )
        wrapper = (
            "import subprocess,sys; subprocess.Popen([sys.executable,'-c',sys.argv[2],sys.argv[1]], "
            "pass_fds=(int(sys.argv[1]),))"
        )
        try:
            process = subprocess.Popen(
                [sys.executable, '-c', wrapper, str(write_fd), child], pass_fds=(write_fd,),
                start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
        finally:
            os.close(write_fd)
        try:
            self.assertTrue(select.select([read_fd], [], [], 5)[0], 'child did not become ready')
            self.assertEqual(os.read(read_fd, 5), b'ready')
            self.assertEqual(process.wait(timeout=5), 0)
            os.killpg(process.pid, 0)  # Negative control: the child outlived its wrapper.
        finally:
            retire_process_group(process, grace_seconds=0.05)
        self.assertTrue(select.select([read_fd], [], [], 5)[0], 'child retained its output descriptor')
        self.assertEqual(os.read(read_fd, 1), b'', 'group cleanup left a live pipe writer')

    @unittest.skipUnless(os.environ.get('FLUME_NATIVE_PI') == '1', 'set FLUME_NATIVE_PI=1 for the installed Pi lane')
    def test_native_pi_hot_reload_emits_new_panel_colors_without_a_restart(self):
        import fcntl
        import pty
        import struct
        import termios

        native.tool('pi')  # Explicitly selected missing dependencies are failures.
        root = self.prepare()
        master, slave = pty.openpty()
        self.addCleanup(os.close, master)
        try:
            fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 60, 120, 0, 0))
            process = subprocess.Popen(
                [str(root / 'control'), 'launch', 'pi'], stdin=slave, stdout=slave, stderr=slave,
                start_new_session=True,
            )
        finally:
            os.close(slave)

        self.addCleanup(retire_process_group, process)

        def observe(color):
            rgb = tuple(int(color[offset:offset + 2], 16) for offset in (1, 3, 5))
            expected = ('\033[48;2;%d;%d;%dm' % rgb).encode()
            output = b''
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline and process.poll() is None:
                ready, _, _ = select.select([master], [], [], 0.2)
                if ready:
                    try:
                        output += os.read(master, 1024 * 1024)
                    except OSError:
                        break
                    if expected in output:
                        return
            self.fail(f'Pi did not render panel color {color}; last output: {output[-2000:]!r}')

        # The host terminal never changes palette. These are Pi-owned SGR fills,
        # not a file-state check or the terminal background showing through.
        observe('#262938')
        native.switch(root, 'opal')
        observe('#f1ecf6')
        self.assertIsNone(process.poll(), 'Pi exited during the live switch')

    def test_missing_app_does_not_install_anything(self):
        with patch.object(native.shutil, 'which', return_value=None):
            with self.assertRaisesRegex(ValueError, 'install it separately'):
                native.launch_command(self.directory, 'kitty')
        self.assertEqual(list(self.directory.iterdir()), [])


if __name__ == '__main__':
    unittest.main()
