# Changelog

## Unreleased

- Soften Dusk's amber types, rose fields and namespaces, and coral literals. Retain its violet
  canvas, teal functions, lavender keywords, sage strings, and stronger state and ANSI inks.
- Add editor-local `schema_overrides` for per-palette role customization. Resolve global overrides
  first, then the selected palette's overrides, with exact highlight overrides last.
- Add LSD shell setup to `:FlumeExtras` for pink world-writable directory names without a background.
- Give Mira a near-neutral charcoal foundation distinct from Dusk's violet canvas. Soften its
  syntax and ANSI inks around mineral blue and sea-glass, with muted berry properties, sand types,
  and copper literals. Soften neutral foregrounds without dimming structural accents. Retain
  readable selections, diagnostics, and diff surfaces.
- Refine Opal's syntax around purple types, red fields/imports, copper literals, sea-glass strings,
  and softened teal functions on its existing cool paper canvas. Deepen the inks for readable
  working states and use a clearer yellow warning fill. Keep neutral identifiers, semantic state
  inks, and ANSI slots unchanged.
- Move Mesa from warm beige paper to soft rose-gray with a slight mauve undertone. Coordinate
  raised, selection, and diff surfaces while retaining its restrained syntax and ANSI inks.
- Add explicit selection foreground/background roles for Visual, completion, command-line menus,
  Ghostty, and Kitty. Retain quieter active-control surfaces.
- Use readable muted ink for hidden and ignored filenames, fold controls, inactive lualine text, LSD
  metadata, and OpenCode quoted prose and line numbers.
- Use restrained cool-gray comments in all four palettes. Share ordinary and documentation-comment
  inks within each palette, keeping prose secondary to code while preserving readable contrast.

## v0.3.0

### Upgrade notes

- Active integration sets now live in `stdpath("data")/flume`, outside the plugin checkout. Run
  `:FlumeInstallExtras` to relink installable integrations and update manual includes to the shared
  data directory. Recognized checkout links are forwarded when writable, but do not survive checkout
  replacement. See the
  [migration procedure](docs/semantic-export.md#migration-from-checkout-owned-state).
- Running Flume editors follow `:FlumeSync` switches by default. To keep an editor independent at
  startup and while running, set both `follow_sync = false` and `watch_sync = false`. Startup
  following remains opt-in.
- Remove Tuxedo themes and integration support.

### Palettes and highlighting

- Give changed words a semantic `diff_text_bg` surface that retains syntax colors.
- Strengthen syntax contrast on cursor-line, selection, and diff surfaces in all four palettes.
  Improve diagnostic and menu text without changing the canvases or ANSI slots. Keep search matches
  readable when Visual replaces their background; distinguish current matches with bold and
  underlined text.
- Align legacy, Tree-sitter, and LSP macro roles; align imports, directives, and string escapes
  across providers.
- Add real Neovim selection, diagnostic, diff, search, completion, and Go/Zig LSP captures through
  headless Ghostty with runtime provenance. Refresh the clean palette specimens.

### Shared themes and integrations

- Store synchronized integration sets in `stdpath("data")/flume`, independent of plugin checkout
  replacement. Support `FLUME_DATA_DIR` and `get_sync_dir()`.
- Forward recognized legacy checkout links when writable; installers now link directly to shared
  state. Preserve unrelated paths and report migration failures.
- Publish a versioned generic semantic palette export for custom consumers.
- Add a four-palette integration contrast report with actual exported pairs, palette hierarchy,
  before/after Git comparisons, and optional JSON measurements. Native visual review remains
  separate from deterministic contrast checks.
- Report shared state, stale integration links, and reload requirements in health checks.
- Isolate activation tests from user state and the working checkout.

- Add opt-in startup selection from the synchronized integration schema with `follow_sync`, while
  keeping the configured schema as a fallback.
- Add opt-in development reload-on-save that preserves the editor palette.
- Supply a palette-aware named lualine theme and the tree statusline highlight.
- Publish portable fzf, Lazygit, and Delta activation recipes.
- Let running Neovim instances follow synchronized palettes by default; disable this with
  `watch_sync = false`.
- Stop synchronization watching when another colorscheme takes over, including already queued
  palette changes.
- Retain immutable integration sets so concurrent activations cannot delete each other's files.
- Keep readonly/static bindings and fields in their normal syntax roles, and let ZLS namespace
  tokens use the namespace color.

### Documentation and visual evidence

- Restore the constant-folding Zig specimen and wider, shorter windows in the cascading README hero.
  Add labelled palette previews and an expandable language gallery; keep application state and LSP
  evidence on the showcase page.
- Use actual Tree-sitter highlighting for canonical screenshots and record parser/query provenance
  instead of manually assigning token colors.
- Add native parser fixtures and role checks for Zig, Rust, Python, TypeScript/TSX, Go, and Elixir.
- Unify editor, lualine, and seven terminal-app snapshots behind headless `scripts/snapshots test`
  and `update` commands. Generate and test the README hero and integration contact sheets through
  the same pinned pipeline. Preserve real parser, diagnostic, completion, and language-server
  evidence, with exact pixel comparisons and visual reports. Keep Ghostty/Kitty configuration checks
  separate from native renderer qualification.
- Pin JetBrains Mono Nerd Font Mono SemiBold and its real bold/italic faces for high-resolution
  captures across every palette and application. Preserve exact RGB colors from Ghostty's X11
  output through PNG composition, and add rounded corners with a restrained macOS-style title bar.
  Keep complete foreground windows visible in the hero and use compact viewports for short app fixtures. Use larger showcase typography, clean title bars, and
  mode-specific non-blinking cursors. Signal capture readiness through real status information
  instead of adding preview labels to the images.

## v0.2.0 — 2026-07-27

### Palettes

- Add four deliberate canonical palettes: `dusk`, `opal`, `mira`, and `mesa`. Appearance is explicit
  metadata rather than part of each public name.
- Add `flume-dusk`, `flume-opal`, `flume-mira`, and `flume-mesa` entry points.
- Use quieter neutral comment inks in Opal and Mesa.
- Generate the exact role and contrast manifest from the canonical Lua palette.

### Integrations and release evidence

- Generate forty committed files across Ghostty, Kitty, Tmux, LSD, OpenCode, Lazygit, fzf, Delta,
  Pi, and Tuxedo.
- Give Pi and Tuxedo artifacts unique palette identities instead of downstream project names.
- Add parsed four-palette contracts for all ten formats, including JSON alias resolution, native
  Git-config parsing for Delta, exact keys, and ANSI slots.
- Add transactional activation coverage for every format and explicit active schema markers.
- Add a deterministic editor/ANSI fixture, screenshot preflight, cascading showcase compositor, and
  metadata-driven native contact-sheet recipe.
- Extend health checks to the selected palette and all ten generated formats.

Automated extra installation remains limited to the five integrations with safe standard
destinations. All ten formats are still generated.

## v0.1.0 — 2026-07-12

First public test release.

### Breaking visual changes

- Constructors now use the type color.
- Imports, word-like operators, and directives use distinct semantic roles.
- Namespace highlighting is consistent across languages.
- Rust, Python, Lua, TSX, and Zig receive narrowly scoped parser or language-server corrections.
- Keyword-heavy code uses a broader color balance with less violet dominance.

### Included

- Dark Neovim colorscheme with Tree-sitter and LSP semantic-token support.
- Configurable palette overrides, syntax styles, transparency, and exact highlights.
- Diagnostics and focused integrations for common Neovim plugins.
- Generated themes for Ghostty, Tmux, LSD, Pi, and Tuxedo.
- Reload, compilation, installation, and health-check commands.
