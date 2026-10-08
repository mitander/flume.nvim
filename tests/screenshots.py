"""Parser-free checks for canonical capture provenance."""

import importlib.util
import json
import shutil
import struct
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
            "examples/completion.lua", "examples/completion.go",
            "examples/states.go",
            "examples/lsp-showcase.lua",
            "examples/flume.zig",
            "scripts/preflight-screenshots.py",
            "tests/snapshots/fixtures/neovim.lua",
            "tests/snapshots/fixtures/neovim.sh",
            "tests/snapshots/neovim.tape",
            "lua/flume/init.lua",
            "lua/flume/palette.lua",
            "tests/snapshots/capture.py", "tests/snapshots/ghostty.py", "tests/snapshots/render.py", "tests/snapshots/Dockerfile",
            "tests/snapshots/tools.json", "tests/snapshots/install.py",
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

    def copy_state_captures(self):
        for kind in ("selection", "completion", "lsp"):
            for source in (ROOT / "assets/screenshots" / kind).rglob("*"):
                if source.suffix in (".png", ".json"):
                    destination = self.root / source.relative_to(ROOT)
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(source, destination)

    def test_state_ocr_is_opt_in(self):
        self.copy_state_captures()
        with (
            patch.object(preflight.sys, "argv", ["preflight", "--states"]),
            patch.object(preflight.shutil, "which", return_value=None),
            patch.object(preflight.subprocess, "run") as run,
        ):
            preflight.main()
            run.assert_not_called()

    def test_state_ocr_rejects_neovim_errors(self):
        self.copy_state_captures()
        with (
            patch.object(preflight.sys, "argv", ["preflight", "--states", "--ocr"]),
            patch.object(preflight.subprocess, "run", return_value=SimpleNamespace(stdout="E21: Not modifiable")),
        ):
            with self.assertRaisesRegex(SystemExit, "contains a Neovim error: E21:"):
                preflight.main()

    def test_state_ocr_allows_server_names(self):
        self.copy_state_captures()
        with (
            patch.object(preflight.sys, "argv", ["preflight", "--states", "--ocr"]),
            patch.object(preflight.subprocess, "run", return_value=SimpleNamespace(stdout="Tree-sitter + zls")) as run,
        ):
            preflight.main()
            self.assertEqual(run.call_count, 16)

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
        if kind == "completion":
            executable = self.root / "server"
            executable.write_bytes(b"fixture server")
            runtime.update(candidates=["TrimSpace", "TrimSuffix"], documentation="TrimSpace removes whitespace.",
                           frontend={"name": "blink.cmp", "border": "single"}, documentation_highlights=5)
            runtime["server"] = {"name": "gopls", "version": "test", "settings": {}, "executable": str(executable)}
        elif kind == "lsp":
            runtime["hover"] = ["func Count(ctx context.Context, start int)"]
        runtime_file = self.root / "runtime.json"
        return runtime, runtime_file, image

    def test_real_state_readiness_is_required(self):
        for kind, required in (("selection", "visual"), ("completion", "completion")):
            with self.subTest(kind=kind):
                runtime, runtime_file, _ = self.state_runtime(kind)
                runtime[required] = False
                runtime_file.write_text(json.dumps(runtime))
                with self.assertRaisesRegex(SystemExit, f"did not render {required}"):
                    preflight.record("dusk", "go", runtime_file, kind, image=self.root / f"assets/screenshots/{kind}/dusk/go.png")

    def test_state_capture_provenance_is_checked(self):
        runtime, runtime_file, image = self.state_runtime("completion")
        runtime_file.write_text(json.dumps(runtime))
        preflight.record("dusk", "go", runtime_file, "completion", image=image)
        preflight.validate_capture(image)
        renderer = self.root / "examples/completion.lua"
        renderer.write_text(renderer.read_text() + "\n-- changed\n")
        with self.assertRaisesRegex(SystemExit, "stale renderer_sha256"):
            preflight.validate_capture(image)

    def test_completion_requires_server_candidates_and_documentation(self):
        for field in ("server", "candidates", "documentation"):
            with self.subTest(field=field):
                runtime, runtime_file, image = self.state_runtime("completion")
                del runtime[field]
                runtime_file.write_text(json.dumps(runtime))
                with self.assertRaisesRegex(SystemExit, "server candidates and documentation"):
                    preflight.record("dusk", "go", runtime_file, "completion", image=image)

    def test_completion_requires_blink_highlighted_documentation(self):
        for field in ("frontend", "documentation_highlights"):
            with self.subTest(field=field):
                runtime, runtime_file, image = self.state_runtime("completion")
                del runtime[field]
                runtime_file.write_text(json.dumps(runtime))
                with self.assertRaisesRegex(SystemExit, "Blink highlighted documentation"):
                    preflight.record("dusk", "go", runtime_file, "completion", image=image)

    def test_lsp_requires_server_tokens(self):
        runtime, runtime_file, image = self.state_runtime("lsp")
        runtime["server"] = {"token_counts": {}}
        runtime_file.write_text(json.dumps(runtime))
        with self.assertRaisesRegex(SystemExit, "did not report semantic tokens"):
            preflight.record("dusk", "go", runtime_file, "lsp", image=image)

    def test_lsp_records_server_identity_without_machine_paths(self):
        runtime, runtime_file, image = self.state_runtime("lsp")
        executable = self.root / "server"
        executable.write_bytes(b"fixture server")
        runtime["server"] = {
            "name": "gopls", "version": "test", "settings": {},
            "token_counts": {"variable": 3, "function": 2}, "executable": str(executable),
        }
        runtime_file.write_text(json.dumps(runtime))
        preflight.record("dusk", "go", runtime_file, "lsp", image=image)
        preflight.validate_capture(image)
        metadata = json.loads(image.with_suffix(".json").read_text())
        self.assertEqual(metadata["server_executable_sha256"], preflight.digest(executable))
        self.assertNotIn(str(self.root), json.dumps(metadata))
        self.assertEqual(list(metadata["server"]["token_counts"]), ["function", "variable"])

    def test_missing_capture_renderer_is_rejected(self):
        sidecar = self.root / "assets/screenshots/dusk/zig.json"
        metadata = json.loads(sidecar.read_text())
        del metadata["capture_renderer"]
        sidecar.write_text(json.dumps(metadata))
        with self.assertRaisesRegex(SystemExit, "stale Ghostty capture inputs"):
            preflight.main()

    def test_legacy_record_commands_are_rejected(self):
        for option in ("--record", "--record-state"):
            with self.subTest(option=option), patch.object(preflight.sys, "argv", ["preflight", option]):
                with self.assertRaises(SystemExit) as error:
                    preflight.main()
                self.assertEqual(error.exception.code, 2)

    def test_source_check_inspects_current_editor_fixture(self):
        fixture = self.root / "tests/snapshots/fixtures/neovim.lua"
        fixture.write_text(fixture.read_text() + "\nvim.diagnostic.config({ virtual_text = true })\n")
        with patch.object(preflight.sys, "argv", ["preflight", "--source-only"]):
            with self.assertRaisesRegex(SystemExit, "presentation noise"):
                preflight.main()

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

    def test_language_viewports_may_differ(self):
        def language_dimensions(path):
            return (112, 32) if path.stem == "zig" else (100, 48)

        with patch.object(preflight, "dimensions", side_effect=language_dimensions):
            preflight.main()

    def test_dimensions_are_checked_across_palettes(self):
        image = self.root / "assets/screenshots/dusk/rust.png"
        data = bytearray(image.read_bytes())
        data[16:20] = struct.pack(">I", 1)
        image.write_bytes(data)
        with self.assertRaisesRegex(SystemExit, "capture dimensions differ"):
            preflight.main()

    def test_neovim_error_text_is_rejected(self):
        with patch.object(preflight.sys, 'argv', ['preflight', '--ocr']), patch.object(preflight.subprocess, "run", return_value=SimpleNamespace(
            stdout="E21: Cannot make changes, 'modifiable' is off\n"
        )):
            with self.assertRaisesRegex(SystemExit, "contains a Neovim error: E21:"):
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
