"""Local Markdown and HTML preview links use the same validation rules."""

import importlib.util
import io
import tempfile
import unittest
from contextlib import redirect_stderr
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("check_links", ROOT / "scripts/check-links.py")
links = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(links)


class DocumentationLinks(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.document = self.root / "README.md"
        (self.root / "preview.png").write_bytes(b"fixture image")

    def check(self, text):
        self.document.write_text(text)
        with patch.multiple(links, ROOT=self.root, FILES=(self.document,)):
            links.main()

    def test_markdown_and_html_targets_are_collected(self):
        self.assertEqual(
            links.link_targets(
                '[Preview](preview.png) <a href="preview.png"><img src=\'preview.png\' /></a>'
            ),
            ["preview.png", "preview.png", "preview.png"],
        )

    def test_existing_preview_and_external_links_pass(self):
        self.check(
            '<a href="preview.png#detail"><img src="preview.png" /></a>\n'
            '<a href="https://example.com">External</a> <a href="#palettes">Palettes</a>'
        )

    def test_html_paths_with_spaces_and_markdown_titles_pass(self):
        (self.root / "preview image.png").write_bytes(b"fixture image")
        self.check(
            '<img src="preview image.png" /> [Preview](preview.png "Preview title")'
        )

    def test_missing_html_preview_targets_fail(self):
        for attribute in ("href", "src"):
            with self.subTest(attribute=attribute), redirect_stderr(io.StringIO()) as errors:
                with self.assertRaises(SystemExit):
                    self.check(f'<a {attribute}="missing.png">Preview</a>')
                self.assertIn("README.md: missing missing.png", errors.getvalue())

    def test_missing_markdown_target_still_fails(self):
        with redirect_stderr(io.StringIO()) as errors:
            with self.assertRaises(SystemExit):
                self.check("[Preview](missing.png)")
            self.assertIn("README.md: missing missing.png", errors.getvalue())


if __name__ == "__main__":
    unittest.main()
