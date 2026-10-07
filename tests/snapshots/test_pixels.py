"""Exercise Pillow's exact comparator in the same image used for capture."""

import tempfile
import unittest
from pathlib import Path

from PIL import Image, PngImagePlugin

from compare import compare_case


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


if __name__ == '__main__':
    unittest.main()
