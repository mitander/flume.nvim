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
locale, fonts, dimensions, and Linux amd64 tools. ARM Macs use the same binaries
as CI. Two isolated capture containers run at a time. Pi and OpenCode restore
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
readiness before VHS captures the painted terminal state.

| Palette | Appearance | Gallery |
| --- | --- | --- |
| Dusk | Dark | [Languages, states, and integrations](themes/dusk.md) |
| Opal | Light | [Languages, states, and integrations](themes/opal.md) |
| Mira | Dark | [Languages, states, and integrations](themes/mira.md) |
| Mesa | Light | [Languages, states, and integrations](themes/mesa.md) |

Raw images live at `assets/screenshots/<schema>/<language>.png`. Geometry is
112 columns × 32 rows for Zig, 100 × 48 for other editor scenes, with DejaVu Sans
Mono at 16 pixels, fixed padding, and an opaque background. Complete fixtures fit
without scrolling. Gallery links embed these same full-resolution images.

Syntax captures demonstrate Tree-sitter, not LSP semantic highlighting. Use the
[native language checks](color-system.md#verify-language-highlighting) to inspect
provider roles independently of screenshots. `scripts/preflight-screenshots.py`
checks input and image provenance, matching runtimes, and geometry. Its optional
OCR checks require Tesseract; the snapshot commands do not require host OCR tools.

## Working-state and LSP captures

[`states.go`](../examples/states.go) and [`states.lua`](../examples/states.lua)
exercise Neovim's real diff engine, changed-word surfaces, search, four fixture
diagnostics with signs/underlines/virtual text, and either Visual selection or
Insert-mode completion. Selection and completion are separate scenes because
one editor cannot show both modes at once. They do not paint imitation UI states.

[`lsp-showcase.lua`](../examples/lsp-showcase.lua) attaches real gopls v0.16.2 or
ZLS 0.16.0 to an isolated workspace. Go 1.23.2 and Zig 0.16.0 are pinned with those
servers. Readiness requires observed semantic tokens; diagnostics are suppressed
to isolate provider coloring. Sidecars identify server version, settings,
executable checksum, and observed token counts. These images do not qualify
other server versions or languages.

The lualine scene loads the real checksum-locked plugin with the named `flume`
theme. Its statusline uses the same palette as the editor.

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
in the capture environment; it preserves capture colors and aspect ratios.
There is no manual screenshot or separate ImageMagick step.

## Integration contact sheets

These contact sheets show real applications through VHS's ttyd/Chromium terminal,
not native Ghostty or Kitty rendering. Each uses the same app fixture and geometry
across all four palettes. Pi/OpenCode content is synthetic, but their UI is real.

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

Ghostty and Kitty exports remain configuration-contract checks: syntax,
settings, ANSI slots, and exact canonical colors. Rendering those files in VHS
would not test either terminal. Native selection/cursor/tab behavior and live
reload remain optional, separate qualification rather than routine pixel tests.

Historical hierarchy comparisons retain their inputs in
[capture metadata](../assets/screenshots/hierarchy/metadata.json). They are
archived evidence, not maintained showcase assets regenerated by this pipeline.
Exact role values and contrast pairs belong to the
[palette manifest](palette-manifest.md), not screenshot comparison tables.
