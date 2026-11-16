"""The whitespace gate distinguishes violations, absent tracked files and scan errors."""

import importlib.util
import io
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/check-whitespace.py"
SPEC = importlib.util.spec_from_file_location("check_whitespace", SCRIPT)
whitespace = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(whitespace)


class CheckWhitespace(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.git("init", "--quiet")

    def git(self, *arguments: str) -> None:
        subprocess.run(
            ["git", *arguments], cwd=self.root, check=True, capture_output=True
        )

    def scan(self) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(SCRIPT)], cwd=self.root, capture_output=True, text=True
        )

    def test_empty_and_clean_files_pass(self) -> None:
        self.assertEqual(self.scan().returncode, 0)
        (self.root / "tracked.md").write_bytes(b"clean\n\tindented\n")
        self.git("add", "--", "tracked.md")
        (self.root / "untracked.txt").write_bytes(b"clean without final newline")
        result = self.scan()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")

    def test_spaces_tabs_and_unterminated_lines_fail(self) -> None:
        (self.root / "bad.md").write_bytes(b"space \ntab\t\nlast ")
        result = self.scan()
        self.assertEqual(result.returncode, 1)
        for number in (1, 2, 3):
            self.assertIn(f"'bad.md':{number}: trailing whitespace", result.stderr)

    def test_tracked_deletion_does_not_hide_untracked_violation(self) -> None:
        tracked = self.root / "deleted.md"
        tracked.write_text("clean\n")
        self.git("add", "--", "deleted.md")
        tracked.unlink()
        self.assertEqual(self.scan().returncode, 0)

        (self.root / "untracked.md").write_bytes(b"bad \n")
        result = self.scan()
        self.assertEqual(result.returncode, 1)
        self.assertIn("'untracked.md':1: trailing whitespace", result.stderr)

    def test_unusual_filenames_are_scanned_and_quoted(self) -> None:
        for name in ("with spaces.md", "with\nnewline.md", "-option.md", "[glob].md"):
            with self.subTest(name=name):
                path = self.root / name
                path.write_bytes(b"clean\n")
                self.assertEqual(self.scan().returncode, 0)
                path.write_bytes(b"bad\t\n")
                result = self.scan()
                self.assertEqual(result.returncode, 1)
                self.assertIn(f"{name!r}:1: trailing whitespace", result.stderr)
                path.unlink()

    def test_ignored_and_out_of_scope_files_are_not_scanned(self) -> None:
        (self.root / ".gitignore").write_text("ignored.md\n")
        (self.root / "ignored.md").write_bytes(b"bad \n")
        (self.root / "image.bin").write_bytes(b"bad \n")
        self.assertEqual(self.scan().returncode, 0)

    def test_unreadable_file_fails_even_with_a_violation(self) -> None:
        unreadable = self.root / "unreadable.md"
        unreadable.write_text("clean\n")
        (self.root / "bad.md").write_bytes(b"bad \n")
        read_bytes = Path.read_bytes

        def read(path: Path) -> bytes:
            if path == unreadable:
                raise PermissionError("fixture read denied")
            return read_bytes(path)

        with patch.object(Path, "read_bytes", read), redirect_stderr(io.StringIO()) as errors:
            self.assertEqual(whitespace.check_whitespace(self.root), 2)
        self.assertIn("Cannot read 'unreadable.md'", errors.getvalue())
        self.assertIn("'bad.md':1: trailing whitespace", errors.getvalue())

    def test_broken_tracked_symlink_is_not_an_intentional_deletion(self) -> None:
        (self.root / "broken.md").symlink_to("missing.md")
        self.git("add", "--", "broken.md")
        result = self.scan()
        self.assertEqual(result.returncode, 2)
        self.assertIn("Cannot read 'broken.md'", result.stderr)

    def test_file_vanishing_after_enumeration_fails(self) -> None:
        with patch.object(whitespace, "git_paths", side_effect=[{"gone.md"}, set()]):
            with redirect_stderr(io.StringIO()) as errors:
                self.assertEqual(whitespace.check_whitespace(self.root), 2)
        self.assertIn("Cannot read 'gone.md'", errors.getvalue())

    def test_enumeration_outside_a_repository_fails(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run(
                [sys.executable, str(SCRIPT)], cwd=directory, capture_output=True, text=True
            )
        self.assertEqual(result.returncode, 2)
        self.assertIn("Cannot enumerate whitespace inputs", result.stderr)

    def test_deleted_inventory_failure_is_not_clean(self) -> None:
        error = subprocess.CalledProcessError(128, ["git", "ls-files", "--deleted"])
        with patch.object(whitespace, "git_paths", side_effect=[set(), error]):
            with redirect_stderr(io.StringIO()) as errors:
                self.assertEqual(whitespace.check_whitespace(self.root), 2)
        self.assertIn("Cannot enumerate whitespace inputs", errors.getvalue())

    def test_git_launch_failure_is_not_clean(self) -> None:
        with patch.object(whitespace.subprocess, "run", side_effect=FileNotFoundError("git")):
            with redirect_stderr(io.StringIO()) as errors:
                self.assertEqual(whitespace.check_whitespace(self.root), 2)
        self.assertIn("Cannot enumerate whitespace inputs", errors.getvalue())


if __name__ == "__main__":
    unittest.main()
