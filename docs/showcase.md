# Showcase and visual release evidence

Flume keeps canonical editor captures, README presentation, and native
integration evidence separate. Composition scripts resize pixels but never tint
or recolor application captures.

## Canonical editor captures

The palette comparison uses Zig. Each palette also has a language grid with
Rust, TypeScript/TSX, Python, and Go. For each language, all palettes use the
same source, Tree-sitter runtime, opaque background, Ghostty geometry, font
size, and padding. Tree-sitter assigns the highlights; the fixture does not
paint tokens manually. Captures exclude language servers,
Git state, diagnostics, diffs, menus, and notifications.

Install Zig, Rust, TSX, Python, and Go parsers and their highlight queries
before capture. Include inherited queries (such as JSX and ECMAScript for TSX).
Set `FLUME_TS_RUNTIME` to a runtime directory containing `parser/` and `queries/`
if they are not on Neovim's default runtime path. Use a locked nvim-treesitter
revision and its matching parser versions for all four palettes. See the
[nvim-treesitter installation guide](https://github.com/nvim-treesitter/nvim-treesitter#setup).
These are capture dependencies, not requirements for using Flume.

| Palette | Appearance | Full-resolution capture |
| --- | --- | --- |
| Dusk | Dark | [`dusk/zig.png`](../assets/screenshots/dusk/zig.png) |
| Opal | Light | [`opal/zig.png`](../assets/screenshots/opal/zig.png) |
| Mira | Dark | [`mira/zig.png`](../assets/screenshots/mira/zig.png) |
| Mesa | Light | [`mesa/zig.png`](../assets/screenshots/mesa/zig.png) |

On macOS, install Ghostty and grant Screen Recording permission before capture.
The script identifies the Ghostty window through CoreGraphics; no interactive
window selection is needed.

Capture and validate from the repository root. If needed, replace the example
runtime path with your parser/query installation:

```sh
export FLUME_TS_RUNTIME=/path/to/treesitter-runtime
```

The capture uses the selected Ghostty theme directly; it does not switch your
active integrations or other editors.

Capture all palettes and languages:

```sh
for schema in dusk opal mira mesa; do
    for language in zig rust tsx python go; do
        ./scripts/screenshot-window.sh "$schema" "$language"
    done
done
python3 scripts/preflight-screenshots.py
```

The language argument defaults to `zig`. Captures live under
`assets/screenshots/<schema>/<language>.png`, with matching JSON sidecars.
Raw window captures are temporary and are removed when the script exits.
Source fixtures live in `examples/`; capture and composition tools live in
`scripts/`.

Each sidecar identifies the palette and language. It records
Neovim's version, parser revision and checksum, query checksums, and source and
image checksums. It also fingerprints Flume's palette, highlight definitions,
language corrections, and selected Ghostty theme. The GUI must report its own
successful fixture initialization; the headless probe cannot certify a capture.
The preflight rejects stale inputs or images and mixed parser/query runtimes,
checks equal dimensions, and OCRs captures for stale branch/LSP text.
Source-only checks also reject manually assigned token highlights.

These captures demonstrate Tree-sitter output, not LSP semantic highlighting.
Use the [native language checks](color-system.md#verify-language-highlighting)
to inspect language-specific roles.

For ANSI evidence, run `./examples/ansi.sh` in the fixed terminal window under
each activated palette and save it with that terminal's native contact sheet.

## README composite

```sh
python3 scripts/compose_showcase.py
python3 scripts/compose-languages.py
```

Both commands validate capture provenance before composing. The first writes
`assets/screenshots/showcase.png`, a 2800 × 1720 composite of Opal, Mesa,
Mira, and Dusk. Dusk is the foreground sample. The second writes
`assets/screenshots/<schema>/languages.png` for each palette, with Rust and
TypeScript/TSX above Python and Go. Application captures retain their original
colors and the language grids preserve their aspect ratios.

Individual language captures:

| Palette | Rust | TypeScript/TSX | Python | Go |
| --- | --- | --- | --- | --- |
| Dusk | [Rust](../assets/screenshots/dusk/rust.png) | [TSX](../assets/screenshots/dusk/tsx.png) | [Python](../assets/screenshots/dusk/python.png) | [Go](../assets/screenshots/dusk/go.png) |
| Opal | [Rust](../assets/screenshots/opal/rust.png) | [TSX](../assets/screenshots/opal/tsx.png) | [Python](../assets/screenshots/opal/python.png) | [Go](../assets/screenshots/opal/go.png) |
| Mira | [Rust](../assets/screenshots/mira/rust.png) | [TSX](../assets/screenshots/mira/tsx.png) | [Python](../assets/screenshots/mira/python.png) | [Go](../assets/screenshots/mira/go.png) |
| Mesa | [Rust](../assets/screenshots/mesa/rust.png) | [TSX](../assets/screenshots/mesa/tsx.png) | [Python](../assets/screenshots/mesa/python.png) | [Go](../assets/screenshots/mesa/go.png) |

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

For each integration, capture the same deterministic app fixture with all four
palettes:

```text
assets/screenshots/integrations/<app>/dusk.png
assets/screenshots/integrations/<app>/opal.png
assets/screenshots/integrations/<app>/mira.png
assets/screenshots/integrations/<app>/mesa.png
assets/screenshots/integrations/<app>/metadata.json
```

Copy [`capture-metadata-template.json`](capture-metadata-template.json), fill in
real values, then compose:

```sh
python3 scripts/compose-contact-sheet.py <app>
```

The output is `assets/screenshots/integrations/<app>/contact-sheet.png`.
Metadata records app version, OS, terminal, font, dimensions, scale, fixture
revision, capture date, and any unsupported or unthemeable regions.

Prioritize:

1. Delta and Lazygit diffs and line numbers;
2. Pi and OpenCode text hierarchy, tool state, and Markdown;
3. Ghostty and Kitty ANSI 0–15, selection, cursor, and tabs;
4. Tmux status variables, LSD metadata, and fzf selection/search state.

When automation is unavailable, record the exact manual action and application
version instead of fabricating evidence.
