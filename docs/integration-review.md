# Review integration colors

Use one report to compare all four palettes and inspect actual foreground/background mappings. It measures contrast; it does not decide whether a palette is aesthetically balanced or readable in an application.

From the repository root:

```sh
python3 scripts/review-integrations.py --baseline-ref v0.2.0
```

Open `/tmp/flume-integration-review.html` in a browser. Each integration has four columns. Red markers identify pairs below their target; blue outlines identify changes from the baseline. Select **Show only changed pairs** to narrow a large review. The palette hierarchy section is new and has no v0.2 baseline export.

Use `--baseline-ref HEAD` to compare uncommitted exporter changes with the current commit. Omit the option to measure the current artifacts without a baseline. The generator reads files and Git objects only; it does not activate a palette or modify application configuration.

For machine-readable snapshot evidence:

```sh
python3 scripts/review-integrations.py \
  --baseline-ref HEAD \
  --json-output /tmp/flume-integration-pairs.json
```

The JSON contains resolved colors, targets, and ratios. A changed snapshot requires review, not automatic acceptance. The committed generated themes already preserve exact exporter mappings; tests additionally check contrast math, alias resolution, selected-match combinations, and xterm quantization.

## What is measured

- Palette hierarchy: text, secondary text, muted text, and placeholders across normal, raised, and selected surfaces.
- Ghostty and Kitty: text, selection, cursor, ANSI slots, and Kitty tabs.
- fzf: selected rows, matches inside selected rows, headers, prompts, and boundaries.
- Pi: selected text, messages, tool states, and syntax/comment text on the palette canvas.
- OpenCode: text on panels/elements, diffs, line numbers, syntax comments, and focused boundaries.
- Lazygit: selections, cherry-picked commits, state text, and active/search boundaries.
- LSD: actual xterm-256 metadata colors, including customized ANSI slots 0–15.
- Delta: syntax ANSI slots on added/deleted and emphasized diff backgrounds.
- Tmux: illustrative variable pairs. The user's statusline owns the actual foreground/background combinations.

Ordinary text targets 4.5:1. State-bearing boundaries target 3:1. Ratios use sRGB relative luminance and are compared before rounding. Decorative separators can be quieter; assess their purpose rather than treating every red marker as a release veto. Review ANSI black and other intentionally specialized slots in their real use cases.

## Limits and native review

The HTML samples are color previews, not native application screenshots. LSD and Delta measurements assume a Ghostty host using the matching Flume palette. Pi canvas measurements assume the matching palette canvas. Different terminal settings, fonts, opacity, ANSI overrides, or application overrides can change the result.

For each changed mapping:

1. Inspect the flagged pair and its role in the actual application.
2. Capture the same content and state before and after the change.
3. Check selected/matched text, inactive controls, diffs, and light palettes.
4. Adjust the integration's role mapping deliberately; do not globally transform the palette to repair one consumer.
5. Regenerate artifacts and the report, then run `./scripts/check`.

Use the [showcase pipeline](showcase.md) for real application snapshots. A screenshot baseline preserves a reviewed result, but cannot prove readability by itself. Visually review the application snapshots before claiming an integration is qualified. Ghostty/Kitty selection, tabs, and live reload remain separate checks. Snapshots exercise Linux Ghostty, not macOS Ghostty or Kitty.
