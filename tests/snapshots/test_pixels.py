"""Exercise Pillow's exact comparator in the same image used for capture."""

import tempfile
import unittest
from pathlib import Path

from PIL import Image, PngImagePlugin

from compare import compare_case
from capture import GEOMETRY, font_evidence
from compose import contact_sheet, showcase
from render import last_frame, window


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


class FaithfulRendering(unittest.TestCase):
    def test_font_faces_are_medium_and_real_bold_italic_variants(self):
        faces = font_evidence()
        self.assertEqual(faces['normal']['filename'], 'MapleMono-NF-Medium.ttf')
        self.assertEqual(faces['bold']['filename'], 'MapleMono-NF-Bold.ttf')
        self.assertEqual(faces['italic']['filename'], 'MapleMono-NF-MediumItalic.ttf')
        self.assertEqual(faces['bold_italic']['filename'], 'MapleMono-NF-BoldItalic.ttf')
        self.assertTrue(all(len(face['sha256']) == 64 for face in faces.values()))

    def test_opaque_terminal_colors_are_preserved_in_every_channel(self):
        # These deliberately awkward RGB values expose RGB/YUV rounding.
        colors = ((35, 33, 54, 255), (242, 239, 247, 255), (7, 123, 231, 255), (251, 1, 127, 255))
        text = Image.new('RGBA', (160, 100), colors[0])
        for x, color in enumerate(colors):
            text.putpixel((50 + x, 50), color)
        cursor = Image.new('RGBA', text.size)
        result = window(text, cursor, {'background': '#232136', 'foreground': '#c9c5d9'}, GEOMETRY)
        x, y = GEOMETRY['padding'] + 50, GEOMETRY['padding'] + GEOMETRY['titlebar_height'] + 50
        for offset, color in enumerate(colors):
            self.assertEqual(result.getpixel((x + offset, y)), color)
        self.assertEqual(result.getpixel((0, 0))[3], 0)
        self.assertEqual(result.getpixel((32, GEOMETRY['titlebar_height'] // 2)), (255, 95, 87, 255))

    def test_titlebar_has_buttons_but_no_title_text(self):
        terminal = Image.new('RGBA', (500, 100), '#232136')
        result = window(terminal, Image.new('RGBA', terminal.size), {'background': '#232136'}, GEOMETRY)
        center = result.width // 2
        plain = result.crop((center - 100, 5, center + 100, GEOMETRY['titlebar_height'] - 5))
        self.assertEqual(plain.getcolors(plain.width * plain.height), [(plain.width * plain.height, (35, 33, 54, 255))])

    def test_cursor_composition_preserves_opaque_colors(self):
        text = Image.new('RGBA', (160, 100), '#232136')
        cursor = Image.new('RGBA', text.size)
        cursor.putpixel((50, 50), (125, 172, 187, 255))
        result = window(text, cursor, {'background': '#232136', 'foreground': '#c9c5d9'}, GEOMETRY)
        self.assertEqual(result.getpixel((GEOMETRY['padding'] + 50, GEOMETRY['padding'] + GEOMETRY['titlebar_height'] + 50)), (125, 172, 187, 255))

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

    def test_missing_final_cursor_cannot_reuse_an_earlier_frame(self):
        with tempfile.TemporaryDirectory() as temporary:
            frames = Path(temporary)
            for name in ('frame-text-00001.png', 'frame-cursor-00001.png', 'frame-text-00002.png'):
                (frames / name).write_bytes(b'frame')
            with self.assertRaisesRegex(ValueError, 'frame-cursor-00002'):
                last_frame(frames)

    def test_frame_layers_cannot_be_symlinks(self):
        with tempfile.TemporaryDirectory() as temporary:
            frames = Path(temporary)
            text = frames / 'frame-text-00001.png'
            text.write_bytes(b'frame')
            (frames / 'frame-cursor-00001.png').symlink_to(text)
            with self.assertRaisesRegex(ValueError, 'unsafe terminal layer'):
                last_frame(frames)


if __name__ == '__main__':
    unittest.main()
