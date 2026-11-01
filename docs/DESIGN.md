# Design

Changing an editor's palette and publishing a shared integration set are different operations. A
local override should not silently rewrite terminal themes, and a consumer should not observe a
half-written set while another editor switches palettes.

Flume keeps canonical colors, editor-local resolution, generated artifacts and shared activation
with separate owners. The [color system](color-system.md) defines role meanings and contrast
obligations. The [semantic export](semantic-export.md) owns the versioned consumer contract.

## Ownership

| Owner | Responsibility |
| - | - |
| `lua/flume/palette.lua` | Canonical palettes, role values and schema metadata |
| `lua/flume/init.lua` | Editor options, resolved highlights and user commands |
| `lua/flume/languages/` | Narrow language-provider corrections |
| `lua/flume/integrations.lua` | Ordered integration inventory, artifact names, install destinations and setup hints |
| `lua/flume/compiler.lua` | Palette-to-text renderers and canonical artifact writes |
| `lua/flume/extras.lua` | Consent, safe installation and setup instructions |
| `lua/flume/state.lua` | Shared data directory, complete active sets and legacy forwarding |
| `lua/flume/sync.lua` | Shared activation and application reload requests |
| `lua/flume/watch.lua` and `dev.lua` | Shared-palette following and local development reload |
| `lua/flume/tweak.lua` and `tweak_samples.lua` | Opt-in, window-local role exploration and reading fixtures |

## Resolve an editor palette

The editor starts from a canonical schema. Global role overrides apply first, selected-schema
overrides next and exact highlight overrides last. Generated extras use canonical palettes instead
of editor-local options. [The color system](color-system.md#invariants) owns that ordering.

Startup following is opt-in. Running Flume editors watch shared palette changes by default. An
independent editor disables both `follow_sync` and `watch_sync`. The help reference
([online](../doc/flume.txt)) owns the complete option and command behavior.

## Compile without activating

Compilation writes canonical files under `extras/`. Contributor regeneration explicitly uses
`compile_all({ activate = false })`, so refreshing committed output does not switch shared themes.
The generated palette manifest comes from the canonical Lua source, not a second hand-maintained
color table. [Development](DEVELOPMENT.md#regenerate-palette-artifacts) owns those commands.

## Preview role edits without changing the editor

`FlumeTweak` draws into a dedicated highlight namespace assigned only to its scratch windows.
`set_highlights(namespace, colors, config)` reuses the editor's mapping without selecting a palette,
clearing global highlights, changing terminal inks or publishing state. Normal loading still applies
that mapping globally, with exact overrides after base groups and terminal values available to
callbacks.

The preview snapshots resolved role values and syntax styles. It uses opaque surfaces and omits
exact group overrides so role changes remain visible. Drafts stay in memory and can be copied as
`schema_overrides`; they are never applied or persisted automatically. Actual parsers color the
samples, with explicit plain-text fallback status. Vim syntax files are not sourced because they
can write global highlight definitions. FileType hooks are suppressed for the scratch buffers. Labelled UI swatches and example diagnostics are not evidence of live plugin menus
or language-server behavior.

The session owns only its scratch buffers, windows and autocommands. Closing it, deleting a sample,
changing the global colorscheme or reloading Flume releases those resources without rolling back a
theme: the original theme was never changed. A surviving final window must leave the preview
namespace and restore the invoking window's options before showing ordinary work. Deferred input
callbacks must match the current live session before editing it. [The preview guide](tweak.md) owns controls and user-visible limits.

## Add an integration

Add its artifact names and optional install destination to `integrations.lua`, then add a plain
renderer in `compiler.lua`. Renderers return text without choosing paths or writing files. The
compiler owns those writes and retains the `compile_<name>()` entry points. Shared publication and
health checks consume the same inventory. Keep app-specific color mappings in the renderer rather
than inventing a configuration language for them.

Static setup fragments can join the inventory without a palette renderer. The optional Fish tool
fragment is shipped once, copied into each complete active set and installed separately from Fish
syntax colors. It derives the stable shared path through its installation symlink. It normally configures
fzf and Lazygit only when unset, and replaces only the world-writable-directory rule in `LS_COLORS`.
An explicit `source ... --adopt` replaces session tool exports without changing persistent universal
variables. Personal prompts, application layouts and custom consumer mappings remain with the
consumer.

A stale static setup fragment is refreshed through complete-set publication, preserving the active
shared schema rather than selecting the installing editor's local palette. Published files are
never edited in place.

Installation reports linking separately from application selection and reload. The Fish tool
installer offers adoption or preservation and prints the corresponding one-line source command.
Both choices install the same startup fragment. The choice controls the current-shell handoff,
not a persistent override policy. Neovim cannot mutate its parent shell's environment. Consent-based
installs report completion through the same result callback as immediate installs. The all-app
installer processes the inventory in order so consent dialogs cannot overlap. No installer edits
`config.fish` or application configuration files.

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

Defined roles, generated configuration, real parser captures, exact pixels and live application
reloads answer different questions. [Testing](TESTING.md) selects their owners and limits.
[Showcase](showcase.md) explains real capture provenance. No generated comparison or baseline update
can decide readability or approve itself.
