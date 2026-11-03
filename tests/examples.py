"""Behavior and viewport checks for the gallery fixtures."""

import importlib.util
import json
import re
import subprocess
import sys
import tempfile
import tomllib
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location("flume_example", ROOT / "examples/flume.py")
example = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(example)


class ContrastPairExample(unittest.TestCase):
    def test_black_and_white_have_the_standard_contrast(self):
        self.assertEqual(example.luminance("#000000"), 0)
        self.assertEqual(example.luminance("#ffffff"), 1)
        self.assertEqual(example.Pair("text", "#000000", "#ffffff").ratio, 21)
        self.assertEqual(example.Pair("text", "#ffffff", "#000000").ratio, 21)

    def test_identical_colors_have_no_contrast(self):
        self.assertEqual(example.Pair("text", "#292938", "#292938").ratio, 1)

    def test_non_literal_colors_are_rejected_on_either_side(self):
        for color in ("red", "#fff", "#ffffff00", "#gggggg", "#ffffff\n"):
            for foreground, background in ((color, "#000000"), ("#ffffff", color)):
                with self.subTest(foreground=foreground, background=background):
                    with self.assertRaisesRegex(ValueError, "Non-literal color in text"):
                        example.Pair("text", foreground, background)

    def test_script_reports_the_example_pair(self):
        result = subprocess.run(
            [sys.executable, str(ROOT / "examples/flume.py")],
            text=True, capture_output=True, check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertRegex(result.stdout, r"^editor text: \d+\.\d{2}:1 PASS\n$")


class ConfigExample(unittest.TestCase):
    def test_toml_values(self):
        config = tomllib.loads((ROOT / "examples/flume.toml").read_text())
        self.assertEqual(config["server"]["port"], 8080)
        self.assertIs(config["cache"]["enabled"], False)
        self.assertEqual(config["cache"]["max_entries"], 1024)
        self.assertEqual(config["assets"]["fingerprint_pattern"], r"\.[a-f0-9]{8}\.")
        self.assertEqual(config["routes"][0]["body"], "ok\n")
        self.assertEqual(config["routes"][1]["body"], "Night radio is on air.\nPull up a chair.\n")


class ExampleViewport(unittest.TestCase):
    def test_lsp_workspace_creation_is_private_and_rejects_existing_data(self):
        source = (ROOT / 'examples/lsp-showcase.lua').read_text()
        creation = next(line for line in source.splitlines() if line.startswith('assert(vim.fn.mkdir(workspace'))
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            workspace = directory / 'workspace'
            script = directory / 'workspace-test.lua'
            script.write_text('\n'.join([
                'local workspace = ' + json.dumps(str(workspace)),
                creation,
                'assert(vim.fn.getfperm(workspace) == "rwx------")',
                'vim.fn.writefile({"preserved"}, workspace .. "/keep")',
                'local ok = pcall(function() ' + creation + ' end)',
                'assert(not ok, "Existing workspace must be rejected")',
                'assert(vim.fn.readfile(workspace .. "/keep")[1] == "preserved")',
            ]))
            result = subprocess.run(['nvim', '--headless', '--clean', '-l', str(script)],
                                    text=True, capture_output=True, timeout=15)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((workspace / 'keep').read_text(), 'preserved\n')

    def test_completion_fixture_uses_the_shipped_palette_backgrounds(self):
        source = (ROOT / 'examples/completion.go').read_text()
        for schema in ('dusk', 'opal', 'mira', 'mesa'):
            export = (ROOT / f'extras/ghostty/flume-{schema}').read_text()
            background = next(line.split('=', 1)[1].strip() for line in export.splitlines() if line.startswith('background ='))
            self.assertIn(f'{{Name: "{schema}", Background: "{background}"}}', source)
        self.assertLessEqual(len(source.splitlines()), 46)
        self.assertLessEqual(max(len(line) for line in source.splitlines()), 92)

    def test_complete_files_fit_capture(self):
        import sys
        sys.path.insert(0, str(ROOT / 'tests/snapshots'))
        from common import SCENES
        rows = SCENES['neovim-go']['rows']
        columns = SCENES['neovim-go']['columns']
        for extension in ("go", "rs", "py", "ts", "tsx", "zig", "ex", "toml"):
            source = ROOT / f"examples/flume.{extension}"
            with self.subTest(source=source.name):
                lines = source.read_text().splitlines()
                # Leave room for status/command lines and the number column.
                capture_rows = rows
                capture_columns = columns
                if extension == "zig":
                    capture_rows = SCENES['neovim-zig']['rows']
                    capture_columns = SCENES['neovim-zig']['columns']
                self.assertLessEqual(len(lines), capture_rows - 2)
                self.assertLessEqual(max(len(line.expandtabs(8)) for line in lines), capture_columns - 8)


if __name__ == "__main__":
    unittest.main()
