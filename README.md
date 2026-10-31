<p align="center">
  <img src="assets/flume.svg" alt="Flume" width="260">
  <br><br>
</p>

Flume is a Neovim colorscheme inspired by
[Jonathan Zawada's artwork for Flume](https://zawada.art/work/flume-skin/). It offers two dark and
two light palettes, with matching themes for your terminal and developer tools.

Ordinary identifiers stay neutral. Color distinguishes functions, types, selections, and diagnostics
against soft backgrounds.

![Opal, Mesa, Mira, and Dusk in a cascading palette showcase](assets/screenshots/showcase.png)

[Compare palettes and browse language examples](docs/gallery.md).

> [!WARNING]
> Flume’s palettes are still evolving. Updates may change colors, including backgrounds. Significant
> visual changes are noted in the changelog. Pin the plugin to a release tag or commit if you want a
> fixed appearance.

## Install

Requires Neovim 0.9+ and a true-color terminal. Add this to your
[lazy.nvim](https://github.com/folke/lazy.nvim) configuration:

```lua
{
    "mitander/flume.nvim",
    lazy = false,
    priority = 1000,
    config = function()
        vim.opt.termguicolors = true
        require("flume").setup({
            schema = "dusk",
        })
    end,
}
```

Install the plugin and restart Neovim to load Dusk. Run `:echo g:colors_name` to confirm
`flume-dusk`. The `setup()` call applies the theme; you don't need an extra `:colorscheme` call.

With another plugin manager, install `mitander/flume.nvim`, then add the contents of the `config`
function above to your `init.lua` after the plugin loads.

Flume includes Tree-sitter, LSP, and plugin highlights. You'll need to install parsers and language
servers separately if you use them.

## Usage

Try another palette in the current editor:

```vim
:colorscheme flume-opal
```

The colorscheme names are `flume-dusk`, `flume-opal`, `flume-mira`, and `flume-mesa`. Change
`schema` in your setup to use that palette at startup.

## Tweak a palette locally

```vim
:FlumeTweak
```

Compare role colors in isolated preview windows without changing your editor theme or shared
integrations. Use `h`/`l` for darker/lighter candidates, `c` for another palette ink, and Enter for a
hex color. Cycle palettes with `p` and language samples with `s`. Press `y` to copy draft
`schema_overrides`, or `q` to discard the preview. See the [preview guide](docs/tweak.md) for controls,
parser requirements and limits.

## Configuration

For italic comments and a custom current line number, replace your setup call with:

```lua
require("flume").setup({
    schema = "opal",
    styles = {
        comments = { italic = true },
    },
    highlights = {
        CursorLineNr = {
            bold = true,
            fg = "#413b49",
        },
    },
})
```

Run `:set cursorline number` to see the line-number change. For all options, including palette-role
overrides, see `:help flume-options` ([online](doc/flume.txt)).

## Integrations

Follow the [external-tool recipes](docs/workflows.md#external-tools) to install and select a
matching theme.

For **lualine**, set `options = { theme = "flume" }` in your existing setup. The named theme follows
palette changes; see `:help flume-lualine`.

Matching themes are available for **Ghostty, Kitty, Tmux, LSD, OpenCode, Lazygit, Fish, fzf, Delta,
and Pi**. See `:help flume-extras` for supported installation paths and reload behavior.

Once they're configured, switch the editor and shared themes together:

```vim
:FlumeSync mira
```

Other running Flume editors follow the switch by default. External apps may need a reload or a new
invocation.

To remember the shared palette at startup, see `:help flume-follow_sync`. To keep an editor
independent, set both `follow_sync = false` and `watch_sync = false`.

## Troubleshooting

- `:help flume` for the full manual ([online](doc/flume.txt)).
- `:help flume-troubleshooting` to identify unexpected colors or palette switches.
- `:checkhealth flume` to verify your setup and integration files are correct.
- [Palette manifest](docs/palette-manifest.md) for color roles and values for overrides.

<a id="contributing"></a>

## Development

Start with [Contributing](CONTRIBUTING.md) for setup and the edit/check loop.
[Testing](docs/TESTING.md) selects parser, integration and screenshot evidence. Source checks do not
activate shared themes or change live user configuration.

## Documentation

- [Contributing](CONTRIBUTING.md): change workflow, review and user-state safety.
- [Development](docs/DEVELOPMENT.md): prerequisites, local commands and artifact regeneration.
- [Testing](docs/TESTING.md): check selection, native boundaries and hosted CI.
- [Style](STYLE.md): code, fixture and documentation conventions.
- [Design](docs/DESIGN.md): palette resolution, compilation and shared activation.
- [Color system](docs/color-system.md): role meanings, mappings and contrast targets.
- [Semantic export](docs/semantic-export.md): versioned consumer format and migration.
- [Gallery](docs/gallery.md): palette and language comparisons.
- [External-tool recipes](docs/workflows.md): includes, installation and reload behavior.
- [Showcase](docs/showcase.md): capture procedures and evidence limits.
- [Changelog](CHANGELOG.md): releases and significant visual changes.

## License

MIT. See [LICENSE](LICENSE).
