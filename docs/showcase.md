# Showcase production

To compare palettes, browse the [gallery](gallery.md). Maintained gallery,
integration, and README images use one reproducible snapshot pipeline:

```sh
./scripts/snapshots test
./scripts/snapshots update
```

Run from the repository root on macOS or Linux with Python 3.11+ and a running
local Docker-compatible runtime. The first run downloads and builds the pinned
capture environment. Subsequent runs reuse it. No desktop windows open, and no
Screen Recording or Accessibility permissions are needed.

Capture runs offline with an isolated home, read-only source, fixed fixtures,
locale, fonts, dimensions, and Linux amd64 tools. Ghostty 1.3.1 renders on a private
Xvfb display with Mesa software OpenGL. Capture converts X11 pixels directly to
RGB PNG, without intermediate YUV conversion, and composes them through pinned Pillow.
Regression tests require exact RGB preservation as well as exact pixel comparison.
ARM Macs use the same binaries as CI. The checksum-locked Linux Ghostty package
comes from the community-maintained `mkasberg/ghostty-ubuntu` release; it is not an
official Ghostty binary. The complete portfolio can take several minutes to capture. Two isolated capture containers run at a time. Pi and OpenCode restore
synthetic sessions: they do not call models or use credentials, extensions,
plugins, or personal configuration. OpenCode's code fence is plain code: this
fixture covers basic Markdown layout, emphasis, inline code, and core UI colors,
not its asynchronous syntax parser, heading/link styles, or colored-diff roles.
Real language-parser coverage belongs to the Neovim scenes.

## Reproducible integration snapshots

`test` freezes its inputs, captures the selected scenes, generates their derived
images, and compares exact pixels against the published images. It never changes
those images or the baseline manifest. Missing evidence, changed environment,
changed pixels, or failed capture produces a nonzero exit status. There is no
pixel tolerance or automatic approval.

The command prints a temporary HTML report with expected, actual, and visible
difference images. Capture failures retain partial captures and logs instead.
CI runs the same command in a separate job and retains its report.

`update` uses the same capture and composition path. It publishes images only
after all requested captures and compositions succeed. Review its before/after
report and Git diff before committing; updating is not visual approval.

Published images under `assets/screenshots/` are the baselines, not copies of a
second image set. `tests/snapshots/baselines/manifest.json` records their hashes,
input fingerprints, dimensions, renderer, and environment identity. Neovim
images also have parser/state/server sidecars. Commit changed images and metadata
with the source change.

Publication is atomic per file, not across the whole matrix. The manifest is
written last, so interrupted image changes fail evidence checks. Rerun `update`
to finish or restore the affected files with Git. If only input provenance changes
while pixels and environment stay identical, interruption leaves valid evidence
from the previous capture. Snapshot tests compare pixels and environment, not
input hashes; editor preflight additionally checks source provenance.

### Focused runs

Filters are repeatable:

```sh
./scripts/snapshots test --app fzf
./scripts/snapshots update --app delta --schema opal
./scripts/snapshots update --app neovim --scene neovim-zig
./scripts/snapshots test --app neovim --scene neovim-completion-go
```

Integration runs also generate that app's contact sheet. Zig syntax runs generate
the README hero. For partial palette updates, composition combines the new
captures with committed, verified unselected captures. Refresh all palettes when
changing the environment; do not combine captures from different tool versions.

Palette/exporter changes still need the generated-extra refresh described in the
[contributor checks](contributing.md#checks). App fixtures consume the shipped
exports, not editor-local overrides.

Tapes, fixtures, inventory, and composition live in `tests/snapshots/`. Its
`Dockerfile` pins the base image and Debian archive; `tools.json` locks release
and grammar archives by checksum. Change versions deliberately and refresh
all affected baselines. `scripts/snapshots` is the only maintained capture and
composition entry point.

## Canonical editor captures

The palette comparison and README hero use the same Zig fixture. Every palette
also has Go, Rust, Python, TypeScript/TSX, Elixir, and TOML captures. They use real
Neovim 0.12.5 Tree-sitter highlighting, not manually colored tokens. Syntax scenes
exclude diagnostics, Git state, menus, notifications, and language servers.

The environment compiles grammars pinned by nvim-treesitter revision
`4916d6592ede8c07973490d9322f187e07dfefac`, with its matching queries and inherited
queries. These are capture dependencies, not requirements for using Flume.
Each capture records parser revision/checksum, query fingerprints, fixture and
theme inputs, image checksum, and renderer identity. Neovim itself reports
readiness before Ghostty captures the painted terminal state. The capture fixture
reveals the real statusline location field only after readiness; no preview label
is added to the image.

| Palette | Appearance | Gallery |
| --- | --- | --- |
| Dusk | Dark | [Languages, states, and integrations](themes/dusk.md) |
| Opal | Light | [Languages, states, and integrations](themes/opal.md) |
| Mira | Dark | [Languages, states, and integrations](themes/mira.md) |
| Mesa | Light | [Languages, states, and integrations](themes/mesa.md) |

Raw images live at `assets/screenshots/<schema>/<language>.png`. Geometry is
112 columns × 32 rows for the Zig hero and 100 × 48 for other language and LSP scenes.
The Neo-tree scene uses 132 × 44. Typography uses checksum-locked Maple Mono NF
SemiBold, with real Bold, SemiBold Italic, and Bold Italic faces. The hero uses a
38-pixel em; compact editor scenes use a 24-pixel em. Ghostty's X11 point sizes
are 28.5 and 18 at 96 DPI. Cell height increases by 12% and cell width by 2%.
Capture checks the resolved font files and fails on fallback. Neovim keeps
mode-specific, non-blinking cursor shapes: block in Normal mode, bar in Insert
mode. Syntax specimens park the block cursor on whitespace to keep text readable.
Capture does not mask pixels or allow comparison tolerance.

Pinned Pillow adds padding, an understated title bar with three macOS-style
buttons, no redundant window-title text, and antialiased rounded corners. It never resizes or filters terminal
pixels. The terminal background is opaque; only the outer corners are transparent.
Complete fixtures fit without scrolling. Gallery links embed the full-resolution
images.

Ghostty shapes ligatures and Nerd Font icons and renders diagnostic undercurls.
SemiBold approximates the fuller strokes of the original macOS captures without
macOS-only font thickening. Linux FreeType/OpenGL rasterization does not reproduce
macOS CoreText/Metal pixels exactly. The composed frame keeps native-style shading
and generous padding, rather than capturing a desktop window.

Syntax captures demonstrate Tree-sitter, not LSP semantic highlighting. Use the
[native language checks](color-system.md#verify-language-highlighting) to inspect
provider roles independently of screenshots. `scripts/preflight-screenshots.py`
checks input and image provenance, matching runtimes, and geometry. Its optional
OCR checks require Tesseract; the snapshot commands do not require host OCR tools.

## Working-state and LSP captures

[`states.go`](../examples/states.go) and [`states.lua`](../examples/states.lua)
exercise Neovim's real diff engine, changed-word surfaces, search, four fixture
diagnostics with signs/undercurls/virtual text, and Visual selection.

[`completion.go`](../examples/completion.go) and [`completion.lua`](../examples/completion.lua)
show a separate editing moment: gopls supplies `strings.TrimSpace` and
`strings.TrimSuffix` candidates for a partially typed call. Blink displays a
completion menu and resolved, syntax-highlighted documentation popup. Both windows
use single-line borders, the theme's `Normal` background, and `Visual` selection
highlights. Blink is checksum-locked and uses its Lua matcher with binary downloads
disabled for offline capture. To run the example separately, set
`FLUME_BLINK_RUNTIME` to a Blink checkout. Capture requires server identity,
observed candidates, nonempty documentation, and rendered syntax highlights, not
a hand-written list.

[`lsp-showcase.lua`](../examples/lsp-showcase.lua) attaches real gopls v0.16.2 or
ZLS 0.16.0 to an isolated workspace. Go 1.23.2 and Zig 0.16.0 are pinned with those
servers. Readiness requires observed semantic tokens and server hover content;
diagnostics are suppressed to isolate provider coloring. The hover shows the
signature and available documentation at a real call site. Sidecars identify
server version, settings, executable checksum, observed token counts, and hover content. These images do not qualify
other server versions or languages.

The lualine scene loads the real checksum-locked plugin with the named `flume`
theme, with real devicons. Its statusline uses the same palette as the editor.

The Neo-tree scene loads the real checksum-locked plugin, Plenary, Nui, and
nvim-web-devicons. Its isolated project contains staged additions, modified files,
and an untracked file. The sidebar exercises file icons, directory colors, selection,
indent guides, Git indicators, and inactive-window surfaces. No host repository or
personal file names appear.

| Palette | Selection and diagnostics | Completion | Tree-sitter + LSP |
| --- | --- | --- | --- |
| Dusk | [States](themes/dusk.md#diagnostics-and-working-states) | [Menu](themes/dusk.md#completion) | [Go](themes/dusk.md#go-with-gopls) · [Zig](themes/dusk.md#zig-with-zls) |
| Opal | [States](themes/opal.md#diagnostics-and-working-states) | [Menu](themes/opal.md#completion) | [Go](themes/opal.md#go-with-gopls) · [Zig](themes/opal.md#zig-with-zls) |
| Mira | [States](themes/mira.md#diagnostics-and-working-states) | [Menu](themes/mira.md#completion) | [Go](themes/mira.md#go-with-gopls) · [Zig](themes/mira.md#zig-with-zls) |
| Mesa | [States](themes/mesa.md#diagnostics-and-working-states) | [Menu](themes/mesa.md#completion) | [Go](themes/mesa.md#go-with-gopls) · [Zig](themes/mesa.md#zig-with-zls) |

## Code examples

Sources live in `examples/`. They use each language's conventions rather than
translating the same exercise. Role coverage spans the examples; no single file
demonstrates every highlight group.

| Source | Mechanism |
| --- | --- |
| [Go](../examples/flume.go) | A channel producer stops on cancellation; its caller waits for cleanup. |
| [Rust](../examples/flume.rs) | Typestate permits opening only after unlocking. |
| [Python](../examples/flume.py) | A JSON-lines event counter reports frequencies and percentages. |
| [TSX](../examples/flume.tsx) | A React counter records undo history through functional updates. |
| [Zig](../examples/flume.zig) | Recursive constant folding over a tagged expression union. |
| [Elixir](../examples/flume.ex) | A regex parser feeds a frequency-counting pipeline. |
| [TOML](../examples/flume.toml) | Illustrative preview-server configuration, not Flume configuration. |

Go requires 1.22+, Python 3.10+, and Elixir 1.10+. TSX requires React and its
TypeScript types. `zig run examples/flume.zig` prints `add folded = 42` with
Zig 0.16.0. Run `python3 examples/flume.py events.jsonl --limit 3` with records
such as `{"event":"play"}`, or `elixir tests/examples.exs` to check its parser.

## README composite

The normal snapshot commands generate and test `assets/screenshots/showcase.png`:
a 2800 × 1720 cascade of Opal, Mesa, Mira, and Dusk Zig captures over the original
artwork. Dusk is the foreground sample. Composition runs through pinned Pillow
in the capture environment; it preserves capture colors, rounded corners, and
aspect ratios. Each window fits within both size bounds so its statusline stays
inside the canvas. There is no manual screenshot or separate ImageMagick step.

## Integration contact sheets

These contact sheets show real applications through Linux Ghostty, not Kitty or
macOS Ghostty rendering. Each uses the same app fixture and geometry
across all four palettes. The short fzf, LSD, and Tmux fixtures use 16-row viewports
instead of mostly empty windows. Pi/OpenCode content is synthetic, but their UI is real.

| Integration | Exercised surface |
| --- | --- |
| Tmux | Exported status variables and active window |
| LSD | File types, permissions, sizes, dates, symlinks, and Git state |
| OpenCode | Core UI colors, Markdown emphasis, inline code, and plain code/diff text from an offline session |
| Lazygit | Repository files and add/change/delete diff state |
| fzf | Search, current item, and multi-selection |
| Delta | Added/changed/deleted diff lines and line numbers |
| Pi | Markdown, code, thinking, and successful/failed tool results |

The palette galleries embed each app's snapshot. Each integration directory also
contains `contact-sheet.png`, generated and tested from its four raw captures.

Ghostty and Kitty exports retain configuration-contract checks for syntax,
settings, ANSI slots, and exact canonical colors. Captures also exercise Ghostty's
Linux renderer, but not its selection, tabs, or live reload. Those behaviors and
native Kitty rendering remain separate qualification checks.

Historical hierarchy comparisons retain their inputs in
[capture metadata](../assets/screenshots/hierarchy/metadata.json). They are
archived evidence, not maintained showcase assets regenerated by this pipeline.
Exact role values and contrast pairs belong to the
[palette manifest](palette-manifest.md), not screenshot comparison tables.
