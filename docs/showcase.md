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

On macOS, install Ghostty and grant Screen Recording permission before capture.
The script identifies the Ghostty window through CoreGraphics; no interactive
window selection is needed.

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
fixture source has no Git or language-server dependency.

For ANSI evidence, run `./examples/ansi.sh` in the fixed terminal window under
each activated palette and save it with that terminal's native contact sheet.

## README composite

```sh
python3 scripts/compose_showcase.py
```

This writes `screenshot-showcase.png`, a 2800 × 1720 composite of Opal, Mesa,
Mira, and Dusk. Dusk is the foreground sample. Application captures retain their
original colors.

## Native integration contact sheets

Visual integration review is manual release evidence, not a pixel-diff CI gate.
The checklist records missing native captures until evidence is committed:

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
| ltui / jtui | Pending | Workflow states, identity colors, selection |

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
2. Pi and OpenCode text hierarchy, tool state, and Markdown;
3. ltui / jtui workflow states, identity colors, and selection;
4. Ghostty and Kitty ANSI 0–15, selection, cursor, and tabs;
5. Tmux status variables, LSD metadata, and fzf selection/search state.

When automation is unavailable, record the exact manual action and application
version instead of fabricating evidence.
