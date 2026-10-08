"""Fast tests for snapshot commands; the separate container lane tests pixels."""

import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from importlib.machinery import SourceFileLoader
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
DIRECTORY = ROOT / 'tests/snapshots'
sys.path.insert(0, str(DIRECTORY))
from common import CASES, derived_cases, destination, digest, environment_digest, read_manifest, verify_images


def load(name, path):
    spec = importlib.util.spec_from_loader(name, SourceFileLoader(name, str(path)))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


commands = load('snapshot_commands', ROOT / 'scripts/snapshots')
capture = load('snapshot_capture', DIRECTORY / 'capture.py')
comparison = load('snapshot_compare', DIRECTORY / 'compare.py')


def evidence(directory, cases, content=b'pixels', environment=None):
    directory.mkdir(parents=True, exist_ok=True)
    records = {}
    for case in cases:
        image = directory / f'{case}.png'
        image.write_bytes(content)
        records[case] = {
            'png_sha256': digest(image),
            'environment': environment or {'renderer': 'fixture'},
            'inputs': {'fixture': 'revision'},
            'dimensions': [1, 1],
        }
    for case, record in records.items():
        if case.startswith('neovim-'):
            sidecar = directory / f'{case}.json'
            sidecar.write_text('fixture metadata')
            record['sidecar_sha256'] = digest(sidecar)
    manifest = {'format_version': 1, 'cases': records}
    (directory / 'manifest.json').write_text(json.dumps(manifest))
    return manifest


class SnapshotCommands(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        self.actual = self.directory / 'actual'
        self.baseline = self.directory / 'baseline'
        self.published = self.directory / 'checkout'

    def published_evidence(self, cases, content=b'pixels', environment=None):
        manifest = evidence(self.baseline, cases, content, environment)
        for case in cases:
            target = self.published / destination(case)
            target.parent.mkdir(parents=True, exist_ok=True)
            (self.baseline / f'{case}.png').replace(target)
            sidecar = self.baseline / f'{case}.json'
            if sidecar.exists():
                sidecar.replace(target.with_suffix('.json'))
        return manifest

    def stage_published(self):
        staged = self.directory / 'staged'
        with patch.object(commands, 'ROOT', self.published), patch.object(commands, 'BASELINES', self.baseline):
            commands.stage_baselines(staged)
        return staged

    def test_published_images_are_the_only_baselines(self):
        captured = evidence(self.actual, ['fzf-opal'], b'new')
        captured['cases']['fzf-opal']['destination'] = '../../untrusted-target'
        (self.actual / 'manifest.json').write_text(json.dumps(captured))
        published = self.directory / 'checkout'
        commands.update_baselines(self.actual, self.baseline, ['fzf-opal'], published_root=published)
        self.assertEqual((published / destination('fzf-opal')).read_bytes(), b'new')
        self.assertFalse((self.baseline / 'fzf-opal.png').exists())
        self.assertEqual(read_manifest(self.baseline)['cases']['fzf-opal']['destination'], destination('fzf-opal'))
        self.assertFalse((self.directory.parent / 'untrusted-target').exists())

    def test_manifest_and_image_symlinks_are_rejected(self):
        manifest = evidence(self.actual, ['fzf-opal'])
        original = self.directory / 'original.png'
        (self.actual / 'fzf-opal.png').rename(original)
        (self.actual / 'fzf-opal.png').symlink_to(original)
        with self.assertRaisesRegex(ValueError, 'snapshot image'):
            verify_images(self.actual, manifest, ['fzf-opal'])
        original_manifest = self.directory / 'original.json'
        (self.actual / 'manifest.json').rename(original_manifest)
        (self.actual / 'manifest.json').symlink_to(original_manifest)
        with self.assertRaisesRegex(ValueError, 'Unsafe snapshot manifest'):
            read_manifest(self.actual)

    def test_staging_reads_published_images_and_manifest_only(self):
        self.published_evidence(['fzf-opal'], b'published')
        self.assertEqual({path.name for path in self.baseline.iterdir()}, {'manifest.json'})
        staged = self.stage_published()
        self.assertEqual((staged / 'fzf-opal.png').read_bytes(), b'published')
        verify_images(staged, read_manifest(staged), ['fzf-opal'])

    def test_derived_inventory_is_fixed_by_selected_raw_cases(self):
        self.assertEqual(derived_cases(['fzf-opal']), ['contact-fzf'])
        self.assertEqual(derived_cases(['neovim-zig-dusk']), ['showcase'])
        self.assertEqual(derived_cases(['neovim-go-dusk']), [])

    def test_unrecorded_sidecars_cannot_be_published(self):
        manifest = evidence(self.actual, ['fzf-opal'])
        sidecar = self.actual / 'fzf-opal.json'
        sidecar.symlink_to(self.actual / 'manifest.json')
        with self.assertRaisesRegex(ValueError, 'Unsafe snapshot sidecar'):
            commands.update_baselines(self.actual, self.baseline, ['fzf-opal'], published_root=self.published)
        sidecar.unlink()
        sidecar.write_text('unrecorded')
        with self.assertRaisesRegex(ValueError, 'Unexpected snapshot sidecar'):
            verify_images(self.actual, manifest, ['fzf-opal'])
        self.assertFalse(self.baseline.exists())

    def test_editor_sidecars_are_verified_before_publication(self):
        manifest = evidence(self.actual, ['neovim-zig-dusk'])
        sidecar = self.actual / 'neovim-zig-dusk.json'
        sidecar.write_text('metadata')
        manifest['cases']['neovim-zig-dusk']['sidecar_sha256'] = digest(sidecar)
        verify_images(self.actual, manifest, ['neovim-zig-dusk'])
        sidecar.write_text('modified')
        with self.assertRaisesRegex(ValueError, 'sidecar'):
            verify_images(self.actual, manifest, ['neovim-zig-dusk'])

    def test_every_scene_and_composite_has_one_safe_destination(self):
        paths = [destination(case) for case in CASES]
        self.assertEqual(len(paths), len(set(paths)))
        self.assertTrue(all(path.startswith('assets/screenshots/') and '..' not in path for path in paths))
        self.assertEqual(len(CASES), 88)
        self.assertFalse(any(case.startswith(('ghostty-', 'kitty-')) for case in CASES))

    def test_tool_lock_and_installer_are_part_of_environment_identity(self):
        source = self.directory / 'source'
        commands.stage_source(source, ['fzf'])
        before = environment_digest(source)
        installer = source / 'tests/snapshots/install.py'
        installer.write_text(installer.read_text() + '\n# build change\n')
        self.assertNotEqual(environment_digest(source), before)

    def test_help_requires_neither_docker_nor_a_running_daemon(self):
        result = subprocess.run([sys.executable, str(ROOT / 'scripts/snapshots'), '--help'],
                                env=dict(os.environ, PATH='/missing'), capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('update', result.stdout)
        self.assertIn('--app', result.stdout)

    def test_invalid_manifest_is_rejected(self):
        self.actual.mkdir()
        for value in ([], {'format_version': 2, 'cases': {}}, {'format_version': 1, 'cases': {'unknown': {}}}):
            (self.actual / 'manifest.json').write_text(json.dumps(value))
            with self.assertRaises(ValueError):
                read_manifest(self.actual)

    def test_partial_update_preserves_unselected_images_and_provenance(self):
        old = self.published_evidence(['delta-dusk', 'fzf-opal'], b'old', {'renderer': 'old'})
        evidence(self.actual, ['fzf-opal'], b'new', {'renderer': 'new'})
        commands.update_baselines(self.actual, self.baseline, ['fzf-opal'], published_root=self.published)
        updated = read_manifest(self.baseline)
        self.assertEqual((self.published / destination('fzf-opal')).read_bytes(), b'new')
        self.assertEqual((self.published / destination('delta-dusk')).read_bytes(), b'old')
        self.assertEqual(updated['cases']['delta-dusk'], old['cases']['delta-dusk'])
        verify_images(self.stage_published(), updated, ['delta-dusk', 'fzf-opal'])
        self.assertEqual({path.name for path in self.baseline.iterdir()}, {'manifest.json'})

    def test_missing_or_modified_capture_cannot_replace_baselines(self):
        self.published_evidence(['fzf-opal'], b'old')
        evidence(self.actual, ['fzf-opal'], b'new')
        before = (self.baseline / 'manifest.json').read_bytes()
        (self.actual / 'fzf-opal.png').write_bytes(b'broken')
        with self.assertRaises(ValueError):
            commands.update_baselines(self.actual, self.baseline, ['fzf-opal'], published_root=self.published)
        self.assertEqual((self.published / destination('fzf-opal')).read_bytes(), b'old')
        self.assertEqual((self.baseline / 'manifest.json').read_bytes(), before)

    def test_incomplete_inventory_cannot_replace_baselines(self):
        evidence(self.actual, ['delta-dusk'])
        with self.assertRaisesRegex(ValueError, 'inventory'):
            commands.update_baselines(self.actual, self.baseline, ['delta-dusk', 'fzf-dusk'], published_root=self.published)
        self.assertFalse(self.baseline.exists())

    def test_interrupted_publication_is_detected(self):
        recorded = self.published_evidence(['fzf-dusk'], b'old')
        evidence(self.actual, ['fzf-dusk'], b'new')
        original = commands.replace_file

        def interrupt(source, destination):
            if destination.name == 'manifest.json':
                raise OSError('interrupted')
            original(source, destination)

        with patch.object(commands, 'replace_file', side_effect=interrupt):
            with self.assertRaises(OSError):
                commands.update_baselines(self.actual, self.baseline, ['fzf-dusk'], published_root=self.published)
        with self.assertRaises(ValueError):
            verify_images(self.stage_published(), recorded, ['fzf-dusk'])

    def test_interrupted_provenance_only_update_retains_valid_old_evidence(self):
        recorded = self.published_evidence(['fzf-dusk'])
        captured = evidence(self.actual, ['fzf-dusk'])
        captured['cases']['fzf-dusk']['inputs']['fixture'] = 'new revision, same pixels'
        (self.actual / 'manifest.json').write_text(json.dumps(captured))
        original = commands.replace_file

        def interrupt(source, destination):
            if destination.name == 'manifest.json':
                raise OSError('interrupted')
            original(source, destination)

        with patch.object(commands, 'replace_file', side_effect=interrupt):
            with self.assertRaises(OSError):
                commands.update_baselines(self.actual, self.baseline, ['fzf-dusk'], published_root=self.published)
        self.assertEqual(read_manifest(self.baseline), recorded)
        staged = self.stage_published()
        verify_images(staged, recorded, ['fzf-dusk'])
        with patch.object(comparison, 'compare_case', return_value=None):
            self.assertEqual(comparison.compare(self.actual, staged, self.directory / 'report', ['fzf-dusk']), 0)

    def test_failed_capture_does_not_publish_baselines(self):
        evidence(self.baseline, ['fzf-dusk'], b'old')
        before = (self.baseline / 'manifest.json').read_bytes()
        report = self.directory / 'report'
        report.mkdir()
        original_mkdtemp = tempfile.mkdtemp

        def temporary_directory(*args, **options):
            if options.get('prefix') == 'flume-snapshot-report-':
                return str(report)
            return original_mkdtemp(*args, **options)

        with (
            patch.object(commands, 'BASELINES', self.baseline),
            patch.object(commands.shutil, 'which', return_value='docker'),
            patch.object(commands.subprocess, 'run') as run,
            patch.object(commands, 'container', return_value=1),
            patch.object(commands.tempfile, 'mkdtemp', side_effect=temporary_directory),
            patch.object(commands, 'update_baselines') as publish,
        ):
            run.return_value.returncode = 0
            self.assertEqual(commands.execute('update', ['fzf'], ['dusk']), 1)
            publish.assert_not_called()
        self.assertEqual((self.baseline / 'manifest.json').read_bytes(), before)
        self.assertEqual((self.baseline / 'fzf-dusk.png').read_bytes(), b'old')

    def test_capture_exceptions_retain_diagnostics_without_publication(self):
        for error in (subprocess.TimeoutExpired('docker run', 200), OSError('capture launch failed')):
            with self.subTest(error=type(error).__name__):
                report = self.directory / type(error).__name__
                report.mkdir()
                original_mkdtemp = tempfile.mkdtemp

                def allocate(*args, **options):
                    if options.get('prefix') == 'flume-snapshot-report-':
                        return str(report)
                    return original_mkdtemp(*args, **options)

                def failed_capture(image, source, directory, case):
                    directory.mkdir()
                    (directory / f'{case}.log').write_text('last capture diagnostic\n')
                    raise error

                with (
                    patch.object(commands.shutil, 'which', return_value='docker'),
                    patch.object(commands.subprocess, 'run') as run,
                    patch.object(commands, 'capture_case', side_effect=failed_capture),
                    patch.object(commands.tempfile, 'mkdtemp', side_effect=allocate),
                    patch.object(commands, 'update_baselines') as publish,
                ):
                    run.return_value.returncode = 0
                    self.assertEqual(commands.execute('update', ['fzf'], ['dusk']), 1)
                    publish.assert_not_called()
                self.assertEqual((report / 'capture/fzf-dusk.log').read_text(), 'last capture diagnostic\n')
                errors = json.loads((report / 'capture-errors.json').read_text())
                self.assertIn(str(error), errors['fzf-dusk'])

    def test_interrupted_submission_cancels_already_queued_captures(self):
        from concurrent.futures import Future
        queued = Future()
        with (
            patch.object(tempfile, 'tempdir', str(self.directory)),
            patch.object(commands.shutil, 'which', return_value='docker'),
            patch.object(commands.subprocess, 'run') as run,
            patch.object(commands, 'ThreadPoolExecutor') as executor,
        ):
            run.return_value.returncode = 0
            pool = executor.return_value.__enter__.return_value
            pool.submit.side_effect = [queued, KeyboardInterrupt]
            with self.assertRaises(KeyboardInterrupt):
                commands.execute('update', ['fzf'], ['dusk', 'opal'])
            self.assertTrue(queued.cancelled())
            pool.shutdown.assert_called_once_with(wait=True, cancel_futures=True)

    def test_symlink_capture_outputs_are_rejected_before_host_copy(self):
        secret = self.directory / 'private'
        secret.write_text('must not be read through a container-created symlink')

        def unsafe_capture(image, source, directory, case):
            evidence(directory, [case], secret.read_bytes())
            (directory / f'{case}.png').unlink()
            (directory / f'{case}.png').symlink_to(secret)
            return 0

        with (
            patch.object(tempfile, 'tempdir', str(self.directory)),
            patch.object(commands.shutil, 'which', return_value='docker'),
            patch.object(commands.subprocess, 'run') as run,
            patch.object(commands, 'capture_case', side_effect=unsafe_capture),
            patch.object(commands, 'update_baselines') as publish,
        ):
            run.return_value.returncode = 0
            with self.assertRaisesRegex(ValueError, 'Unsafe capture output'):
                commands.execute('update', ['fzf'], ['dusk'])
            publish.assert_not_called()

    def test_success_exit_without_requested_inventory_cannot_publish(self):
        def incomplete_capture(image, source, directory, case):
            evidence(directory, [])
            return 0

        with (
            patch.object(tempfile, 'tempdir', str(self.directory)),
            patch.object(commands.shutil, 'which', return_value='docker'),
            patch.object(commands.subprocess, 'run') as run,
            patch.object(commands, 'capture_case', side_effect=incomplete_capture),
            patch.object(commands, 'update_baselines') as publish,
        ):
            run.return_value.returncode = 0
            with self.assertRaisesRegex(ValueError, 'inventory'):
                commands.execute('update', ['neovim'], ['opal'], ['neovim-go'])
            publish.assert_not_called()

    def test_writable_stage_cannot_reduce_publication_inventory(self):
        for stage in ('composition', 'comparison'):
            with self.subTest(stage=stage):
                def complete_capture(image, source, directory, case):
                    evidence(directory, [case])
                    return 0

                calls = []

                def mutate(image, source, output, arguments, *mounts, **options):
                    calls.append(arguments[0])
                    if (stage == 'composition' and arguments[0].endswith('compose.py')) or (stage == 'comparison' and arguments[0].endswith('compare.py')):
                        (output / 'manifest.json').write_text(json.dumps({'format_version': 1, 'cases': {}}))
                    if arguments[0].endswith('compare.py'):
                        self.assertTrue(options['readonly_output'])
                    return 0

                with (
                    patch.object(tempfile, 'tempdir', str(self.directory)),
                    patch.object(commands.shutil, 'which', return_value='docker'),
                    patch.object(commands.subprocess, 'run') as run,
                    patch.object(commands, 'capture_case', side_effect=complete_capture),
                    patch.object(commands, 'container', side_effect=mutate),
                    patch.object(commands, 'update_baselines') as publish,
                ):
                    run.return_value.returncode = 0
                    with self.assertRaisesRegex(ValueError, 'inventory'):
                        commands.execute('update', ['neovim'], ['opal'], ['neovim-go'])
                    publish.assert_not_called()

    def test_source_is_frozen_and_excludes_baselines(self):
        destination = self.directory / 'source'
        commands.stage_source(destination, ['fzf'])
        self.assertFalse((destination / 'tests/snapshots/baselines').exists())
        staged = destination / 'extras/fzf/flume-dusk.opts'
        original = staged.read_bytes()
        self.assertEqual(original, (ROOT / 'extras/fzf/flume-dusk.opts').read_bytes())
        staged.write_bytes(b'private edit')
        self.assertEqual((ROOT / 'extras/fzf/flume-dusk.opts').read_bytes(), original)
        self.assertFalse((destination / '.git').exists())

    def test_container_is_offline_readonly_and_cleaned_up(self):
        output = self.directory / 'output'
        output.mkdir()
        cidfile = output.parent / (output.name + '.cid')
        cidfile.write_text('owned-container')
        with patch.object(commands.subprocess, 'run') as run:
            run.return_value.returncode = 0
            commands.container('image', self.directory, output, ['--app', 'fzf'])
        invocation = run.call_args_list[0].args[0]
        self.assertIn('--read-only', invocation)
        self.assertEqual(invocation[invocation.index('--network') + 1], 'none')
        self.assertIn(f'type=bind,source={self.directory},target=/repo,readonly', invocation)
        self.assertIn(['docker', 'rm', '-f', 'owned-container'], [call.args[0] for call in run.call_args_list])
        self.assertFalse(cidfile.exists())
        self.assertNotEqual(cidfile.parent, output)

    def test_neovim_cursor_preserves_mode_shapes_and_disables_blinking(self):
        fixture = (ROOT / 'tests/snapshots/fixtures/neovim.lua').read_text()
        self.assertIn("vim.opt.guicursor = 'n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20,a:blinkon0'", fixture)
        self.assertNotIn('Flume preview', fixture)
        self.assertLess(fixture.index('vim.o.laststatus = 0'), fixture.index('dofile('))
        self.assertLess(fixture.index('filereadable'), fixture.index('vim.o.laststatus = 2'))
        for renderer in ('showcase.lua', 'states.lua'):
            self.assertIn('if not vim.env.FLUME_CAPTURE_KIND then vim.o.laststatus = 2 end',
                          (ROOT / 'examples' / renderer).read_text())

    def test_palette_header_uses_the_shipped_terminal_export(self):
        with patch.object(capture, 'ROOT', ROOT):
            theme = capture.terminal_theme('opal')
        self.assertEqual(theme['background'], '#f2eff7')
        self.assertEqual(theme['foreground'], '#554e5d')
        self.assertEqual(theme['selection'], '#413b49')
        self.assertEqual(theme['brightBlue'], '#0071a3')

    def test_original_editor_geometry_is_compact_except_for_the_hero(self):
        from common import SCENES
        self.assertEqual(capture.scene_geometry(SCENES['neovim-go'])['font_size'], 18)
        self.assertEqual(capture.scene_geometry(SCENES['neovim-zig'])['font_size'], 28.5)
        self.assertEqual(capture.scene_geometry(SCENES['neovim-lsp-zig'])['font_size'], 18)
        self.assertEqual(destination('neovim-neotree-dusk'), 'assets/screenshots/neotree/dusk/go.png')

    def test_test_reports_environment_changes_without_updating_baselines(self):
        evidence(self.actual, ['fzf-dusk'], environment={'renderer': 'new'})
        evidence(self.baseline, ['fzf-dusk'], environment={'renderer': 'old'})
        before = (self.baseline / 'manifest.json').read_bytes()
        with patch.object(comparison, 'compare_case', return_value=None):
            result = comparison.compare(self.actual, self.baseline, self.directory / 'report', ['fzf-dusk'])
        self.assertEqual(result, 1)
        self.assertEqual((self.baseline / 'manifest.json').read_bytes(), before)
        self.assertIn('environment changed', (self.directory / 'report/index.html').read_text())


if __name__ == '__main__':
    unittest.main()
