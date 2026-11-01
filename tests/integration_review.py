"""Deterministic measurements of exported artifacts, not a native rendering test."""

import importlib.util
import json
import sys
import unittest
from pathlib import Path

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

    def test_selected_match_and_quantized_colors_use_actual_exports(self):
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
                ("added", "green", "diff_add_bg"),
                ("removed", "red", "diff_delete_bg"),
            ):
                label = pairs[f"Diff {side} label"]
                self.assertEqual(label.foreground, colors[ink])
                self.assertEqual(label.background, colors["bg"])
                sign = pairs[f"Diff {side} sign"]
                self.assertEqual(sign.foreground, colors["bright_" + ink])
                self.assertEqual(sign.background, colors[surface])
            for pair in pairs.values():
                if pair.label.startswith(("Diff ", "syntax")):
                    with self.subTest(schema=schema, pair=pair.label):
                        self.assertGreaterEqual(pair.ratio, 4.5)

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
