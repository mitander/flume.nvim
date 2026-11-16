"""Exported-pair measurements and opt-in native Lazygit installed-link checks."""

import hashlib
import importlib.util
import json
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "flume_review_report", ROOT / "scripts/review-integrations.py"
)
review = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = review
SPEC.loader.exec_module(review)
NATIVE_SPEC = importlib.util.spec_from_file_location(
    "flume_native_delta", ROOT / "tests/snapshots/check_delta.py"
)
native_delta = importlib.util.module_from_spec(NATIVE_SPEC)
sys.modules[NATIVE_SPEC.name] = native_delta
NATIVE_SPEC.loader.exec_module(native_delta)


class IntegrationReviewTests(unittest.TestCase):
    def test_reference_contrast_and_xterm_values(self):
        self.assertAlmostEqual(review.contrast("#000000", "#ffffff"), 21)
        self.assertAlmostEqual(review.contrast("#123456", "#123456"), 1)
        self.assertEqual(review.xterm_color(16, {}), "#000000")
        self.assertEqual(review.xterm_color(231, {}), "#ffffff")
        self.assertEqual(review.xterm_color(232, {}), "#080808")
        self.assertEqual(review.xterm_color(8, {8: "#abcdef"}), "#abcdef")

    def test_all_artifacts_measure_deterministically(self):
        current = review.measurements(ROOT)
        self.assertEqual(set(current), set(review.ARTIFACTS) | {"palette hierarchy"})
        for schemas in current.values():
            self.assertEqual(set(schemas), set(review.SCHEMAS))
            for pairs in schemas.values():
                self.assertTrue(pairs)
                self.assertEqual(len({pair.label for pair in pairs}), len(pairs))
                for pair in pairs:
                    self.assertGreaterEqual(pair.ratio, 1)
                    self.assertLessEqual(pair.ratio, 21)
        self.assertEqual(
            review.render(current), review.render(review.measurements(ROOT))
        )

    def test_selected_match_and_literal_rgb_colors_use_actual_exports(self):
        pairs = {
            pair.label: pair for pair in review.integration_pairs(ROOT, "fzf", "opal")
        }
        palette_path = ROOT / "extras/palette/flume-opal.json"
        colors = json.loads(palette_path.read_text())["colors"]
        selected_match = pairs["Match inside selected row"]
        self.assertEqual(selected_match.foreground, colors["match"])
        self.assertEqual(selected_match.background, colors["element_active"])
        lsd = {
            pair.label: pair for pair in review.integration_pairs(ROOT, "lsd", "opal")
        }
        self.assertEqual(
            lsd["permission.no-access (LSD host)"].foreground, "#615a68"
        )
        self.assertEqual(lsd["user (LSD host)"].foreground, "#514e57")

    def test_lazygit_selected_foreground_is_measured_instead_of_assumed(self):
        artifact = review.artifact
        for schema in review.SCHEMAS:
            colors = json.loads(
                (ROOT / f"extras/palette/flume-{schema}.json").read_text()
            )["colors"]
            pairs = {
                pair.label: pair
                for pair in review.integration_pairs(ROOT, "lazygit", schema)
            }
            selected = pairs["selectedLineBgColor"]
            self.assertEqual(selected.foreground, colors["syntax_primary"])
            self.assertEqual(selected.background, colors["element_active"])
            self.assertGreaterEqual(selected.ratio, 4.5)

            # The old literal foreground must expose the real low-contrast pair,
            # not be silently replaced with the application's ordinary text ink.
            content = artifact(ROOT, "lazygit", schema).replace(
                'selectedLineFgColor: ["default"]',
                f'selectedLineFgColor: ["{colors["selection_fg"]}"]',
            )

            def old_foreground(root: Path, app: str, name: str, ref: str | None = None) -> str:
                return content if app == "lazygit" else artifact(root, app, name, ref)

            with patch.object(review, "artifact", side_effect=old_foreground):
                broken = {
                    pair.label: pair
                    for pair in review.integration_pairs(ROOT, "lazygit", schema)
                }["selectedLineBgColor"]
            self.assertEqual(broken.foreground, colors["selection_fg"])
            self.assertLess(broken.ratio, 1.5)

    @unittest.skipUnless(
        os.environ.get("FLUME_NATIVE_LAZYGIT") == "1",
        "set FLUME_NATIVE_LAZYGIT=1 for installed-link, RGB and Delta renderer checks",
    )
    def test_native_lazygit_installed_bytes_and_rendering(self):
        for executable in ("git", "tmux", "lazygit", "nvim", "delta"):
            self.assertIsNotNone(shutil.which(executable), f"Install {executable} separately")
        directory = Path(tempfile.mkdtemp(prefix="flume-lazygit-native-")).resolve()
        home = directory / "home"
        home.mkdir()
        environment = {
            "PATH": os.environ.get("PATH", os.defpath),
            "HOME": str(home),
            "XDG_CONFIG_HOME": str(home / ".config"),
            "XDG_DATA_HOME": str(home / ".local/share"),
            "XDG_STATE_HOME": str(home / ".local/state"),
            "XDG_CACHE_HOME": str(home / ".cache"),
            "GIT_CONFIG_NOSYSTEM": "1",
            "TERM": "xterm-256color",
            "COLORTERM": "truecolor",
            "LANG": "en_US.UTF-8",
        }
        version = subprocess.check_output(
            ["lazygit", "--version"], env=environment, text=True, timeout=10,
        ).strip()
        (directory / "version.txt").write_text(version + "\n")
        print(f"Native Lazygit evidence: {directory}\n{version}")
        project = directory / "project"
        (project / "selected-folder").mkdir(parents=True)
        file = project / "selected-folder/modified.txt"
        file.write_text("before\n")
        for command in (
            ["git", "init", "--quiet"],
            ["git", "add", "."],
            ["git", "-c", "user.name=Flume Fixture", "-c", "user.email=fixture@example.test",
             "commit", "--quiet", "-m", "fixture"],
            ["git", "branch", "-m", "flume-native-branch"],
        ):
            subprocess.run(command, cwd=project, env=environment, check=True, timeout=10)
        file.write_text("after\n")
        (project / "z-untracked.txt").write_text("untracked\n")
        tmux = ["tmux", "-u", "-S", str(directory / "tmux.sock"), "-f", "/dev/null"]

        def run_tmux(*arguments: str) -> str:
            return subprocess.run(
                [*tmux, *arguments], env=environment, text=True, capture_output=True,
                check=True, timeout=10,
            ).stdout

        def observe(
            schema: str, *, broken: bool = False, metadata_control: bool = False,
            legacy: bool = False,
        ) -> tuple[dict[str, str], list[native_delta.Cell]]:
            suffix = ("-old-foreground" if broken else "-metadata-control" if metadata_control
                      else "-legacy-migration" if legacy else "")
            case = directory / (schema + suffix)
            case.mkdir()
            colors = json.loads((ROOT / f"extras/palette/flume-{schema}.json").read_text())["colors"]
            theme = (ROOT / f"extras/lazygit/flume-{schema}.yml").read_text()
            if broken:
                self.assertIn('selectedLineFgColor: ["default"]', theme)
                theme = theme.replace(
                    'selectedLineFgColor: ["default"]',
                    f'selectedLineFgColor: ["{colors["selection_fg"]}"]',
                )
            if metadata_control:
                theme = theme.replace(f'"*": "{colors["syntax_primary"]}"', '"*": "#123456"')
                theme = theme.replace(f'".*": "{colors["accent"]}"', '".*": "#abcdef"')
            if legacy:
                theme = theme.replace(
                    f'    authorColors:\n      "*": "{colors["syntax_primary"]}"',
                    f'  authorColors:\n    "*": "{colors["syntax_primary"]}"',
                ).replace(
                    f'    branchColorPatterns:\n      ".*": "{colors["accent"]}"',
                    f'  branchColorPatterns:\n    ".*": "{colors["accent"]}"',
                ).replace("  diffRenderers:", "  pagers:").replace("      command:", "      pager:")

            # Publish only from a private checkout. The public installer creates
            # the actual home -> current -> immutable-set chain under test.
            plugin = case / "plugin"
            for name in ("lua", "colors", "extras"):
                shutil.copytree(ROOT / name, plugin / name,
                                ignore=shutil.ignore_patterns("current", ".set-*", "__pycache__"))
            (plugin / f"extras/lazygit/flume-{schema}.yml").write_text(theme)
            case_home = case / "home"
            case_home.mkdir()
            case_environment = environment | {
                "HOME": str(case_home),
                "XDG_CONFIG_HOME": str(case_home / ".config"),
                "XDG_DATA_HOME": str(case_home / ".local/share"),
                "XDG_STATE_HOME": str(case_home / ".local/state"),
                "XDG_CACHE_HOME": str(case_home / ".cache"),
                "FLUME_DATA_DIR": str(case / "data"),
            }
            install = case / "install.lua"
            install.write_text(
                'vim.opt.runtimepath:prepend(' + json.dumps(str(plugin)) + ')\n'
                'vim.fn.system = function() error("No external reloads in this test") end\n'
                'require("flume").setup({schema = "' + schema + '", '
                'watch_sync = false, follow_sync = false})\n'
                'local result = require("flume.extras").install("lazygit")\n'
                'assert(result.status == "linked", result.message)\n'
                'vim.cmd("qa!")\n'
            )
            subprocess.run(
                ["nvim", "--headless", "--clean", "-l", str(install)],
                cwd=case, env=case_environment, check=True, capture_output=True, timeout=20,
            )
            installed = case_home / ".config/lazygit/flume.yml"
            current = case / "data/current"
            published = installed.resolve(strict=True)
            self.assertTrue(published.is_relative_to(case / "data"))
            self.assertEqual(published.read_bytes(), theme.encode())
            links = {str(path): os.readlink(path) for path in (installed, current)}
            before = {path: path.read_bytes() for path in published.parent.iterdir() if path.is_file()}
            (case / "theme-before.yml").write_bytes(before[published])
            before_hashes = {str(path): hashlib.sha256(data).hexdigest()
                             for path, data in before.items()}
            (case / "before-publication.json").write_text(json.dumps({
                "links": links, "published_path": str(published), "sha256": before_hashes,
            }, indent=2) + "\n")

            def check_publication(phase: str) -> None:
                after_links = {str(path): os.readlink(path) for path in (installed, current)}
                after = {path: path.read_bytes() for path in published.parent.iterdir() if path.is_file()}
                (case / (phase + "-publication.json")).write_text(json.dumps({
                    "links_before": links, "links_after": after_links,
                    "published_path": str(published),
                    "sha256_before": before_hashes,
                    "sha256_after": {str(path): hashlib.sha256(data).hexdigest()
                                     for path, data in after.items()},
                }, indent=2) + "\n")
                self.assertEqual(after_links, links)
                self.assertEqual(installed.resolve(strict=True), published)
                if legacy:
                    self.assertNotEqual(after[published], before[published], "Legacy migration control did not write")
                    self.assertIn(b"diffRenderers:", after[published])
                    self.assertNotIn(b"  pagers:", after[published])
                    self.assertEqual({p: b for p, b in after.items() if p != published},
                                     {p: b for p, b in before.items() if p != published})
                else:
                    self.assertEqual(after, before, "Lazygit changed immutable published bytes")

            # Log real Delta launches without substituting its rendering or
            # modifying the installed command. A raw-Git fallback cannot pass.
            bin_dir = case / "bin"
            bin_dir.mkdir()
            delta_log = case / "delta-invocations.txt"
            delta = bin_dir / "delta"
            delta.write_text(
                "#!/bin/sh\n"
                "printf '%s\\n' \"$*\" >> " + shlex.quote(str(delta_log)) + "\n"
                "exec " + shlex.quote(shutil.which("delta")) + ' "$@"\n'
            )
            delta.chmod(0o755)
            case_environment["PATH"] = str(bin_dir) + os.pathsep + environment["PATH"]
            (case / "config.yml").write_text(
                "disableStartupPopups: true\n"
                "gui:\n  showRandomTip: false\n  showCommandLog: false\n"
                "  showFileTree: true\n  showRootItemInFileTree: false\n"
                "  sidePanelWidth: 0.4\n"
                "git:\n  autoFetch: false\n  autoRefresh: false\n"
            )
            command = shlex.join([
                "env", *(f"{key}={value}" for key, value in case_environment.items()),
                "lazygit", "--use-config-dir", str(case), "--use-config-file",
                f"{case}/config.yml,{installed}", "--path", str(project),
            ])
            run_tmux("new-session", "-d", "-s", case.name, "-x", "110", "-y", "36", command)
            deadline = time.monotonic() + 15
            output = ""
            while time.monotonic() < deadline:
                output = run_tmux("capture-pane", "-e", "-p", "-t", case.name)
                rendered = native_delta.cells(output, colors)
                plain = "".join(cell.text for cell in rendered)
                # Match the directory row, not the diff header path prefix.
                if "selected-folder " in plain and " FF " in plain and "* flume-native-branch" in plain:
                    start = plain.index("selected-folder ")
                    selected = rendered[start:start + len("selected-folder")]
                    if all(cell.background == colors["element_active"] for cell in selected):
                        if "before" in plain and "after" in plain:
                            break
                    else:
                        run_tmux("send-keys", "-t", case.name, "2", "Home")
                time.sleep(0.05)
            else:
                (case / "capture.ansi").write_text(output)
                self.fail(f"Lazygit did not paint the selected folder and diff: {case}/capture.ansi")
            (case / "capture.ansi").write_text(output)
            self.assertTrue(delta_log.is_file(), "Lazygit did not invoke Delta")
            self.assertIn("--syntax-theme=ansi", delta_log.read_text())
            for token, role in (("before", "diff_delete_bg"), ("after", "diff_add_bg")):
                for cell in token_cells(rendered, token):
                    self.assertEqual(cell.background, colors[role], "Active Delta " + token)
            check_publication("running")
            run_tmux("send-keys", "-t", case.name, "q")
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline:
                result = subprocess.run([*tmux, "has-session", "-t", case.name], env=environment,
                                        capture_output=True, timeout=10)
                if result.returncode != 0:
                    break
                time.sleep(0.05)
            else:
                self.fail("Lazygit did not exit")
            check_publication("exited")
            print(f"PASS: {case.name} installed links and published bytes "
                  + ("detect migration write" if legacy else "unchanged") + "; native Delta active")
            return colors, rendered

        def token_cells(
            rendered: list[native_delta.Cell], token: str,
        ) -> list[native_delta.Cell]:
            plain = "".join(cell.text for cell in rendered)
            self.assertIn(token, plain)
            start = plain.index(token)
            return rendered[start:start + len(token)]

        def check_metadata(
            colors: dict[str, str], rendered: list[native_delta.Cell], *, control: bool = False,
        ) -> None:
            author = token_cells(rendered, " FF ")[1:3]
            branch = token_cells(rendered, "* flume-native-branch")[2:]
            if not control:
                for token in ("Status", "Stash", "1 of 1"):
                    for cell in token_cells(rendered, token):
                        self.assertEqual(cell.foreground, colors["muted"], token)
                        self.assertGreaterEqual(native_delta.contrast(cell.foreground, cell.background), 4.5)
            for label, observed, ink in (
                ("author", author, "#123456" if control else colors["syntax_primary"]),
                ("branch", branch, "#abcdef" if control else colors["accent"]),
            ):
                for cell in observed:
                    self.assertEqual(cell.foreground, ink, label)
                    if not control:
                        self.assertGreaterEqual(native_delta.contrast(cell.foreground, cell.background), 4.5)
                print(f"PASS: native {label} ink {ink}" + (" (negative control)" if control else ""))

        try:
            for schema in review.SCHEMAS:
                with self.subTest(schema=schema):
                    colors, rendered = observe(schema)
                    check_metadata(colors, rendered)
                    selected = token_cells(rendered, "selected-folder ")[:-1]
                    for cell in selected:
                        self.assertEqual(cell.foreground, colors["syntax_primary"])
                        self.assertGreaterEqual(native_delta.contrast(cell.foreground, cell.background), 4.5)
                    print(
                        f"PASS: {schema} selected-folder ink {selected[0].foreground} "
                        f"on {selected[0].background}"
                    )
            colors, rendered = observe("opal", metadata_control=True)
            check_metadata(colors, rendered, control=True)
            colors, rendered = observe("opal", broken=True)
            for cell in token_cells(rendered, "selected-folder ")[:-1]:
                self.assertEqual(cell.foreground, colors["selection_fg"])
                self.assertLess(native_delta.contrast(cell.foreground, cell.background), 1.5)
            observe("opal", legacy=True)
        finally:
            subprocess.run([*tmux, "kill-server"], env=environment, capture_output=True, timeout=10)

    def test_tmux_semantic_pairs_use_readable_roles_not_ansi_surrogates(self):
        expected = {
            "Message text": ("fg", "surface"),
            "Command message": ("accent", "surface"),
            "Inactive label": ("muted", "bg"),
            "Accent badge": ("on_accent", "accent"),
            "Context badge": ("on_accent", "magenta"),
            "Warning badge": ("on_accent", "yellow"),
        }
        for schema in review.SCHEMAS:
            colors = json.loads(
                (ROOT / f"extras/palette/flume-{schema}.json").read_text()
            )["colors"]
            pairs = {pair.label: pair for pair in review.integration_pairs(ROOT, "tmux", schema)}
            for label, (foreground, background) in expected.items():
                with self.subTest(schema=schema, pair=label):
                    pair = pairs[label + " (illustrative)"]
                    self.assertEqual(pair.foreground, colors[foreground])
                    self.assertEqual(pair.background, colors[background])
                    self.assertEqual(pair.target, 4.5)
                    self.assertGreaterEqual(pair.ratio, 4.5)
            decoration = pairs["Decorative separator (illustrative)"]
            self.assertEqual(decoration.foreground, colors["placeholder"])
            self.assertEqual(decoration.target, 1.0)

    def test_retained_delta_inks_meet_contrast_on_every_diff_surface(self):
        # Slots 0/8 remain terminal black/decorative inks, not syntax foregrounds.
        ansi_roles = (
            "black", "red", "green", "yellow", "blue", "magenta", "cyan", "white",
            "bright_black", "bright_red", "bright_green", "bright_yellow", "bright_blue",
            "bright_magenta", "bright_cyan", "bright_white",
        )
        surfaces = {
            "minus-style": "diff_delete_bg",
            "minus-emph-style": "diff_delete_emphasis",
            "plus-style": "diff_add_bg",
            "plus-emph-style": "diff_add_emphasis",
        }
        for schema in review.SCHEMAS:
            colors = json.loads(
                (ROOT / f"extras/palette/flume-{schema}.json").read_text()
            )["colors"]
            for app in ("delta", "lazygit"):
                pairs = {pair.label: pair for pair in review.integration_pairs(ROOT, app, schema)}
                for style, role in surfaces.items():
                    foregrounds = [("Default text", colors["fg"])] + [
                        (f"ANSI {index}", colors[ink])
                        for index, ink in enumerate(ansi_roles) if index not in (0, 8)
                    ]
                    for label, foreground in foregrounds:
                        with self.subTest(schema=schema, app=app, style=style, ink=label):
                            pair = pairs[f"{label} on {style} (Ghostty host)"]
                            self.assertEqual(pair.foreground, foreground)
                            self.assertEqual(pair.background, colors[role])
                            self.assertGreaterEqual(pair.ratio, 4.5)

    def test_opencode_diff_inks_use_their_actual_surfaces(self):
        for schema in review.SCHEMAS:
            colors = json.loads(
                (ROOT / f"extras/palette/flume-{schema}.json").read_text()
            )["colors"]
            pairs = {pair.label: pair for pair in review.integration_pairs(ROOT, "opencode", schema)}
            for side, ink, surface in (
                ("added", "diff_add", "diff_add_bg"),
                ("removed", "diff_delete", "diff_delete_bg"),
            ):
                label = pairs[f"Diff {side} label"]
                self.assertEqual(label.foreground, colors[ink])
                self.assertEqual(label.background, colors["bg"])
                sign = pairs[f"Diff {side} sign"]
                self.assertEqual(sign.foreground, colors["bright_green" if side == "added" else "bright_red"])
                self.assertEqual(sign.background, colors[surface])
            for pair in pairs.values():
                if pair.label.startswith(("Diff ", "syntax")):
                    with self.subTest(schema=schema, pair=pair.label):
                        self.assertGreaterEqual(pair.ratio, 4.5)

    def test_pi_and_opencode_states_resolve_semantic_roles_on_actual_surfaces(self):
        expected = {
            "pi": {
                "warning on palette canvas": ("warning", 4.5),
                "Focused boundary on palette canvas": ("border_focused", 3),
            },
            "opencode": {role: (role, 4.5) for role in ("error", "warning", "success", "info")},
        }
        for schema in review.SCHEMAS:
            colors = json.loads((ROOT / f"extras/palette/flume-{schema}.json").read_text())["colors"]
            for app, roles in expected.items():
                pairs = {pair.label: pair for pair in review.integration_pairs(ROOT, app, schema)}
                for label, (role, target) in roles.items():
                    with self.subTest(schema=schema, app=app, label=label):
                        pair = pairs[label]
                        self.assertEqual(pair.foreground, colors[role])
                        self.assertEqual(pair.background, colors["bg"])
                        self.assertEqual(pair.target, target)
                        self.assertGreaterEqual(pair.ratio, target)

    def test_secondary_metadata_and_delta_gutters_use_readable_roles(self):
        expected = {
            "pi": {"mdCodeBlockBorder on palette canvas": "muted"},
            "lazygit": {"Inactive headings on terminal": "muted"},
            "delta": {},
        }
        for app in ("delta", "lazygit"):
            for side, role in (
                ("left", "muted"), ("right", "muted"), ("zero", "muted"),
                ("minus", "diff_delete"), ("plus", "diff_add"),
            ):
                expected[app][f"line-numbers-{side}-style on terminal"] = role
        for schema in review.SCHEMAS:
            colors = json.loads((ROOT / f"extras/palette/flume-{schema}.json").read_text())["colors"]
            for app, roles in expected.items():
                pairs = {pair.label: pair for pair in review.integration_pairs(ROOT, app, schema)}
                for label, role in roles.items():
                    with self.subTest(schema=schema, app=app, label=label):
                        pair = pairs[label]
                        self.assertEqual(pair.foreground, colors[role])
                        self.assertEqual(pair.background, colors["bg" if app == "pi" else "terminal_bg"])
                        self.assertGreaterEqual(pair.ratio, 4.5)

    def test_native_delta_gutter_observer_rejects_old_inks_and_missing_numbers(self):
        colors = json.loads((ROOT / "extras/palette/flume-dusk.json").read_text())["colors"]

        def rgb(role: str) -> str:
            color = colors[role]
            return "\x1b[38;2;" + ";".join(str(int(color[i:i + 2], 16)) for i in (1, 3, 5)) + "m"

        output = "\n".join((
            rgb("muted") + "  1 ⋮  1 │# Select a palette without changing ordinary identifiers.",
            rgb("diff_delete") + "  7 ⋮    │    return name",
            rgb("diff_delete") + '  8 ⋮    │print(select_palette("dusk"))',
            rgb("diff_add") + "    ⋮  7 │    return name.upper()",
            rgb("diff_add") + '    ⋮  8 │print(select_palette("opal"))',
        ))
        native_delta.check_gutters(output, colors)
        low_contrast = dict(colors, muted=colors["border"])
        with self.assertRaisesRegex(ValueError, "native gutter contrast .* is below 4.5:1"):
            native_delta.check_gutters(output.replace(rgb("muted"), rgb("border")), low_contrast)
        for old, new in (
            (rgb("muted"), rgb("border")),
            (rgb("diff_delete"), rgb("border")),
            ("  1 ⋮  1 │", "    ⋮  1 │"),
        ):
            with self.subTest(old=old), self.assertRaisesRegex(ValueError, "unexpected .*gutter|unexpected left number"):
                native_delta.check_gutters(output.replace(old, new), colors)

    def test_report_highlights_real_changes_without_blessing_contrast(self):
        old = {"demo": {"opal": [review.Pair("Selection", "#ffffff", "#000000")]}}
        new = {"demo": {"opal": [review.Pair("Selection", "#ffffff", "#eeeeee")]}}
        output = review.render(new, old)
        self.assertIn('class="below changed"', output)
        self.assertIn("Before: #ffffff / #000000 (21.00:1)", output)
        self.assertIn("not native screenshots", output)
        self.assertIn('class="meets unchanged"', review.render(old, old))

    def test_native_delta_observer_tracks_sgr_and_default_inks(self):
        colors = json.loads((ROOT / "extras/palette/flume-dusk.json").read_text())["colors"]
        output = "\x1b[32;48;2;60;42;51;4mA\x1b[24;39mB\x1b[0mC\x1b[95mD\x1b[0K"
        cells = native_delta.cells(output, colors)
        self.assertEqual("".join(cell.text for cell in cells), "ABCD")
        self.assertEqual(cells[0], native_delta.Cell("A", colors["green"], "#3c2a33", True))
        self.assertEqual(cells[1], native_delta.Cell("B", colors["fg"], "#3c2a33", False))
        self.assertEqual(
            cells[2], native_delta.Cell("C", colors["fg"], colors["terminal_bg"], False)
        )
        self.assertEqual(cells[3].foreground, colors["bright_magenta"])
        self.assertAlmostEqual(native_delta.contrast("#000000", "#ffffff"), 21)

    def test_native_delta_observer_rejects_the_old_dusk_string_fill(self):
        colors = json.loads((ROOT / "extras/palette/flume-dusk.json").read_text())["colors"]
        colors["diff_delete_emphasis"] = "#b65360"
        output = 'print(select_palette("\x1b[32;48;2;182;83;96;4mdusk\x1b[0m"))'
        with self.assertRaisesRegex(ValueError, "native contrast .* is below 4.5:1"):
            native_delta.check_output(output, colors)

    def test_invalid_colors_and_cyclic_aliases_are_rejected(self):
        with self.assertRaises(ValueError):
            review.Pair("bad", "red", "#000000")
        with self.assertRaises(ValueError):
            review.alias_colors(
                {"vars": {"a": "b", "b": "a"}, "colors": {"text": "a"}},
                "vars",
                "colors",
            )


if __name__ == "__main__":
    unittest.main()
