<div align="center">
  <img src="assets/flume.svg" alt="Flume" width="360">
  <p><strong>Organic synthesis. Soft contrast. Resonant code.</strong></p>
</div>

[![Opal, Mesa, Mira, and Dusk in a cascading palette showcase](assets/screenshots/showcase.png)](docs/showcase.md)

Flume is a Neovim colorscheme with four palettes and matching terminal and
developer-tool themes. Neutral identifiers, semantic color, and soft surfaces
keep the focus on code. Includes Tree-sitter, LSP semantic tokens, diagnostics,
and popular plugin highlights.

| Palette                         | Appearance | Character                           |
| ------------------------------- | ---------- | ----------------------------------- |
| [**Dusk**](assets/screenshots/dusk/zig.png) | Dark       | Quiet violet                        |
| [**Opal**](assets/screenshots/opal/zig.png) | Light      | Vivid inks on cool opalescent paper |
| [**Mira**](assets/screenshots/mira/zig.png) | Dark       | Plum with cyan, teal, and magenta   |
| [**Mesa**](assets/screenshots/mesa/zig.png) | Light      | Warm rose-mineral paper             |

## Language gallery

Rust, TypeScript/TSX, Python, and Go, shown with real Tree-sitter highlighting.
Each palette uses the same source and layout. Click a grid for full resolution.

### Dusk

[![Dusk: Rust, TypeScript/TSX, Python, and Go](assets/screenshots/dusk/languages.png)](assets/screenshots/dusk/languages.png)

### Opal

[![Opal: Rust, TypeScript/TSX, Python, and Go](assets/screenshots/opal/languages.png)](assets/screenshots/opal/languages.png)

### Mira

[![Mira: Rust, TypeScript/TSX, Python, and Go](assets/screenshots/mira/languages.png)](assets/screenshots/mira/languages.png)

### Mesa

[![Mesa: Rust, TypeScript/TSX, Python, and Go](assets/screenshots/mesa/languages.png)](assets/screenshots/mesa/languages.png)

## Install

Requires Neovim 0.9+ and true-color support. With lazy.nvim:

```lua
{
    "mitander/flume.nvim",
    lazy = false,
    priority = 1000,
    config = function()
        vim.opt.termguicolors = true
        require("flume").setup({ schema = "dusk" })
    end,
}
```

`setup()` configures and applies Flume. Do not follow it with `:colorscheme`.
Without Lua options, use `colorscheme flume-dusk` instead. The other entry points
are `flume-opal`, `flume-mira`, and `flume-mesa`.

## Configure

Override palette roles, syntax styles, or exact highlight groups:

```lua
require("flume").setup({
    schema = "opal",
    transparent = false,
    overrides = {
        syntax_comment = "#7a747a",
        accent = "#5f9cab",
    },
    styles = { comments = { italic = true } },
    highlights = {
        CursorLineNr = { fg = "#ffffff", bold = true },
    },
})
```

Use `:Inspect` or `:highlight GroupName` to identify a highlight group.
Overrides affect Neovim only; generated themes use canonical palette colors.
See [`:help flume-options`](doc/flume.txt) for all defaults and system-appearance
hooks. Exact roles are listed in the [palette manifest](docs/palette-manifest.md).

## Integrations

Matching themes live in [`extras/`](extras):

- [Ghostty](extras/ghostty/)
- [Kitty](extras/kitty/)
- [Tmux](extras/tmux/)
- [LSD](extras/lsd/)
- [OpenCode](extras/opencode/)
- [Lazygit](extras/lazygit/)
- [fzf](extras/fzf/)
- [Delta](extras/delta/)
- [Pi](extras/pi/)

**Automatic installation:** Ghostty, Kitty, OpenCode, Tmux, and LSD.

```vim
:FlumeInstallExtras
```

**Manual setup:** use the other tools' theme or include mechanisms. Flume does
not guess user-specific destinations. See [`:help flume-extras`](doc/flume.txt)
for artifact paths.

Switch Neovim and the active integration set together:

```vim
:FlumeSync mira
```

Other running Neovim instances follow by default. To remember the synchronized
palette at startup, keep a fallback in your dotfiles:

```lua
require("flume").setup({ schema = "mesa", follow_sync = true })
```

`:FlumeSync mira` records Mira in runtime state, not your Lua configuration.
Set both `follow_sync = false` and `watch_sync = false` for an independent editor.
Active sets live in `stdpath("data")/flume`, outside the plugin checkout. Print
`require("flume").get_sync_dir()` for your exact path. After upgrading, rerun
`:FlumeInstallExtras` and update manual includes; legacy checkout links are forwarded
when possible. External tools need their own reload support. See
[shared workflows](docs/workflows.md) for setup and reload behavior, and the
[semantic export](docs/semantic-export.md) for custom consumers.

## Commands

| Command                     | Action                                                     |
| --------------------------- | ---------------------------------------------------------- |
| `:FlumeReload`              | Reload the editor-local palette                            |
| `:FlumeCompile`             | Regenerate all integration artifacts                       |
| `:FlumeSync [schema]`       | Apply a palette and activate its integration set           |
| `:FlumeInstallExtras [app]` | Link integrations with standard destinations               |
| `:FlumeExtras`              | Show safe link instructions for the five installable tools |
| `:checkhealth flume`        | Check the selected palette and generated files             |
| `:help flume`               | Open the reference manual                                  |

## Development

Set `dev = true` in your local Flume setup to reload on Lua source saves.
Reloads preserve the editor's current palette and do not synchronize external tools.

Run `./scripts/check` for tests, local links, and source checks.

- [Color system](docs/color-system.md): roles, contrast targets, and mapping rules.
- [Integration review](docs/integration-review.md): visual previews, contrast measurements, and before/after reports.
- [Showcase production](docs/showcase.md): captures and native integration evidence.
- [Changelog](CHANGELOG.md): release history.

Flume's visual direction draws on [Jonathan Zawada's artwork for
Flume](https://zawada.art/work/flume-skin/). A [wallpaper](assets/background.png) is
available at 1376×768.

## License

MIT. See [LICENSE](LICENSE).
