"""Parser-free checks for canonical capture provenance."""

import importlib.util
import json
import os
import shutil
import struct
import subprocess
import tempfile
import unittest
from contextlib import ExitStack
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location(
    "preflight", ROOT / "scripts/preflight-screenshots.py"
)
preflight = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(preflight)


class CaptureProvenance(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        files = [
            "examples/showcase.lua",
            "examples/states.lua",
            "examples/states.go",
            "examples/lsp-showcase.lua",
            "examples/flume.zig",
            "scripts/screenshot-window.sh",
            "scripts/preflight-screenshots.py",
            "lua/flume/init.lua",
            "lua/flume/palette.lua",
        ]
        files += [
            str(path.relative_to(ROOT)) for path in (ROOT / "lua/flume/languages").glob("*.lua")
        ]
        files += [f"extras/ghostty/flume-{schema}" for schema in ("dusk", "opal", "mira", "mesa")]
        files += [f"examples/flume.{extension}" for extension in ("rs", "tsx", "py", "go", "ex", "toml")]
        files += [str(path.relative_to(ROOT)) for path in preflight.CAPTURES]
        files += [str(path.with_suffix(".json").relative_to(ROOT)) for path in preflight.CAPTURES]
        for name in files:
            (self.root / name).parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, self.root / name)
        stack = ExitStack()
        self.addCleanup(stack.close)
        stack.enter_context(
            patch.multiple(
                preflight,
                ROOT=self.root,
                CAPTURES=tuple(self.root / path.relative_to(ROOT) for path in preflight.CAPTURES),
            )
        )
        stack.enter_context(patch.object(preflight.sys, "argv", ["preflight"]))
        stack.enter_context(patch.object(preflight.shutil, "which", return_value="tesseract"))
        stack.enter_context(
            patch.object(preflight.subprocess, "run", return_value=SimpleNamespace(stdout=""))
        )

    def test_current_captures_pass(self):
        preflight.main()

    def state_runtime(self, kind):
        parser = self.root / "runtime/parser/go.so"
        query = self.root / "runtime/queries/go/highlights.scm"
        parser.parent.mkdir(parents=True, exist_ok=True)
        query.parent.mkdir(parents=True, exist_ok=True)
        parser.write_bytes(b"fixture parser")
        query.write_text("(identifier) @variable\n")
        image = self.root / f"assets/screenshots/{kind}/dusk/go.png"
        image.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(self.root / "assets/screenshots/dusk/go.png", image)
        runtime = {
            "nvim": "test", "language": "go", "kind": kind,
            "parser": str(parser), "queries": [str(query)],
            "diff_text": True, "diagnostics": 4,
            "visual": kind == "selection", "completion": kind == "completion",
        }
        runtime_file = self.root / "runtime.json"
        return runtime, runtime_file, image

    def test_real_state_readiness_is_required(self):
        for kind, required in (("selection", "visual"), ("completion", "completion")):
            with self.subTest(kind=kind):
                runtime, runtime_file, _ = self.state_runtime(kind)
                runtime[required] = False
                runtime_file.write_text(json.dumps(runtime))
                with self.assertRaisesRegex(SystemExit, f"did not render {required}"):
                    preflight.record("dusk", "go", runtime_file, kind)

    def test_state_capture_provenance_is_checked(self):
        runtime, runtime_file, image = self.state_runtime("completion")
        runtime_file.write_text(json.dumps(runtime))
        preflight.record("dusk", "go", runtime_file, "completion")
        preflight.validate_capture(image)
        renderer = self.root / "examples/states.lua"
        renderer.write_text(renderer.read_text() + "\n-- changed\n")
        with self.assertRaisesRegex(SystemExit, "stale renderer_sha256"):
            preflight.validate_capture(image)

    def test_lsp_requires_server_tokens(self):
        runtime, runtime_file, _ = self.state_runtime("lsp")
        runtime["server"] = {"token_counts": {}}
        runtime_file.write_text(json.dumps(runtime))
        with self.assertRaisesRegex(SystemExit, "did not report semantic tokens"):
            preflight.record("dusk", "go", runtime_file, "lsp")

    def test_lsp_records_server_identity_without_machine_paths(self):
        runtime, runtime_file, image = self.state_runtime("lsp")
        executable = self.root / "server"
        executable.write_bytes(b"fixture server")
        runtime["server"] = {
            "name": "gopls", "version": "test", "settings": {},
            "token_counts": {"function": 2}, "executable": str(executable),
        }
        runtime_file.write_text(json.dumps(runtime))
        preflight.record("dusk", "go", runtime_file, "lsp")
        preflight.validate_capture(image)
        metadata = json.loads(image.with_suffix(".json").read_text())
        self.assertEqual(metadata["server_executable_sha256"], preflight.digest(executable))
        self.assertNotIn(str(self.root), json.dumps(metadata))

    def test_changed_image_is_rejected(self):
        image = self.root / "assets/screenshots/dusk/zig.png"
        image.write_bytes(image.read_bytes() + b"changed")
        with self.assertRaisesRegex(SystemExit, "stale image_sha256"):
            preflight.main()

    def test_changed_renderer_is_rejected(self):
        renderer = self.root / "examples/showcase.lua"
        renderer.write_text(renderer.read_text() + "\n-- changed\n")
        with self.assertRaisesRegex(SystemExit, "stale renderer_sha256"):
            preflight.main()

    def test_changed_theme_is_rejected(self):
        for name in (
            "lua/flume/init.lua",
            "lua/flume/palette.lua",
            "lua/flume/languages/zig.lua",
            "extras/ghostty/flume-dusk",
        ):
            with self.subTest(input=name):
                path = self.root / name
                original = path.read_bytes()
                path.write_bytes(original + b"\nchanged\n")
                with self.assertRaisesRegex(SystemExit, "stale theme inputs"):
                    preflight.main()
                path.write_bytes(original)

    def test_failed_gui_cannot_reuse_headless_metadata(self):
        fake_bin = self.root / "bin"
        fake_bin.mkdir()
        app = self.root / "Ghostty.app"
        executable = app / "Contents/MacOS/ghostty"
        executable.parent.mkdir(parents=True)
        executable.write_text("#!/bin/sh\nexec tail -f /dev/null\n")
        executable.chmod(0o700)
        runtime = self.root / "runtime"
        runtime.mkdir()
        parser, query = runtime / "zig.so", runtime / "highlights.scm"
        parser.write_bytes(b"test parser")
        query.write_text("(identifier) @variable\n")
        metadata = json.dumps({"nvim": "test", "parser": str(parser), "queries": [str(query)]})
        commands = {
            "nvim": "printf '%s\\n' '" + metadata + '\' > "$FLUME_SHOWCASE_METADATA"\n',
            "osascript": "case \"$*\" in *'POSIX path'*) printf '%s/\\n' '"
            + str(app)
            + "';; esac\n",
            "screencapture": "for last do :; done\nprintf 'capture' > \"$last\"\n",
            "swift": "printf '123\\n'\n",
            "magick": "printf 'failed GUI capture' > \"${3#PNG24:}\"\n",
        }
        for name, body in commands.items():
            command = fake_bin / name
            command.write_text("#!/bin/sh\n" + body)
            command.chmod(0o700)
        image = self.root / "assets/screenshots/dusk/zig.png"
        original = image.read_bytes()
        # Popen bypasses the OCR run() mock and executes the actual capture
        # script with a successful headless probe but no GUI completion.
        process = subprocess.Popen(
            ["bash", str(self.root / "scripts/screenshot-window.sh"), "dusk"],
            cwd=self.root,
            env={**os.environ, "PATH": str(fake_bin) + os.pathsep + os.environ["PATH"]},
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        stdout, stderr = process.communicate(timeout=15)
        self.assertNotEqual(process.returncode, 0, stdout)
        self.assertIn("parser-backed fixture did not finish loading", stderr)
        self.assertEqual(image.read_bytes(), original)

    def test_mixed_runtimes_are_rejected(self):
        sidecar = self.root / "assets/screenshots/opal/zig.json"
        metadata = json.loads(sidecar.read_text())
        metadata["parser"]["sha256"] = "different"
        sidecar.write_text(json.dumps(metadata))
        with self.assertRaisesRegex(SystemExit, "different parser/query runtimes"):
            preflight.main()

    def test_changed_language_fixture_is_rejected(self):
        source = self.root / "examples/flume.rs"
        source.write_text(source.read_text() + "\n// changed\n")
        with self.assertRaisesRegex(SystemExit, "stale fixture_sha256"):
            preflight.main()

    def test_wrong_language_metadata_is_rejected(self):
        sidecar = self.root / "assets/screenshots/dusk/rust.json"
        metadata = json.loads(sidecar.read_text())
        metadata["language"] = "go"
        sidecar.write_text(json.dumps(metadata))
        with self.assertRaisesRegex(SystemExit, "does not describe this Tree-sitter capture"):
            preflight.main()

    def test_missing_gallery_capture_is_rejected(self):
        (self.root / "assets/screenshots/mesa/tsx.png").unlink()
        with self.assertRaisesRegex(SystemExit, "Missing canonical captures"):
            preflight.main()

    def test_dimensions_are_checked_across_palettes(self):
        image = self.root / "assets/screenshots/dusk/rust.png"
        data = bytearray(image.read_bytes())
        data[16:20] = struct.pack(">I", 1)
        image.write_bytes(data)
        with self.assertRaisesRegex(SystemExit, "capture dimensions differ"):
            preflight.main()

    def test_root_screenshots_are_rejected(self):
        (self.root / "screenshot-dusk.png").write_bytes(b"obsolete")
        with self.assertRaisesRegex(SystemExit, "Unexpected canonical capture names"):
            preflight.main()

    def test_painted_tokens_are_rejected(self):
        renderer = self.root / "examples/showcase.lua"
        renderer.write_text(renderer.read_text() + "\nvim.api.nvim_buf_set_extmark()\n")
        with self.assertRaisesRegex(SystemExit, "not painted tokens"):
            preflight.main()


if __name__ == "__main__":
    unittest.main()
