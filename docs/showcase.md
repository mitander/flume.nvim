# Showcase production

This guide is for contributors who need to refresh screenshots or review native
integrations. To compare palettes, browse the [gallery](gallery.md).

Composition scripts resize captures without tinting or recoloring them. Exact
role values and contrast pairs belong to the [palette manifest](palette-manifest.md),
not screenshot comparison tables. Archived hierarchy comparisons retain their
inputs in [capture metadata](../assets/screenshots/hierarchy/metadata.json).

## Canonical editor captures

The palette comparison uses Zig. Each palette also has individual captures of
Go, Rust, Python, TypeScript/TSX, Zig, Elixir, and TOML. For each language, all palettes use the
same source, Tree-sitter runtime, opaque background, Ghostty geometry, font
size, and padding. Tree-sitter assigns the highlights; the fixture does not
paint tokens manually. Captures exclude language servers,
Git state, diagnostics, diffs, menus, and notifications.

Install Zig, Rust, TSX, Python, Go, Elixir, and TOML parsers and their highlight queries
before capture. Include inherited queries (such as JSX and ECMAScript for TSX).
Set `FLUME_TS_RUNTIME` to a runtime directory containing `parser/` and `queries/`
if they are not on Neovim's default runtime path. Use a locked nvim-treesitter
revision and its matching parser versions for all four palettes. See the
[nvim-treesitter installation guide](https://github.com/nvim-treesitter/nvim-treesitter#setup).
These are capture dependencies, not requirements for using Flume.

| Palette | Appearance | Theme gallery |
| --- | --- | --- |
| Dusk | Dark | [Languages, working states, and integrations](themes/dusk.md) |
| Opal | Light | [Languages, working states, and integrations](themes/opal.md) |
| Mira | Dark | [Languages, working states, and integrations](themes/mira.md) |
| Mesa | Light | [Languages, working states, and integrations](themes/mesa.md) |

On macOS, install Ghostty and Maple Mono NF, then grant Screen Recording permission before capture.
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
    ./scripts/screenshot-window.sh "$schema" zig
    for language in rust tsx python go elixir toml; do
        FLUME_CAPTURE_FONT_SIZE=12 ./scripts/screenshot-window.sh "$schema" "$language"
    done
done
python3 scripts/preflight-screenshots.py
```

The default font size is 19 points. Set `FLUME_CAPTURE_FONT_SIZE` for a
capture-only override when complete fixtures do not fit the display. Keep the
same size across all palettes for a language, and across all state captures.
This does not change installed terminal preferences or editor settings.

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
checks equal dimensions across palettes for each language, and OCRs captures
for stale branch/LSP text and Neovim error messages.
Source-only checks also reject manually assigned token highlights.

These captures demonstrate Tree-sitter output, not LSP semantic highlighting.
Use the [native language checks](color-system.md#verify-language-highlighting)
to inspect language-specific roles.

For ANSI evidence, run `./examples/ansi.sh` in the fixed terminal window under
each activated palette and save it with that terminal's native contact sheet.

## Working-state and LSP captures

Working-state captures use [`states.go`](../examples/states.go) and
[`states.lua`](../examples/states.lua). The upper panes use Neovim's real diff
engine, including changed identifiers and strings. The lower pane shows four
fixture diagnostics, underlines, letter signs, and search matches.

Selection and completion need different editor modes. Capture them separately
so both use native UI states rather than painted imitations:

```sh
for schema in dusk opal mira mesa; do
    FLUME_CAPTURE_FONT_SIZE=12 ./scripts/screenshot-window.sh "$schema" go selection
    FLUME_CAPTURE_FONT_SIZE=12 ./scripts/screenshot-window.sh "$schema" go completion
    FLUME_CAPTURE_FONT_SIZE=12 ./scripts/screenshot-window.sh "$schema" go lsp
    FLUME_CAPTURE_FONT_SIZE=12 ./scripts/screenshot-window.sh "$schema" zig lsp
done
python3 scripts/preflight-screenshots.py --states --ocr
```

Use the same `FLUME_TS_RUNTIME` as the canonical captures. The LSP fixture
requires `gopls` and `zls` on `PATH`, plus their Go and Zig toolchains.
[`lsp-showcase.lua`](../examples/lsp-showcase.lua) copies source into a temporary
workspace. It requires attached semantic tokens before reporting readiness.
It suppresses diagnostics to isolate provider coloring and removes the workspace
on exit. It does not change the user's editor or synchronized palette.

Sidecars record parser/query fingerprints, fixture and renderer checksums,
image checksums, and theme inputs. State sidecars also record native readiness
and the capture-script checksum. LSP sidecars identify server versions, settings,
executable checksums, and observed token counts. Preflight rejects mixed server
or parser/query runtimes across palettes. Add `--ocr` to check state and LSP
captures for Neovim error messages; this native lane requires Tesseract.
Without `--ocr`, state preflight checks provenance and dimensions only, so
ordinary checks do not require OCR.

The captures below use Neovim 0.12.5 and Ghostty 1.3.1 on macOS 27.0.1,
with Maple Mono NF at 12 points and an opaque 100-column viewport.
Complete selection/completion fixtures and Go/Zig LSP sources fit without scrolling.
The parser/query installation comes from nvim-treesitter commit
`4916d6592ede8c07973490d9322f187e07dfefac`; sidecars record parser revisions
and checksums. LSP captures use gopls v0.16.2 and ZLS 0.16.0.
They do not qualify other server versions or languages.

| Palette | Selection and diagnostics | Completion | Tree-sitter + LSP |
| --- | --- | --- | --- |
| Dusk | [Working states](themes/dusk.md#diagnostics-and-working-states) | [Menu](themes/dusk.md#completion) | [Go](themes/dusk.md#go-with-gopls) · [Zig](themes/dusk.md#zig-with-zls) |
| Opal | [Working states](themes/opal.md#diagnostics-and-working-states) | [Menu](themes/opal.md#completion) | [Go](themes/opal.md#go-with-gopls) · [Zig](themes/opal.md#zig-with-zls) |
| Mira | [Working states](themes/mira.md#diagnostics-and-working-states) | [Menu](themes/mira.md#completion) | [Go](themes/mira.md#go-with-gopls) · [Zig](themes/mira.md#zig-with-zls) |
| Mesa | [Working states](themes/mesa.md#diagnostics-and-working-states) | [Menu](themes/mesa.md#completion) | [Go](themes/mesa.md#go-with-gopls) · [Zig](themes/mesa.md#zig-with-zls) |

These editor captures do not approve the native integration contact sheets below.
Review hierarchy at working font size; checksum and contrast checks do not
establish reading comfort.

## Code examples

The examples use each language's conventions rather than translating the same
exercise. Some demonstrate a language mechanism; others show a practical script
or configuration. Zig uses a compact 112-column × 32-row viewport for the
README hero. Other languages use 100 columns × 48 rows. Each complete file fits
without scrolling. Zig captures use a 19-point font; other languages use
12 points. They show syntax, not diagnostics or LSP semantic tokens. Syntax-role coverage is spread across the
examples; no single file demonstrates every highlight group.

| Source                         | Mechanism                                                                                                                                     |
| ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------- |
| [Go](../examples/flume.go)     | A channel producer stops on cancellation, even without a receiver; the caller waits for cleanup.                                              |
| [Rust](../examples/flume.rs)   | Typestate makes `open` available only after unlocking; a wrong key returns the door for another attempt.                                      |
| [Python](../examples/flume.py) | A command-line script reads JSON-lines events, counts names, and prints the most common events with percentages.                              |
| [TSX](../examples/flume.tsx)   | A React counter stores history so undo is one state transition; functional updates compose queued clicks.                                     |
| [Zig](../examples/flume.zig)   | A tagged union represents an expression tree. Recursive folding returns a number for constant expressions and `null` for dynamic identifiers. |
| [Elixir](../examples/flume.ex) | A regex parser returns tagged tuples; a pipeline counts valid log entries using pattern-matched anonymous function clauses.                   |
| [TOML](../examples/flume.toml) | An illustrative preview-server config uses tables, arrays of tables, quoted keys, literal strings, and multiline strings.                     |

Run `zig run examples/flume.zig` to print `add folded = 42` (verified with Zig 0.16.0).
Go requires 1.22+ for integer ranges. The TSX component requires React and its
TypeScript types; render `<UndoCounter />` in a React application. Python requires
3.10+; run `python3 examples/flume.py events.jsonl --limit 3` with one object such
as `{"event": "play"}` per line. Elixir requires 1.10+ for `Enum.frequencies/1`;
run `elixir examples/flume.ex` or `elixir tests/examples.exs` to check the parser.
The TOML example is not a Flume configuration file.

## README composite

```sh
python3 scripts/compose_showcase.py
```

The command validates capture provenance before composing. It writes
`assets/screenshots/showcase.png`, a 2800 × 1720 composite of Opal, Mesa,
Mira, and Dusk. Dusk is the foreground sample. Application captures retain their
original colors and aspect ratios. README links open Markdown galleries with
embedded captures, headings, and links to corresponding theme/language sections.

The [gallery](gallery.md) links to both palette and language views. Both views
embed the same full-resolution image files; they do not duplicate or recolor captures.

## Native integration contact sheets

Visual integration review is manual release evidence, not a pixel-diff CI gate.
The checklist records missing native captures until evidence is committed:

| Integration | Contact sheet | Required surface                   |
| ----------- | ------------- | ---------------------------------- |
| Ghostty     | Pending       | ANSI 0–15, selection, cursor       |
| Kitty       | Pending       | ANSI 0–15, selection, tabs         |
| Tmux        | Pending       | Status variables and active window |
| LSD         | Pending       | File types, permissions, Git state |
| OpenCode    | Pending       | Text hierarchy, diffs, Markdown    |
| Lazygit     | Pending       | Add/change/delete and line numbers |
| fzf         | Pending       | Selection, match, prompt, border   |
| Delta       | Pending       | Add/change/delete and line numbers |
| Pi          | Pending       | Text hierarchy, tools, Markdown    |

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
