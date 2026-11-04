# Changelog

## v0.3.0 (unreleased)

### Upgrade notes

- The recommended lazy.nvim spec now uses `version = "*"` to follow release tags instead of
  `master`. Existing users must change their own spec to opt into release-based updates. See
  [installation](README.md#install) for migration steps and the explicit development opt-in.
- Active integration sets now live in `stdpath("data")/flume`, outside the plugin checkout. Run
  `:FlumeSync`, then `:FlumeInstallExtras` to relink installable integrations. Update manual
  includes to the shared data directory. Recognized checkout links are forwarded when writable, but
  do not survive checkout replacement. See the
  [migration procedure](docs/semantic-export.md#migration-from-checkout-owned-state).
- Running Flume editors follow `:FlumeSync` switches and same-palette color updates by default.
  Refresh the receiver's canonical palette cache while retaining local options. Failed refreshes
  keep the previous palette and can retry the same published set. Startup following remains opt-in
  through `follow_sync = true`. To keep an editor independent at startup and while running, set both
  `follow_sync = false` and `watch_sync = false`.
- Restore `colorscheme flume` as a compatibility entry that keeps the selected editor palette, or
  Dusk before setup. Accept `style` and `variant` as compatibility spellings of `schema` for the
  four named palettes. Warn once per session with migration guidance, without dropping local
  options or activating external themes. Reject conflicting selectors before changing the editor.
- All four palettes have visual changes. Pin a release tag or commit if you need a fixed appearance.
- Remove Tuxedo themes and integration support.

### Palettes and highlighting

- Refine Dusk's warm syntax with muted amber types, rose-red fields, quiet rose namespaces and
  softened coral literals. Retain its violet canvas, teal functions, purple keywords and sage
  strings.
- Make Mira a more open, easygoing dark palette with a lifted blue-violet canvas and matte honey,
  sky-blue, lavender, rose, mint and peach syntax. Soften neutral text and lower the syntax brightness
  band while keeping types and calls above fields and secondary ink. Use nearly achromatic text
  and slightly more chromatic rose-red fields at similar lightness, preserving the warm honey/peach
  relationship. Keep quiet surfaces and independent teal UI focus, diagnostics, ANSI and file-icon inks.
- Refine Opal around deep apricot types, vivid violet keywords, pink-berry fields/imports, copper
  literals, eucalyptus strings and clear blue functions on cool porcelain paper. Replace gold types
  with a readable peach-family ink rather than adding more blue or muting the colorful accents.
  Make cursor-line/raised and statusline tiers clearer while retaining pale diff fills and readable
  syntax ink.
- Refine Mesa around nearly neutral violet-gray paper, ochre types, deeper violet keywords,
  petrol-blue calls, clear jade strings, lighter berry fields and muted plum literals. Separate
  frequent syntax by hue and lightness rather than accumulating similarly dark brown and yellow-green
  inks. Replace warm paper and clay-colored panels with coordinated cool cursor-line, raised and
  active-row surfaces. Preserve independent diagnostic, success, UI focus, ANSI and file-icon inks.
- Use restrained low-chroma comment inks in all four palettes. Ordinary and documentation comments
  stay subordinate to code. Keep muted text readable for inactive labels, hidden files and metadata.
- Render named constants in neutral identifier ink. Keep numbers, booleans, built-in constants, tags
  and symbol literals accented. Keep readonly/static bindings and fields in their normal syntax
  roles, and use the namespace color for ZLS namespace tokens.
- Add explicit selection foreground/background roles for Visual, completion, command-line menus,
  Ghostty and Kitty. Give changed words a semantic `diff_text_bg` surface that retains syntax
  colors. Strengthen text contrast on cursor-line, selection and diff surfaces. Preserve search
  underlines through Visual selection and distinguish current matches with bold, underlined text.
- Align legacy, Tree-sitter and LSP macro roles. Align imports, directives and string escapes across
  providers.
- Use neutral ink for semantic type parameters and supported language receiver captures while
  retaining named-type, call, field and literal families. Keep TypeScript and TSX `new` expressions
  in the type family without changing JSX tags. Keep Go `New...`/`Make...` factory calls in the
  function family. Preserve parser-only generic fallbacks where queries cannot distinguish type
  parameters.
- Add dedicated `icon_*` roles for file-icon hue families across all four schemas. Keep muted copper
  distinct from brighter orange and gold/yellow without borrowing syntax or ANSI colors. Include
  these roles in the version 1 semantic palette export.

### Editor features

- Add editor-local `schema_overrides` for per-palette customization. Resolve global role overrides
  first, selected-schema overrides next and exact highlight overrides last.
- Add opt-in development reload-on-save that preserves the editor palette. With `dev = true`,
  `:FlumeSync` reloads source and regenerates canonical extras before synchronizing. Failed source
  reloads restore the previous modules and theme. Normal users sync bundled artifacts without
  regeneration.
- Supply a palette-aware named lualine theme and the tree statusline highlight. Define indentmini's
  ordinary and current-scope guide groups with palette roles.
- Stop shared-palette watching when another colorscheme takes over, including already queued
  changes. Reloading preserves the editor's current palette rather than rereading the startup
  preference.

### Shared themes and integrations

- Store synchronized integration sets outside the checkout, with `FLUME_DATA_DIR` and
  `get_sync_dir()` support. Retain complete immutable sets so concurrent activations cannot delete
  files another reader still uses. Preserve unrelated paths during legacy-link migration and report
  failures.
- Publish a versioned generic semantic palette export for custom consumers. Report shared state,
  stale integration links and reload requirements in health checks.
- Add Lazygit and Pi theme linking. Installation reports its destination and next setup step
  separately from application selection or reload. Refuse existing regular files and directories.
- Keep Lazygit selected rows readable by retaining filename and Git-status inks on quiet active-row
  surfaces instead of applying the foreground meant for stronger selections.
- Add Fish syntax and pager themes with consent-based installation that leaves `config.fish`
  untouched. Existing shells can source the active fragment again after synchronization.
- Add optional `:FlumeInstallExtras fish_tools` for Fish 3.5+ setup of fzf, Lazygit and the
  world-writable-directory `LS_COLORS` rule. Ask whether to install, then print separate source
  commands to preserve configured tools or replace current-session exports. Neither command changes
  persistent variables. Refresh stale setup fragments without switching the shared palette.
- Document editor-local fzf.vim/Fzfx highlight mapping separately from shared shell FZF options.
  Explain option precedence and how local role overrides differ from exact highlight overrides.
- Publish portable fzf, Lazygit and Delta activation recipes and manual LSD filename-color setup.
  Give artifact names, install destinations and setup hints one integration inventory. Separate
  palette renderers from file writes while preserving compiler entry points and output.
- Request Ghostty reloads through AppleScript on macOS or `SIGUSR2` on Linux, source Tmux's
  configuration when attached, and notify a linked Pi theme. Keep sync feedback brief, with manual
  reload hints only for installed adapter links whose refresh failed. Other applications still need
  their own reload action or a new invocation.
- Add Tmux UI variables `thm_surface`, `thm_muted` and `thm_on_accent` for raised panels, secondary
  labels and text on filled accents. Keep the existing ANSI and placeholder variables' meanings
  unchanged.
- Keep Delta and Lazygit diff syntax readable with quieter emphasis fills and underlined changed
  words. Use neutral raised panels for successful Pi tool results and tinted panels for failures.
  Measure OpenCode labels and signs on their actual surfaces and capture its real edit diff.
- Use UI focus ink for Pi's highest reasoning border without changing keyword highlighting.

### Documentation and visual evidence

- Add palette and language galleries, with extra languages collapsed on palette pages and a
  cascading README hero. Use runnable, self-contained specimens covering generic queues, owned
  rejection envelopes, contrast calculations and picker state alongside the existing React,
  Elixir and TOML examples.
- Unify editor, lualine, Neo-tree and seven terminal-app snapshots behind `scripts/snapshots test`
  and `update`. Generate the hero and integration contact sheets through the same pinned, isolated
  Linux Ghostty pipeline with exact pixel comparisons and review reports.
- Capture actual Tree-sitter highlighting, selection, diagnostics, diffs, search, completion and
  Go/Zig language-server output. Record parser, query, server, source and image provenance. Keep
  Ghostty/Kitty configuration checks separate from native renderer qualification.
- Pin JetBrains Mono Nerd Font Mono SemiBold and its bold/italic faces. Preserve exact RGB pixels
  through PNG composition, with rounded frames, compact integration viewports and non-blinking
  mode-specific cursors. Reveal real status information only after capture readiness.
- Separate command registration, reload and sync orchestration from rendering inputs so nonvisual
  command changes do not invalidate editor capture provenance.
- Add native parser fixtures and role checks for Zig, Rust, Python, TypeScript/TSX, Go, Lua and
  Elixir, plus real gopls generic-token checks. Qualify native Delta output alongside snapshots and
  add four-palette integration contrast reports.
  Keep activation tests isolated from user state and the working checkout.

- Add a disposable native-theme trial for manual Ghostty/Kitty rendering and Pi reload checks,
  plus an opt-in installed-Pi output check. Keep trial configuration and palette state separate from
  live user settings. Terminal reloads remain manual.

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
