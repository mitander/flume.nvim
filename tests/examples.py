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


class EventSummaryExample(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.log = Path(temporary.name) / "events.jsonl"

    def write_events(self, events):
        self.log.write_text("\n".join(json.dumps(event) for event in events), encoding="utf-8")

    def run_script(self, *args):
        return subprocess.run(
            [sys.executable, str(ROOT / "examples/flume.py"), str(self.log), *args],
            text=True, capture_output=True, check=False,
        )

    def test_counts_and_blank_lines(self):
        self.write_events([{"event": "play"}, {"event": "pause"}, {"event": "play"}])
        with self.log.open("a", encoding="utf-8") as log:
            log.write("\n\n")
        self.assertEqual(example.count_events(self.log), {"play": 2, "pause": 1})
        result = self.run_script("--limit", "1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout,
            "3 events across 2 names\n" + f"{'play':<24} {2:>6,}  {2 / 3:>6.1%}\n",
        )

    def test_empty_log(self):
        self.log.write_text("", encoding="utf-8")
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "0 events across 0 names\n")

    def test_invalid_records(self):
        for record in ({}, [], {"event": None}, {"event": 42}, {"event": "  "}):
            with self.subTest(record=record):
                self.write_events([record])
                with self.assertRaisesRegex(ValueError, "line 1"):
                    example.count_events(self.log)

    def test_cli_errors_are_reported_without_tracebacks(self):
        self.log.write_text("not JSON\n", encoding="utf-8")
        result = self.run_script()
        self.assertEqual(result.returncode, 1)
        self.assertIn(str(self.log), result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        result = self.run_script("--limit", "0")
        self.assertEqual(result.returncode, 2)
        self.assertIn("--limit must be positive", result.stderr)


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
    def test_complete_files_fit_capture(self):
        script = (ROOT / "scripts/screenshot-window.sh").read_text()
        rows = int(re.search(r"GHOSTTY_ROWS=(\d+)", script)[1])
        columns = int(re.search(r"GHOSTTY_COLUMNS=(\d+)", script)[1])
        for extension in ("go", "rs", "py", "tsx", "zig", "ex", "toml"):
            source = ROOT / f"examples/flume.{extension}"
            with self.subTest(source=source.name):
                lines = source.read_text().splitlines()
                # Leave room for status/command lines and the number column.
                self.assertLessEqual(len(lines), rows - 2)
                self.assertLessEqual(max(len(line.expandtabs(8)) for line in lines), columns - 8)


if __name__ == "__main__":
    unittest.main()
