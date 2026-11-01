# Showcase production

Use this guide to capture, compare and update the gallery, integration and README images. To browse
existing images, open the [gallery](gallery.md).

Run commands from the repository root on macOS or Linux with Python 3.11+ and a running local
Docker-compatible runtime. The first run downloads and builds the pinned environment. Later runs
reuse it. Captures use isolated state and open no desktop windows. They need no Screen Recording or
Accessibility permissions. The complete portfolio can take several minutes.

## Reproducible integration snapshots

Compare fresh captures with the committed images:

```sh
./scripts/snapshots test
```

`test` freezes its inputs, captures the selected scenes, generates their derived images, and
compares exact pixels against the published images. It never changes those images or the baseline
manifest. Missing evidence, changed environment, changed pixels, or failed capture produces a
nonzero exit status. There is no pixel tolerance or automatic approval.

The command prints a temporary HTML report with expected, actual, and visible difference images.
Capture failures retain partial captures and logs instead. CI runs the same command in a separate
job and retains its report.

When the source change intentionally requires new captures, update the published images:

```sh
./scripts/snapshots update
```

`update` uses the same capture and composition path and publishes only after all requested captures
and compositions succeed. Review its before/after report and Git diff before committing. An update
is a candidate for review, not automatic visual approval.

Published images under `assets/screenshots/` are the baselines, not copies of a second image set.
`tests/snapshots/baselines/manifest.json` records their hashes, input fingerprints, dimensions,
renderer, and environment identity. Neovim images also have parser/state/server sidecars. Commit
changed images and metadata with the source change.

Publication is atomic per file, not across the whole matrix. The manifest is written last, so
interrupted image changes fail evidence checks. Rerun `update` to finish or restore the affected
files with Git. If only input provenance changes while pixels and environment stay identical,
interruption leaves valid evidence from the previous capture. Snapshot tests compare pixels and
environment, not input hashes; editor preflight additionally checks source provenance.

### Focused runs

Filters are repeatable:

```sh
./scripts/snapshots test --app fzf
./scripts/snapshots update --app delta --schema opal
./scripts/snapshots update --app neovim --scene neovim-zig
./scripts/snapshots test --app neovim --scene neovim-completion-go
```

Integration runs also generate that app's contact sheet. Zig syntax runs generate the README hero.
For partial palette updates, composition combines the new captures with committed, verified
unselected captures. Refresh all palettes when changing the environment; do not combine captures
from different tool versions.

Palette/exporter changes still need the generated-extra refresh described in the
[development commands](DEVELOPMENT.md#regenerate-palette-artifacts). App fixtures consume the
shipped exports, not editor-local overrides.

## Capture environment

Capture runs offline with an isolated home, read-only source, fixed fixtures, locale, fonts and
Linux amd64 tools. ARM Macs use the same binaries as CI. Two isolated capture containers run at a
time. Ghostty 1.3.1 renders on a private Xvfb display with Mesa software OpenGL. X11 pixels convert
directly to RGB PNG and compose through pinned Pillow, without intermediate YUV conversion. Tests
check exact RGB preservation and pixel equality.

The checksum-locked Linux Ghostty package comes from the community-maintained
`mkasberg/ghostty-ubuntu` release, not an official Ghostty binary. Linux captures do not qualify
macOS Ghostty or Kitty rendering, selection, tabs or live reload.

Tapes, fixtures, inventory, and composition live in `tests/snapshots/`. Its `Dockerfile` pins the
base image and Debian archive; `tools.json` locks release and grammar archives by checksum. Change
versions deliberately and refresh all affected baselines. `scripts/snapshots` is the only maintained
capture and composition entry point.

## Canonical editor captures

The palette comparison and README hero use the same Zig fixture. Every palette also has Go, Rust,
Python, TypeScript/TSX, Elixir, and TOML captures. They use real Neovim 0.12.5 Tree-sitter
highlighting, not manually colored tokens. Syntax scenes exclude diagnostics, Git state, menus,
notifications, and language servers.

The environment compiles grammars pinned by nvim-treesitter revision
`4916d6592ede8c07973490d9322f187e07dfefac`, with its matching queries and inherited queries. These
are capture dependencies, not requirements for using Flume. Each capture records parser
revision/checksum, query fingerprints, fixture and theme inputs, image checksum, and renderer
identity. Rendering inputs include `init.lua`, the canonical palette and language mappings. Command
registration, reload and sync orchestration live separately in `commands.lua`, so changes to that
plumbing do not invalidate editor capture provenance. Changes to palette application or highlight
mapping still require new captures. Neovim itself reports readiness before Ghostty captures the
painted terminal state. The capture fixture reveals the real statusline location field only after
readiness. No preview label is added to the image.

| Palette | Appearance | Gallery                                               |
| ------- | ---------- | ----------------------------------------------------- |
| Dusk    | Dark       | [Languages, states, and integrations](themes/dusk.md) |
| Opal    | Light      | [Languages, states, and integrations](themes/opal.md) |
| Mira    | Dark       | [Languages, states, and integrations](themes/mira.md) |
| Mesa    | Light      | [Languages, states, and integrations](themes/mesa.md) |

### Typography and framing

Raw images live at `assets/screenshots/<schema>/<language>.png`. Geometry is 112 columns × 32 rows
for the Zig hero and 100 × 48 for other language and LSP scenes. The Neo-tree scene uses 132 × 44.
Typography uses checksum-locked JetBrains Mono 2.304 from the
[Nerd Fonts 3.5.1 release](https://github.com/ryanoasis/nerd-fonts/releases/tag/v3.5.1). Its
`JetBrainsMono Nerd Font Mono` family preserves ligatures and supplies monospaced icons. Every
palette and app uses SemiBold, with real Bold, SemiBold Italic, and Bold Italic faces. Contact-sheet
labels use the same family. This capture choice does not change the user's terminal font. The hero
uses a 38-pixel em; compact editor scenes use a 24-pixel em. Ghostty's X11 point sizes are 28.5 and
18 at 96 DPI. Cell height increases by 12% and cell width by 2%. Capture checks the resolved font
files and fails on fallback. Neovim keeps mode-specific, non-blinking cursor shapes: block in Normal
mode, bar in Insert mode. Syntax specimens park the block cursor on whitespace to keep text
readable. Capture does not mask pixels or allow comparison tolerance. Ghostty explicitly uses native
sRGB alpha blending instead of Linux's `linear-corrected` default. This follows macOS's native
blending mode and avoids host-dependent rounding in the linear sRGB framebuffer path. Mesa llvmpipe
provides single-threaded software rendering. The manifest records blending, the renderer
environment, and the installed Mesa version. See
[Ghostty's alpha-blending modes](https://ghostty.org/docs/config/reference#alpha-blending).

Pinned Pillow adds padding, an understated title bar with three macOS-style buttons, no redundant
window-title text, and antialiased rounded corners. Frame padding, controls, titlebar, and corners
scale with captured width so they keep consistent proportions at a shared gallery display width.
Terminal pixels are never resized or filtered. The terminal background is opaque; only the outer
corners are transparent. Complete fixtures fit without scrolling. Gallery links embed the
full-resolution images.

Ghostty shapes ligatures and Nerd Font icons and renders diagnostic undercurls. One family and
weight across the portfolio keep font choice from becoming another palette-comparison variable.
Linux FreeType/OpenGL rasterization does not reproduce macOS CoreText/Metal pixels exactly. The
composed frame keeps native-style shading and generous padding, rather than capturing a desktop
window.

Syntax captures demonstrate Tree-sitter, not LSP semantic highlighting. Use the
[native language checks](color-system.md#verify-language-highlighting) to inspect provider roles
independently of screenshots. `scripts/preflight-screenshots.py` checks input and image provenance,
matching runtimes, and geometry. Its optional OCR checks require Tesseract; the snapshot commands do
not require host OCR tools.

## Working-state and LSP captures

[`states.go`](../examples/states.go) and [`states.lua`](../examples/states.lua) exercise Neovim's
real diff engine, changed-word surfaces, search, four fixture diagnostics with
signs/undercurls/virtual text, and Visual selection.

[`completion.go`](../examples/completion.go) and [`completion.lua`](../examples/completion.lua) show
a separate editing moment: gopls supplies `strings.TrimSpace` and `strings.TrimSuffix` candidates
for a partially typed call. Blink displays a completion menu and resolved, syntax-highlighted
documentation popup. Both windows use single-line borders, the theme's `Normal` background, and
`Visual` selection highlights. Blink is checksum-locked and uses its Lua matcher with binary
downloads disabled for offline capture. To run the example separately, set `FLUME_BLINK_RUNTIME` to
a Blink checkout. Capture requires server identity, observed candidates, nonempty documentation, and
rendered syntax highlights, not a hand-written list.

[`lsp-showcase.lua`](../examples/lsp-showcase.lua) attaches real gopls v0.16.2 or ZLS 0.16.0 to an
isolated workspace. Capture workspaces have stable paths inside each private container: ZLS includes
file URLs in hover content, and variable path lengths change the popup width. Go 1.23.2 and Zig
0.16.0 are pinned with those servers. Readiness requires observed semantic tokens and server hover
content; diagnostics are suppressed to isolate provider coloring. The hover shows the signature and
available documentation at a real call site. Sidecars identify server version, settings, executable
checksum, observed token counts, and hover content. These images do not qualify other server
versions or languages.

The lualine scene loads the real checksum-locked plugin with the named `flume` theme, with real
devicons. Its statusline uses the same palette as the editor.

The Neo-tree scene loads the real checksum-locked plugin, Plenary, Nui, and nvim-web-devicons. Its
isolated project contains staged additions, modified files, and an untracked file. The sidebar
exercises file icons, directory colors, selection, indent guides, Git indicators, and
inactive-window surfaces. No host repository or personal file names appear.

| Palette | Selection and diagnostics                               | Completion                        | Tree-sitter + LSP                                                       |
| ------- | ------------------------------------------------------- | --------------------------------- | ----------------------------------------------------------------------- |
| Dusk    | [States](themes/dusk.md#diagnostics-and-working-states) | [Menu](themes/dusk.md#completion) | [Go](themes/dusk.md#go-with-gopls) · [Zig](themes/dusk.md#zig-with-zls) |
| Opal    | [States](themes/opal.md#diagnostics-and-working-states) | [Menu](themes/opal.md#completion) | [Go](themes/opal.md#go-with-gopls) · [Zig](themes/opal.md#zig-with-zls) |
| Mira    | [States](themes/mira.md#diagnostics-and-working-states) | [Menu](themes/mira.md#completion) | [Go](themes/mira.md#go-with-gopls) · [Zig](themes/mira.md#zig-with-zls) |
| Mesa    | [States](themes/mesa.md#diagnostics-and-working-states) | [Menu](themes/mesa.md#completion) | [Go](themes/mesa.md#go-with-gopls) · [Zig](themes/mesa.md#zig-with-zls) |

## Code examples

Sources live in `examples/`. They use each language's conventions rather than translating the same
exercise. Role coverage spans the examples; no single file demonstrates every highlight group.

| Source                         | Mechanism                                                               |
| ------------------------------ | ----------------------------------------------------------------------- |
| [Go](../examples/flume.go)     | A channel producer stops on cancellation; its caller waits for cleanup. |
| [Rust](../examples/flume.rs)   | Typestate permits opening only after unlocking.                         |
| [Python](../examples/flume.py) | A JSON-lines event counter reports frequencies and percentages.         |
| [TSX](../examples/flume.tsx)   | A React counter records undo history through functional updates.        |
| [Zig](../examples/flume.zig)   | Recursive constant folding over a tagged expression union.              |
| [Elixir](../examples/flume.ex) | A regex parser feeds a frequency-counting pipeline.                     |
| [TOML](../examples/flume.toml) | Illustrative preview-server configuration, not Flume configuration.     |

Go requires 1.22+, Python 3.10+, and Elixir 1.10+. TSX requires React and its TypeScript types. `zig
run examples/flume.zig` prints `add folded = 42` with Zig 0.16.0. Run `python3 examples/flume.py
events.jsonl --limit 3` with records such as `{"event":"play"}`, or `elixir tests/examples.exs` to
check its parser.

## README composite

The normal snapshot commands generate and test `assets/screenshots/showcase.png`: a 2800 × 1720
cascade of Opal, Mesa, Mira, and Dusk Zig captures over the original artwork. Dusk is the foreground
sample. Composition runs through pinned Pillow in the capture environment; it preserves capture
colors, rounded corners, and aspect ratios. Each window fits within both size bounds so its
statusline stays inside the canvas. There is no manual screenshot or separate ImageMagick step.

## Integration contact sheets

Each contact sheet shows the same real application fixture and geometry across all four palettes.
The short fzf, LSD and Tmux fixtures use 16-row viewports instead of mostly empty windows. Pi and
OpenCode restore synthetic offline sessions without model calls, credentials, extensions, plugins or
personal configuration. Their UI is real.

OpenCode's fixture covers basic Markdown layout, emphasis, inline code, core UI colors and a
completed text-file edit through its real diff component. The code fence is plain code. It does not
qualify OpenCode's asynchronous syntax parser or heading/link styles. Real language-parser coverage
belongs to the Neovim scenes.

| Integration | Exercised surface                                                                                                 |
| ----------- | ----------------------------------------------------------------------------------------------------------------- |
| Tmux        | Exported status variables and active window                                                                       |
| LSD         | File types, permissions, sizes, dates, symlinks, and Git state                                                    |
| OpenCode    | Core UI colors, Markdown emphasis, inline code, plain code and a real text-file edit diff from an offline session |
| Lazygit     | Repository files and add/change/delete diff state                                                                 |
| fzf         | Search, current item, and multi-selection                                                                         |
| Delta       | Added/changed/deleted diff lines and line numbers                                                                 |
| Pi          | Markdown, code, thinking, and successful/failed tool results                                                      |

The palette galleries embed each app's snapshot. Each integration directory also contains
`contact-sheet.png`, generated and tested from its four raw captures.

Ghostty and Kitty exports retain configuration-contract checks for syntax, settings, ANSI slots, and
exact canonical colors. Captures also exercise Ghostty's Linux renderer, but not its selection,
tabs, or live reload. Use the [native-theme trial](TESTING.md#native-theme-qualification) for an
isolated manual check of those behaviors, native Kitty rendering and Pi's live theme reload. It does
not update screenshot baselines or exercise Ghostty's global reload adapter.

Historical hierarchy comparisons retain their inputs in
[capture metadata](../assets/screenshots/hierarchy/metadata.json). They are archived evidence, not
maintained showcase assets regenerated by this pipeline. Exact role values and contrast pairs belong
to the [palette manifest](palette-manifest.md), not screenshot comparison tables.
