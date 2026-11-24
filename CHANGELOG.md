# Changelog

## v0.3.0 — 2026-11-24

### Upgrade notes

- All four palettes have visual changes. Pin a release tag or commit for a fixed appearance.
- Move active integration sets to `stdpath("data")/flume`, outside the plugin checkout. Run
  `:FlumeSync`, then `:FlumeInstallExtras` to relink installable integrations. Update manual includes
  using the [migration procedure](docs/semantic-export.md#migration-from-checkout-owned-state).
  Recognized checkout links are forwarded when writable, but do not survive checkout replacement.
- Running Flume editors now follow shared palette switches and color updates by default, retaining
  local options. Startup following remains opt-in. Set both `follow_sync = false` and
  `watch_sync = false` to keep an editor independent.
- The optional Lazygit extra now requires Lazygit 0.66.2+.
- Recommend lazy.nvim's `version = "*"` for release-based updates. Existing users must change their
  own spec to opt in. See [installation](README.md#install) for migration and development options.
- Remove Tuxedo themes and integration support.

### Palettes and highlighting

- Refine Dusk's violet canvas with muted amber types, teal functions, purple keywords, rose-red
  fields, sage strings and softened coral literals.
- Give Mira a lifted blue-violet canvas with matte honey types, sky-blue calls, lavender keywords,
  rose fields, mint strings and peach literals.
- Refine Opal's cool porcelain paper with apricot types, vivid violet keywords, berry fields,
  clear blue functions, eucalyptus strings and copper literals.
- Give Mesa cool violet-gray paper, ochre types, deeper violet keywords, petrol-blue calls,
  jade strings, berry fields and muted plum literals.
- Keep comments subordinate to code while retaining readable muted labels and metadata.
- Keep named constants, semantic type parameters and supported receiver captures neutral. Preserve
  accents for named types, calls, fields and literals, with parser-only generic fallbacks.
- Add explicit selection foreground/background roles and a changed-word surface that retains
  syntax colors. Improve contrast on cursor-line, selection and diff surfaces.
- Align macro, import, directive and escape roles across providers. Preserve function ink for Rust
  macro invocations and nongeneric Go factory calls, and type ink for TypeScript/TSX `new` expressions.
- Add independent `icon_*` file-icon roles to all palettes and the version 1 semantic export.

### Editor features

- Add editor-local `schema_overrides` between global role overrides and exact highlight overrides.
- Restore `colorscheme flume` as a compatibility entry that preserves the selected palette, or uses
  Dusk before setup. Accept `style` and `variant` as compatibility spellings of `schema`, with
  one-time migration warnings and conflict checks.
- Add opt-in development reload-on-save. With `dev = true`, `:FlumeSync` reloads source and
  regenerates extras before synchronization. Failed reloads attempt to restore the previous theme.
  Normal users sync bundled artifacts without regeneration.
- Preserve the displayed palette through compilation and reload, and keep a foreign theme selected
  during a failed reload. Retry failed watched refreshes without losing local options, and stop
  watching when another colorscheme takes over.
- Supply a palette-aware named lualine theme, readable Neo-tree hidden-item counts and indentmini
  ordinary/current-scope guide groups.

### Shared themes and integrations

- Publish complete, retained integration sets with `FLUME_DATA_DIR` and `get_sync_dir()` support.
  Preserve unrelated paths during legacy-link migration and refuse occupied installation targets.
- Add a versioned semantic palette export and health checks for shared state, stale links and reloads.
- Add Lazygit and Pi theme linking, with installation guidance separate from selection and reload.
- Add consent-based Fish syntax and pager themes without editing `config.fish`. Supply optional
  Fish 3.5+ `fish_tools` setup for fzf, Lazygit and `LS_COLORS`, with separate commands to preserve
  existing settings or adopt Flume's current-session exports.
- Add portable external-tool recipes and editor-local fzf.vim/Fzfx highlight recipes.
- Request Ghostty reloads on macOS and Linux, including Nix-wrapped builds. Reload attached Tmux
  configuration and notify linked Pi themes, reporting remaining manual reload steps.
- Add Tmux `thm_surface`, `thm_muted` and `thm_on_accent` variables without changing ANSI meanings.
- Improve Lazygit selected rows and metadata, Delta/Lazygit diff emphasis and line numbers,
  Pi tool panels and reasoning borders, and OpenCode state and diff-label colors.

### Documentation and visual evidence

- Add palette/language galleries, runnable specimens and a cascading README hero.
- Unify editor and terminal-app snapshots behind `scripts/snapshots test` and `update`, with pinned
  Linux Ghostty rendering, exact pixel comparisons, retained reports and generated contact sheets.
- Record parser, query, server, source and image provenance for all 52 editor scenes, including
  working states, completion, Go/Zig LSP output, installed lualine and Neo-tree.
- Add native parser/gopls checks, Delta output checks and four-palette integration contrast reports.
- Add isolated native-theme trials and an automated installed-Pi reload check. Keep Linux capture
  evidence separate from native macOS/Kitty rendering and external-application reload observations.

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
