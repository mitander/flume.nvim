"""Deterministic measurements of exported artifacts, not a native rendering test."""

import importlib.util
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
        self.assertEqual(pairs["Match inside selected row"].foreground, "#895c00")
        self.assertEqual(pairs["Match inside selected row"].background, "#ddd6e3")
        lsd = {
            pair.label: pair for pair in review.integration_pairs(ROOT, "lsd", "opal")
        }
        self.assertEqual(
            lsd["permission.no-access (Ghostty host)"].foreground, "#706878"
        )
        self.assertEqual(lsd["user (Ghostty host)"].foreground, "#6c6c6c")

    def test_report_highlights_real_changes_without_blessing_contrast(self):
        old = {"demo": {"opal": [review.Pair("Selection", "#ffffff", "#000000")]}}
        new = {"demo": {"opal": [review.Pair("Selection", "#ffffff", "#eeeeee")]}}
        output = review.render(new, old)
        self.assertIn('class="below changed"', output)
        self.assertIn("Before: #ffffff / #000000 (21.00:1)", output)
        self.assertIn("not native screenshots", output)
        self.assertIn('class="meets unchanged"', review.render(old, old))

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
