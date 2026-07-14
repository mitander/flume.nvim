# Showcase and visual release evidence

Flume keeps canonical editor captures, README presentation, and native
integration evidence separate. Composition scripts resize pixels but never tint
or recolor application captures.

## Canonical editor captures

Every palette uses the same deterministic fixture, opaque background, Ghostty
window geometry, font size, and padding. The fixture renders the valid
`examples/flume.zig` program with documentation and ordinary comments, neutral
identifiers, types, functions, properties, constants, numbers, strings,
keywords, operators, punctuation, line numbers, an active line, and a restrained
statusline. It deliberately excludes diagnostics, virtual text, diffs, menus,
and notifications so the palette remains readable. It does not depend on a
parser, language server, Git branch, or working tree.

| Palette | Appearance | Full-resolution capture |
| --- | --- | --- |
| Dusk | Dark | [`screenshot-dusk.png`](../screenshot-dusk.png) |
| Opal | Light | [`screenshot-opal.png`](../screenshot-opal.png) |
| Mira | Dark | [`screenshot-mira.png`](../screenshot-mira.png) |
| Mesa | Light | [`screenshot-mesa.png`](../screenshot-mesa.png) |

Capture and validate from the repository root:

```sh
./scripts/screenshot-window.sh dusk
./scripts/screenshot-window.sh opal
./scripts/screenshot-window.sh mira
./scripts/screenshot-window.sh mesa
python3 scripts/preflight-screenshots.py
```

The preflight requires all four canonical filenames and equal dimensions,
rejects old names, OCRs captures for stale branch/LSP text, and verifies that the
fixture source has no Git or language-server dependency. macOS capture requires
Screen Recording permission; the script identifies its Ghostty window through
CoreGraphics and captures it without interactive window selection.

For ANSI evidence, run `./examples/ansi.sh` in the fixed terminal window under
each activated palette and save it with that terminal's native contact sheet.

## README composite

```sh
python3 scripts/compose_showcase.py
```

This writes `screenshot-showcase.png`: Opal, Mesa, Mira, and Dusk cascade from
the upper-left light foundation to the lower-right dark foundation in a
2800 × 1720 frame. Each window overlaps the previous one heavily, exposing its
comments, syntax, line numbers, and statusline while leaving Dusk as the fully
readable foreground sample. The more vivid Flume artwork shows through a
translucent palette blend, with restrained shadows and unmodified title bars.

## Native integration contact sheets

Visual integration review is manual release evidence, not a pixel-diff CI gate.
The v0.2.0 native-capture checklist is explicit until evidence is committed:

| Integration | Contact sheet | Required surface |
| --- | --- | --- |
| Ghostty | Pending | ANSI 0–15, selection, cursor |
| Kitty | Pending | ANSI 0–15, selection, tabs |
| Tmux | Pending | Status variables and active window |
| LSD | Pending | File types, permissions, Git state |
| OpenCode | Pending | Text hierarchy, diffs, Markdown |
| Lazygit | Pending | Add/change/delete and line numbers |
| fzf | Pending | Selection, match, prompt, border |
| Delta | Pending | Add/change/delete and line numbers |
| Pi | Pending | Text hierarchy, tools, Markdown |
| Tuxedo | Pending | Priorities, status, selection |

For each integration, capture the same deterministic app fixture with all four
palettes:

```text
captures/<app>/dusk.png
captures/<app>/opal.png
captures/<app>/mira.png
captures/<app>/mesa.png
captures/<app>/metadata.json
```

Copy [`capture-metadata-template.json`](capture-metadata-template.json), fill in
real values, then compose:

```sh
python3 scripts/compose-contact-sheet.py <app>
```

The output is `captures/<app>/contact-sheet.png`. Metadata records app version,
OS, terminal, font, dimensions, scale, fixture revision, capture date, and any
unsupported or unthemeable regions.

Prioritize:

1. Delta and Lazygit diffs and line numbers;
2. Pi, OpenCode, and Tuxedo text hierarchy, tool state, and Markdown;
3. Ghostty and Kitty ANSI 0–15, selection, cursor, and tabs;
4. Tmux status variables, LSD metadata, and fzf selection/search state.

When automation is unavailable, record the exact manual action and application
version instead of fabricating evidence.
