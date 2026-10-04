# Semantic palette export

Flume publishes a generic color contract for custom consumers. Application-specific UI mappings belong in the consumer, not in Flume.

## Find the active export

Run `:FlumeSync` to create the active set. In Neovim, print its data directory:

```vim
:lua print(require("flume").get_sync_dir())
```

The default is `stdpath("data") .. "/flume"`. Set `FLUME_DATA_DIR` before starting Neovim to choose another absolute directory or share state between different Neovim application profiles. Configure consumers with the printed path rather than guessing a plugin-manager location.

Read `<data-dir>/current/palette.json`. Flume atomically replaces the `current` symlink after writing a complete immutable set. Watch the data directory, not the resolved file or previous set directory. Open the stable path again after a switch. Read schema metadata and colors from the same JSON document to avoid mixing activations.

Canonical files also ship as `extras/palette/flume-<schema>.json`. These are fixed palettes, not the active selection. Editor-local overrides do not affect either export.

## Format version 1

The document has four fields:

| Field | Meaning |
| --- | --- |
| `format_version` | Integer `1`. Reject unsupported versions explicitly. |
| `schema` | Canonical palette identifier, currently `dusk`, `opal`, `mira`, or `mesa`. |
| `appearance` | `dark` or `light`. |
| `colors` | Object mapping canonical role names to literal `#RRGGBB` colors. |

All roles in the [palette manifest](palette-manifest.md) are exported. Role meanings belong to the [color system](color-system.md). Consumers may ignore additional roles. Removing or changing the meaning of a role requires a new format version; adding roles or palettes does not.

Example envelope, with only three colors shown for brevity:

```json
{
  "format_version": 1,
  "schema": "opal",
  "appearance": "light",
  "colors": {
    "bg": "#f2eff7",
    "surface": "#ebe6f0",
    "text": "#413b49"
  }
}
```

## Consumer responsibilities

- Map roles to your application's actual foreground/background pairs. Use `on_accent` for text on a filled accent, not ordinary text by default.
- Validate every required role before applying a palette. Do not combine incomplete light palettes with dark defaults.
- Bound file reads and accept literal RGB colors, not terminal escape sequences or style expressions.
- Distinguish an absent optional integration from a missing or invalid explicitly configured file. Report configuration failures rather than silently claiming synchronization.
- Document whether an open UI reloads or only new invocations follow switches. An export does not provide live reload automatically.
- Test all four palettes and atomic switches, including selected text and popup chrome.

## Migration from checkout-owned state

v0.3 stores active sets outside the plugin checkout. Startup can read a valid old `extras/current/schema` until the first synchronization. Successful synchronization forwards the old `extras/current` symlink to the new owner and emits a directory event for legacy watchers when the checkout is writable. Old sets are retained.

Relink the five installable integrations with `:FlumeInstallExtras`. Update manual includes to `<data-dir>/current/...`. The forwarding link is transitional: deleting the plugin checkout still breaks paths through it, but direct links to the data directory survive replacement.

A short-lived exclusive directory lock serializes legacy forwarding between Flume activations. A stale lock is not stolen; if no Flume process is synchronizing, remove `extras/current.flume-lock` or relink directly to the data directory.

Flume refuses regular files, directories, or unrecognized symlinks observed at the legacy path. Do not edit that path concurrently with synchronization. If forwarding fails, synchronization still succeeds in the new owner and reports a warning. Move the old path aside and relink manually. Read-only plugin installations can use the new state without changing the checkout.
