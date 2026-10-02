# Changelog

## Unreleased

- Add generated Textual themes for the Pantheon Linear and Jira TUIs.
- Normalize tracker-owned workflow and identity colors onto canonical Flume
  roles instead of mixing Linear or Jira colors into the active palette.
- Include the active Tracker TUI theme in the atomic integration set so patched
  clients can follow `:FlumeSync` while running.
- Let running Neovim instances follow synchronized palettes by default;
  disable this with `watch_sync = false`.
- Stop synchronization watching when another colorscheme takes over,
  including already queued palette changes.
- Retain immutable integration sets so concurrent activations cannot delete
  each other's files.
- Use actual Tree-sitter highlighting for canonical screenshots and record
  parser/query provenance instead of manually assigning token colors.
- Add native parser fixtures and role checks for Zig, Rust, Python,
  TypeScript/TSX, Go, and Elixir.
- Keep readonly/static bindings and fields in their normal syntax roles,
  and let ZLS namespace tokens use the namespace color.
- Remove Tuxedo themes and integration support.

## v0.2.0 — 2026-07-27

### Palettes

- Add four deliberate canonical palettes: `dusk`, `opal`, `mira`, and `mesa`.
  Appearance is explicit metadata rather than part of each public name.
- Add `flume-dusk`, `flume-opal`, `flume-mira`, and `flume-mesa` entry points.
- Use quieter neutral comment inks in Opal and Mesa.
- Generate the exact role and contrast manifest from the canonical Lua palette.

### Integrations and release evidence

- Generate forty committed files across Ghostty, Kitty, Tmux, LSD, OpenCode,
  Lazygit, fzf, Delta, Pi, and Tuxedo.
- Give Pi and Tuxedo artifacts unique palette identities instead of downstream
  project names.
- Add parsed four-palette contracts for all ten formats, including JSON alias
  resolution, native Git-config parsing for Delta, exact keys, and ANSI slots.
- Add transactional activation coverage for every format and explicit active
  schema markers.
- Add a deterministic editor/ANSI fixture, screenshot preflight, cascading
  showcase compositor, and metadata-driven native contact-sheet recipe.
- Extend health checks to the selected palette and all ten generated formats.

Automated extra installation remains limited to the five integrations with safe
standard destinations. All ten formats are still generated.

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
