# Compare palette edits

Run `:FlumeTweak` to try role colors without changing your editor theme, configuration, terminal
colors or synchronized integrations. An optional palette name chooses the initial preview:

```vim
:FlumeTweak opal
```

A scratch tab opens with role controls, a code sample and labelled UI color samples. Samples use your
installed Tree-sitter parsers and highlight queries. Missing parsers or queries produce explicitly
labelled plain text. The tool does not install parsers or start language servers.

## Try a color

A [role](color-system.md#palettes-roles-and-themes) names a color's job, such as a function name or
selection background. Move to one with normal cursor keys or search for its name. The first
selected role is `syntax_function`.

| Key          | Action                                                           |
| ------------ | ---------------------------------------------------------------- |
| `h` / `l`    | Cycle darker/lighter candidates around the role's starting color |
| `c`          | Choose another ink from the preview palette                      |
| Enter        | Enter a six-digit `#RRGGBB` color                                |
| `r`          | Reset the selected role to its starting value                    |
| `p` / `P`    | Next/previous palette, retaining separate drafts                 |
| `s` / `S`    | Next/previous language sample                                    |
| `y`          | Copy edited roles as a Lua `schema_overrides` field              |
| `q` / Escape | Close and discard the draft                                      |

Palette, sample, copy and close keys also work in the sample and swatch panes. Code is read-only,
but normal navigation and Visual selection work. Press Escape once to leave Visual mode and again to
close the preview. Reopening the command focuses its existing tab. Accurate previewing requires
`termguicolors`, at least 80 columns and 22 rows.

The preview starts from your resolved global and per-schema role overrides and retains syntax
styles. It uses opaque surfaces and bypasses exact highlight-group overrides so the role you are
editing stays visible. Compare an edit on selections, diagnostics and diff surfaces before keeping
it. A candidate color is not automatically contrast-checked.

## Import a palette draft

Load a group of proposed colors without changing your setup:

```vim
:FlumeTweakImport /path/to/draft.json
```

The command opens or reuses the preview and selects the file's palette. Imported colors become
edits, not a new starting palette. `r` restores the selected role to its resolved starting color,
`h`/`l` explore shades around the imported ink, and `y` copies imported changes together with your
later edits. Closing the preview discards them. Neither the draft file nor your configuration is
written, and no global or shared theme is activated.

If that palette already has edits, the command refuses to replace them. Use
`:FlumeTweakImport! /path/to/draft.json` to explicitly replace its entire draft. Drafts for other
palettes remain intact. Invalid input is rejected before opening or changing the preview, even with
`!`.

Try the [Dusk pastel candidate](../examples/dusk-pastel.json) from the plugin checkout:

```vim
:FlumeTweakImport examples/dusk-pastel.json
```

This is an exploratory plum-and-pastel draft, not a fifth palette or a change to canonical Dusk. It
leaves Dusk's state and ANSI inks unchanged. Compare it with selections, diffs and diagnostics
before keeping it. Imported colors are not automatically contrast-checked.

### Draft file format

Drafts are JSON data, never Lua or executable configuration. Version 1 requires exactly these three
fields:

```json
{
  "version": 1,
  "schema": "dusk",
  "colors": {
    "bg": "#282332",
    "syntax_keyword": "#c4abd8",
    "syntax_property": "#d6a5bd"
  }
}
```

`schema` must name an installed palette. `colors` must be a nonempty object of known role names and
six-digit `#RRGGBB` strings. Hexadecimal letters are case-insensitive. Omitted roles retain their
resolved starting values. Unknown fields, roles, schemas and versions are rejected. Input must be a
regular file no larger than 64 KiB. Relative paths resolve from Neovim's current directory. Filename
completion is available, and escaped spaces are accepted.

Tools can write this format without loading Neovim or changing canonical palette files. A Lua
caller can use `require("flume.tweak").import_file(path, replace)`, where `replace` defaults to
`false`. It returns `true` after import, or `false` with a notification for invalid input, existing
edits or unmet preview prerequisites. The file contains the colors themselves, so loading it needs
no hash lookup, registry or network service.

## Keep an edit

Press `y` to copy only edited roles to the unnamed register. Merge the copied field into your setup,
retaining any existing per-schema overrides:

```lua
require("flume").setup({
    schema = "dusk",
    schema_overrides = {
        dusk = {
            syntax_function = "#7dacbb",
        },
    },
})
```

Copying does not apply the draft or write a file. Exact highlight-group overrides still win in your
actual setup, so update them separately if they hide a role edit. Closing the preview discards its
in-memory drafts. Reloading Flume, changing the global colorscheme or deleting a preview buffer also
closes it. Your other buffers, including modified work, remain untouched.

Editor-local overrides do not change generated external themes. To make a color canonical, edit the
palette source and follow the [regeneration procedure](DEVELOPMENT.md#regenerate-palette-artifacts).

## What the samples establish

The Lua, Rust, Python, TypeScript, TSX, Zig and Go samples are reading fixtures, not runnable apps
or API tutorials. Their status identifies actual Tree-sitter highlighting or plain-text fallback.
FileType hooks and Vim syntax files are not loaded for the scratch samples.

Cursor-line and Visual selection are native editor states. Errors and warnings are example
diagnostics, not language-server findings. The lower pane shows labelled swatches for Visual,
completion, search, diff and diagnostic groups. These are not live menus or a running diff engine.
Integration-only roles, such as file-icon inks, also appear as swatches rather than simulated apps.

For contributor checks of real parser-colored cells and live role edits in all four palettes, see
[Native preview checks](TESTING.md#native-tweak-preview).
