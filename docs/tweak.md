# Compare palette edits

Run `:FlumeTweak` to explore role colors without changing the current editor theme, configuration,
terminal inks or synchronized integrations. You can open it even when another colorscheme is active.
An optional palette name chooses the initial preview:

```vim
:FlumeTweak opal
```

The command opens a scratch tab with role controls, a code sample and labelled UI swatches. Preview
windows have their own highlight namespace, using the same role mapping as the editor. Closing the
preview needs no theme rollback because the original theme was never replaced.

## Try a color

In the role panel, move to a role with normal cursor keys or search for its name. The first selected
role is `syntax_function`.

| Key | Action |
| - | - |
| `h` / `l` | Cycle darker/lighter candidates around the role's starting color |
| `c` | Choose another ink from the preview palette |
| Enter | Enter a six-digit `#RRGGBB` color |
| `r` | Reset the selected role to its starting value |
| `p` / `P` | Next/previous palette, retaining separate drafts |
| `s` / `S` | Next/previous language sample |
| `y` | Copy edited roles as a Lua `schema_overrides` field |
| `q` / Escape | Close and discard the draft |

Palette, sample, copy and close keys also work in the sample and swatch panes. The code is read-only,
but normal navigation and Visual selection work. Press Escape once to leave Visual mode and again
to close the preview. Opening the command again focuses its existing tab rather than creating
another session. Accurate previewing requires `termguicolors`, plus at least 80 columns and 22 rows.

The preview starts from resolved role values, including configured global and per-schema role
overrides. It retains configured syntax styles but deliberately bypasses exact highlight-group
overrides so they cannot hide the role you are editing. Surfaces are opaque, even if the editor uses
transparency. A preview color is an experiment, not a contrast approval. Compare changed roles on
selections and diagnostic/diff surfaces before keeping them.

## Keep an edit

Press `y` to copy only edited roles to the unnamed register. Merge the copied field into your setup,
including any existing per-schema overrides you want to retain:

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

Exact highlight-group overrides still win in your actual setup. Update those separately if they
hide a role edit.

Copying does not apply the draft to the editor or write a file. The tool never runs compilation,
installation or synchronization. Editor-local overrides do not change canonical generated extras.
To make a color canonical, edit the existing palette owner and follow the
[regeneration and validation procedure](DEVELOPMENT.md#regenerate-palette-artifacts).

## What the samples establish

The packaged Lua, Rust, Python, TypeScript, TSX, Zig and Go samples are self-contained reading
fixtures based on ordinary queueing, request, inventory and UI work. They are not loaded from private
repositories and are not an API tutorial or runnable application.

The tool uses actual installed Tree-sitter parsers and highlight queries. When those are unavailable,
it shows explicitly labelled plain text. It does not source Vim syntax files, which can define global
highlights even when autocommands are suppressed. The statusline and role panel identify the active
path. It never installs a parser or hand-colors code to imitate one. FileType hooks are not fired for
the scratch buffers, and the tool does not start language servers.

Cursor-line and Visual selection are native editor states. The example errors and warnings are
explicit sample diagnostics, not language-server findings. The lower pane shows the real Visual,
completion, search, diff and diagnostic highlight groups as labelled swatches. Those swatches are
not live completion menus or a running diff engine, and do not qualify an external integration.
[Native preview checks](TESTING.md#native-tweak-preview) separately observe real parser-colored cells
and live edits across all four palettes.

Changing the global colorscheme, reloading Flume or deleting a preview buffer closes the preview.
Late color-picker callbacks cannot edit a later session. Only the tool's scratch buffers are
removed. If its invoking tab has been closed, the surviving window is returned to normal highlights
and the invoking window's options before showing your work. Your other buffers, including modified
work, remain untouched.

Integration-only roles, such as file-icon inks, appear as color swatches. The preview does not
simulate each external application's custom mapping.
