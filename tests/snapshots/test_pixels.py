"""Exercise Pillow's exact comparator in the same image used for capture."""

import copy
import json
import tempfile
import unittest
from contextlib import ExitStack
from types import SimpleNamespace
from unittest.mock import Mock, patch

import ghostty
import capture
import check_delta
import compose
from pathlib import Path

from PIL import Image, PngImagePlugin

from common import digest, environment_digest
from compare import compare_case
from capture import GEOMETRY, font_evidence
from compose import contact_sheet, showcase
from render import frame_geometry, window


class ExactPixels(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        self.actual, self.baseline, self.report = (root / name for name in ('actual', 'baseline', 'report'))
        for directory in (self.actual, self.baseline, self.report):
            directory.mkdir()
        self.case = 'fzf-dusk'
        self.image = Image.new('RGBA', (2, 2), (10, 20, 30, 255))
        self.image.save(self.baseline / f'{self.case}.png')

    def result(self):
        return compare_case(self.case, self.actual, self.baseline, self.report)

    def test_one_rgb_channel_difference_fails(self):
        self.image.putpixel((0, 0), (11, 20, 30, 255))
        self.image.save(self.actual / f'{self.case}.png')
        self.assertEqual(self.result(), 'Pixels changed (no tolerance)')

    def test_alpha_only_difference_fails(self):
        self.image.putpixel((0, 0), (10, 20, 30, 254))
        self.image.save(self.actual / f'{self.case}.png')
        self.assertEqual(self.result(), 'Pixels changed (no tolerance)')
        with Image.open(self.report / f'{self.case}-diff.png') as difference:
            self.assertEqual(difference.getpixel((0, 0)), (255, 255, 255))
            self.assertEqual(difference.getpixel((1, 1)), (0, 0, 0))

    def test_png_metadata_is_not_a_pixel_difference(self):
        metadata = PngImagePlugin.PngInfo()
        metadata.add_text('comment', 'Different encoding, identical pixels')
        self.image.save(self.actual / f'{self.case}.png', pnginfo=metadata)
        self.assertIsNone(self.result())


class CompositeEnvironment(unittest.TestCase):
    def test_partial_composition_requires_the_complete_same_environment(self):
        environment = {
            'image_recipe_sha256': environment_digest(Path('/repo')),
            'render_environment': {'LP_NUM_THREADS': '1'},
            'font_faces': {'normal': {'sha256': 'font-a'}},
            'mesa_version': 'mesa-a', 'geometry': {'rows': 16},
        }
        for field, changed in (
            ('render_environment', {'LP_NUM_THREADS': '2'}),
            ('font_faces', {'normal': {'sha256': 'font-b'}}),
            ('mesa_version', 'mesa-b'), ('geometry', {'rows': 17}), (None, None),
        ):
            with self.subTest(field=field), tempfile.TemporaryDirectory() as temporary:
                actual, baseline = (Path(temporary) / name for name in ('actual', 'baseline'))
                for directory in (actual, baseline):
                    directory.mkdir()
                recorded = {'format_version': 1, 'cases': {}}
                for schema in ('dusk', 'opal', 'mira', 'mesa'):
                    case = f'fzf-{schema}'
                    image = baseline / f'{case}.png'
                    Image.new('RGBA', (4, 4), '#123456').save(image)
                    recorded['cases'][case] = {'png_sha256': digest(image), 'inputs': {},
                                               'environment': copy.deepcopy(environment)}
                (baseline / 'manifest.json').write_text(json.dumps(recorded))
                before = (baseline / 'manifest.json').read_bytes()
                fresh = copy.deepcopy(recorded['cases']['fzf-dusk'])
                if field:
                    fresh['environment'][field] = changed
                self.assertEqual(fresh['environment']['image_recipe_sha256'], environment['image_recipe_sha256'])
                (actual / 'fzf-dusk.png').write_bytes((baseline / 'fzf-dusk.png').read_bytes())
                (actual / 'manifest.json').write_text(json.dumps({'format_version': 1, 'cases': {'fzf-dusk': fresh}}))
                manifest_before = (actual / 'manifest.json').read_bytes()
                if field:
                    with self.assertRaisesRegex(ValueError, 'Refresh all palettes'):
                        compose.compose(actual, baseline, ['fzf-dusk'])
                    self.assertFalse((actual / 'contact-fzf.png').exists())
                    self.assertEqual((actual / 'manifest.json').read_bytes(), manifest_before)
                else:
                    compose.compose(actual, baseline, ['fzf-dusk'])
                    first = (actual / 'contact-fzf.png').read_bytes()
                    compose.compose(actual, baseline, ['fzf-dusk'])
                    self.assertEqual((actual / 'contact-fzf.png').read_bytes(), first)
                self.assertEqual((baseline / 'manifest.json').read_bytes(), before)


class FaithfulRendering(unittest.TestCase):
    def test_font_faces_are_semibold_and_real_bold_italic_variants(self):
        faces = font_evidence()
        self.assertEqual(faces['normal']['filename'], 'JetBrainsMonoNerdFontMono-SemiBold.ttf')
        self.assertEqual(faces['bold']['filename'], 'JetBrainsMonoNerdFontMono-Bold.ttf')
        self.assertEqual(faces['italic']['filename'], 'JetBrainsMonoNerdFontMono-SemiBoldItalic.ttf')
        self.assertEqual(faces['bold_italic']['filename'], 'JetBrainsMonoNerdFontMono-BoldItalic.ttf')
        self.assertTrue(all(len(face['sha256']) == 64 for face in faces.values()))

    def test_opaque_terminal_colors_are_preserved_in_every_channel(self):
        # These deliberately awkward RGB values expose RGB/YUV rounding.
        colors = ((35, 33, 54, 255), (242, 239, 247, 255), (7, 123, 231, 255), (251, 1, 127, 255))
        text = Image.new('RGBA', (1400, 100), colors[0])
        for x, color in enumerate(colors):
            text.putpixel((50 + x, 50), color)
        cursor = Image.new('RGBA', text.size)
        geometry = GEOMETRY | frame_geometry(text.width)
        result = window(text, cursor, {'background': '#232136', 'foreground': '#c9c5d9'}, geometry)
        x, y = geometry['padding'] + 50, geometry['padding'] + geometry['titlebar_height'] + 50
        for offset, color in enumerate(colors):
            self.assertEqual(result.getpixel((x + offset, y)), color)
        self.assertEqual(result.getpixel((0, 0))[3], 0)
        self.assertEqual(result.getpixel((geometry['button_inset'], geometry['titlebar_height'] // 2)), (242, 105, 90, 255))

    def test_titlebar_has_buttons_but_no_title_text(self):
        terminal = Image.new('RGBA', (500, 100), '#232136')
        geometry = GEOMETRY | frame_geometry(terminal.width)
        result = window(terminal, Image.new('RGBA', terminal.size), {'background': '#232136'}, geometry)
        center = result.width // 2
        plain = result.crop((center - 100, 5, center + 100, geometry['titlebar_height'] - 5))
        self.assertEqual(plain.getcolors(plain.width * plain.height), [(plain.width * plain.height, (35, 33, 54, 255))])

    def test_cursor_composition_preserves_opaque_colors(self):
        text = Image.new('RGBA', (160, 100), '#232136')
        cursor = Image.new('RGBA', text.size)
        cursor.putpixel((50, 50), (125, 172, 187, 255))
        geometry = GEOMETRY | frame_geometry(text.width)
        result = window(text, cursor, {'background': '#232136', 'foreground': '#c9c5d9'}, geometry)
        self.assertEqual(result.getpixel((geometry['padding'] + 50, geometry['padding'] + geometry['titlebar_height'] + 50)), (125, 172, 187, 255))

    def test_frame_proportions_match_at_a_shared_gallery_width(self):
        ratios = {key: [] for key in ('button_radius', 'button_spacing', 'button_inset',
                                      'titlebar_height', 'padding', 'corner_radius')}
        for terminal_width in (1400, 1848, 2300, 2576):
            geometry = frame_geometry(terminal_width)
            width = terminal_width + 2 * geometry['padding']
            for key in ratios:
                ratios[key].append(geometry[key] / width)
        for key, values in ratios.items():
            with self.subTest(part=key):
                self.assertLess(max(values) - min(values), 0.0007)
        self.assertLess(2 * frame_geometry(1400)['button_radius'] + 1, 20)

    def test_contact_sheet_preserves_transparent_corners(self):
        image = Image.new('RGBA', (160, 100), (255, 0, 0, 255))
        image.putpixel((0, 0), (255, 0, 0, 0))
        result = contact_sheet([image] * 4)
        self.assertEqual(result.getpixel((24, 60)), (28, 27, 32))
        self.assertEqual(result.getpixel((25, 61)), (255, 0, 0))

    def test_hero_keeps_the_foreground_statusline_inside_the_canvas(self):
        image = Image.new('RGBA', (1952, 1504), (0, 255, 0, 255))
        image.paste((255, 0, 255, 255), (0, 1444, 1952, 1504))
        result = showcase([image] * 4)
        self.assertEqual(result.getpixel((1960, 1690)), (255, 0, 255))

    def test_mismatched_layers_are_rejected(self):
        with self.assertRaisesRegex(ValueError, 'dimensions differ'):
            window(Image.new('RGBA', (10, 10)), Image.new('RGBA', (9, 10)), {}, GEOMETRY)


class GhosttyScenarios(unittest.TestCase):
    def test_native_checker_and_font_failures_precede_case_log_creation(self):
        for checker, case in ((check_delta, 'delta-dusk'), (capture, 'fzf-dusk')):
            with self.subTest(case=case), tempfile.TemporaryDirectory() as temporary:
                output = Path(temporary)
                method = 'check' if checker is check_delta else 'font_evidence'
                with patch.object(capture, 'OUTPUT', output), \
                     patch.object(checker, method, side_effect=ValueError('pre-log checker failure')), \
                     patch.object(ghostty, 'capture_terminal') as terminal:
                    with self.assertRaisesRegex(ValueError, 'pre-log checker failure'):
                        capture.capture(case)
                    terminal.assert_not_called()
                self.assertEqual(list(output.iterdir()), [])

    def test_shared_tapes_have_known_launches_and_instructions(self):
        for path in Path('/repo/tests/snapshots').glob('*.tape'):
            with self.subTest(app=path.stem), patch.object(ghostty, 'wait_screen') as wait, \
                 patch.object(ghostty, 'command'), patch.object(ghostty.time, 'sleep'):
                ghostty.run_scenario(ghostty.scenario(path, path.stem), 'window', Mock())
                self.assertGreater(wait.call_count, 0)

    def test_neovim_posix_whitespace_pattern_matches_screen_text(self):
        with patch.object(ghostty, 'screen_text', return_value='  NORMAL  main.go    17:1  \n'):
            ghostty.wait_screen('window', r'(?m) [0-9]+:[0-9]+[[:space:]]*$', SimpleNamespace(poll=lambda: None))

    def test_previous_runtime_evidence_is_removed_before_launch(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            case = 'neovim-completion-go-dusk'
            runtime = output / f'{case}-runtime.json'
            runtime.write_text('{"completion": true}')

            def inspect_launch(*args):
                self.assertFalse(runtime.exists())
                raise RuntimeError('checked fresh launch')

            with patch.object(capture, 'OUTPUT', output), patch.object(capture, 'font_evidence', return_value={}), \
                 patch.object(ghostty, 'capture_terminal', side_effect=inspect_launch):
                with self.assertRaisesRegex(RuntimeError, 'checked fresh launch'):
                    capture.capture(case)

    def test_terminal_forces_native_blending_and_software_rendering_despite_host_overrides(self):
        host = {'GALLIUM_DRIVER': 'softpipe', 'LP_NUM_THREADS': '32',
                'LIBGL_ALWAYS_SOFTWARE': '0', 'EXTRA': 'preserved'}
        with patch.dict(ghostty.os.environ, host, clear=True), \
             patch.object(ghostty.Path, 'mkdir'), patch.object(ghostty, 'start_display'), \
             patch.object(ghostty, 'start', side_effect=RuntimeError('checked renderer')) as start:
            with self.assertRaisesRegex(RuntimeError, 'checked renderer'):
                ghostty.capture_terminal(Path('/repo'), Path('/output'), 'neovim-zig-dusk',
                                         {'app': 'neovim'}, GEOMETRY, Mock())
        self.assertIn('--alpha-blending=native', start.call_args.args)
        self.assertIn('--font-family=JetBrainsMono Nerd Font Mono', start.call_args.args)
        self.assertIn('--font-style=SemiBold', start.call_args.args)
        environment = start.call_args.kwargs['env']
        self.assertEqual(environment['EXTRA'], 'preserved')
        self.assertEqual({key: environment[key] for key in ghostty.RENDER_ENV}, {
            'LIBGL_ALWAYS_SOFTWARE': '1', 'GALLIUM_DRIVER': 'llvmpipe',
            'LP_NUM_THREADS': '1',
        })

    def test_occupied_display_is_rejected_before_launch(self):
        with patch.object(ghostty.Path, 'exists', return_value=True), patch.object(ghostty, 'start') as start:
            with self.assertRaisesRegex(RuntimeError, 'already occupied'):
                ghostty.start_display(Mock(), Mock())
            start.assert_not_called()

    def test_display_does_not_reset_between_probe_and_terminal_launch(self):
        with patch.object(ghostty.Path, 'exists', return_value=False), \
             patch.object(ghostty, 'start', return_value=SimpleNamespace(poll=lambda: None)) as start, \
             patch.object(ghostty, 'command'):
            ghostty.start_display(Mock(), Mock())
            self.assertIn('-noreset', start.call_args.args)

    def test_display_must_be_alive_before_it_is_used(self):
        with patch.object(ghostty.Path, 'exists', return_value=False), \
             patch.object(ghostty, 'start', return_value=SimpleNamespace(poll=lambda: 1)), \
             patch.object(ghostty, 'command') as command:
            with self.assertRaisesRegex(RuntimeError, 'did not start'):
                ghostty.start_display(Mock(), Mock())
            command.assert_not_called()

    def test_failed_process_is_not_accepted_as_ready(self):
        with self.assertRaisesRegex(RuntimeError, 'exited before'):
            ghostty.wait_screen('window', 'ready', SimpleNamespace(poll=lambda: 1))

    def test_clipboard_path_outside_private_tmp_is_not_read(self):
        with patch.object(ghostty, 'command', return_value='/repo/examples/flume.go'), \
             patch.object(ghostty.time, 'sleep'):
            self.assertEqual(ghostty.screen_text('window'), '')

    def test_capture_processes_are_reaped_on_failure(self):
        process = Mock()
        process.poll.return_value = None
        with patch.object(ghostty.subprocess, 'Popen', return_value=process):
            with self.assertRaisesRegex(RuntimeError, 'capture failed'):
                with ExitStack() as stack:
                    ghostty.start(stack, Mock(), 'ghostty')
                    raise RuntimeError('capture failed')
        process.terminate.assert_called_once()
        process.wait.assert_called_once_with(timeout=5)


if __name__ == '__main__':
    unittest.main()
