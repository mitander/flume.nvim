# Design

Changing an editor's palette and publishing a shared integration set are different operations. A
local override should not silently rewrite terminal themes, and a consumer should not observe a
half-written set while another editor switches palettes.

Flume keeps canonical colors, editor-local resolution, generated artifacts and shared activation
with separate owners. The [color system](color-system.md) defines role meanings and contrast
obligations. The [semantic export](semantic-export.md) owns the versioned consumer contract.

## Ownership

| Owner                                         | Responsibility                                                                      |
| --------------------------------------------- | ----------------------------------------------------------------------------------- |
| `lua/flume/palette.lua`                       | Canonical palettes, role values and schema metadata                                 |
| `lua/flume/init.lua`                          | Editor options, palette application and resolved highlights                         |
| `lua/flume/commands.lua`                      | User commands, source reload/rollback and sync orchestration                        |
| `lua/flume/languages/`                        | Narrow language-provider corrections                                                |
| `lua/flume/integrations.lua`                  | Ordered integration inventory, artifact names, install destinations and setup hints |
| `lua/flume/compiler.lua`                      | Palette-to-text renderers and canonical artifact writes                             |
| `lua/flume/extras.lua`                        | Consent, safe installation and setup instructions                                   |
| `lua/flume/state.lua`                         | Shared data directory, complete active sets and legacy forwarding                   |
| `lua/flume/sync.lua`                          | Shared activation and application reload requests                                   |
| `lua/flume/watch.lua` and `dev.lua`           | Shared-palette following and local development reload                               |

## Resolve an editor palette

The editor starts from a canonical schema. Global role overrides apply first, selected-schema
overrides next and exact highlight overrides last. Generated extras use canonical palettes instead
of editor-local options. [The color system](color-system.md#invariants) owns that ordering.

Editor compatibility is normalized at setup and colorscheme entry points, not in the canonical
palette registry or exporters. The legacy `flume` entry keeps the selected palette and canonical
editor identity. Compatibility selectors warn once and normalize to `schema` before applying any
state. Conflicts and unknown names fail rather than guessing. This keeps old editor configurations
usable without creating alternate semantic-export identities or silently publishing shared themes.
The [help reference](../doc/flume.txt) owns migration instructions.

Startup following is opt-in. Running Flume editors watch shared activations by default. A changed
activation refreshes the receiver's canonical palette module from its installed source, even when
the schema name is unchanged. Local overrides, styles and exact highlights remain in effect. This
refresh does not reload the whole plugin or read another editor's source files. Other installations
need updated palette source. Identical palette metadata does not repaint the editor when only other
shared artifacts change.

Palette read failures leave the editor unchanged. If applying fresh colors fails, the watcher
restores the previous palette cache and options and attempts to repaint the old theme. A newer setup
or foreign colorscheme owns the editor instead of that rollback. Only successful refreshes advance
the observed activation, so publishing the same set again can retry a failure. Errors, including a
failed recovery repaint, are reported.

An independent editor disables both `follow_sync` and `watch_sync`. The help reference
([online](../doc/flume.txt)) owns the complete option and command behavior.

## Compile without activating

Compilation writes canonical files under `extras/`. Contributor regeneration explicitly uses
`compile_all({ activate = false })`, so refreshing committed output does not switch shared themes.
The generated palette manifest comes from the canonical Lua source, not a second hand-maintained
color table. [Development](DEVELOPMENT.md#regenerate-palette-artifacts) owns those commands.

## Add an integration

Add its artifact names and optional install destination to `integrations.lua`, then add a plain
renderer in `compiler.lua`. Renderers return text without choosing paths or writing files. The
compiler owns those writes and retains the `compile_<name>()` entry points. Shared publication and
health checks consume the same inventory. Keep app-specific color mappings in the renderer rather
than inventing a configuration language for them.

Static setup fragments can join the inventory without a palette renderer. The optional Fish tool
fragment is shipped once, copied into each complete active set and installed separately from Fish
syntax colors. It derives the stable shared path through its installation symlink. It normally
configures fzf and Lazygit only when unset, and replaces only the world-writable-directory rule in
`LS_COLORS`. An explicit `source ... --adopt` replaces session tool exports without changing
persistent universal variables. Personal prompts, application layouts and custom consumer mappings
remain with the consumer.

A stale static setup fragment is refreshed through complete-set publication, preserving the active
shared schema rather than selecting the installing editor's local palette. Published files are never
edited in place.

Installation reports linking separately from application selection and reload. The Fish tool
installer asks only whether to install the startup fragment. After installation it prints separate
source commands for preserving configured tools or adopting Flume's session exports. The source
argument controls the current-shell handoff, not a persistent override policy. Neovim cannot mutate
its parent shell's environment. Consent-based installs report completion through the same result
callback as immediate installs. The all-app installer processes the inventory in order so consent
dialogs cannot overlap. No installer edits `config.fish` or application configuration files.

## Publish shared themes

The editor's `FlumeSync` command normally publishes bundled artifacts. With `dev = true`, it first
reloads source and compiles canonical extras without activation, then performs the same sync. Source
reload or compilation failure stops before publication and reload requests. Save-time reload and
`FlumeReload` remain editor-local. Release selection belongs to the plugin manager, not dev mode.

Synchronization stages a complete set in the shared data directory, promotes it and atomically
replaces the `current` symlink. Published sets are retained so readers of an earlier set are not
invalidated by another activation. Consumers reopen the stable path after a switch and read schema
metadata and colors from one document.

Legacy checkout forwarding is transitional and must preserve unrelated paths. Its refusal and
recovery rules remain in
[the migration contract](semantic-export.md#migration-from-checkout-owned-state). Atomic active-set
selection is not proof that every external application reloaded. Sync requests reloads where
supported, while each consumer owns how and when it reads the selected file.

## Observe the result at its boundary

The optional `scripts/native-themes` trial copies the checkout and creates private application
configuration and shared state. Its switch driver disables external Ghostty/Tmux reload commands
while exercising Pi's filesystem notification. Native terminal reloads and visual observations stay
manual. Preparation does not launch apps, install tools, change live configuration or approve a
baseline. The trial is configuration isolation, not an OS sandbox.

Defined roles, generated configuration, real parser captures, exact pixels and live application
reloads answer different questions. [Testing](TESTING.md) selects their owners and limits.
[Showcase](showcase.md) explains real capture provenance. No generated comparison or baseline update
can decide readability or approve itself.
