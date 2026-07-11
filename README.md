<div align="center">
  <h1>FLUME</h1>
  <p><strong>Organic synthesis. Soft contrast. Resonant code.</strong></p>
  <p>A moody nvim theme tuned for quiet focus and warm spectral edges.</p>
</div>

<div align="center">
  <img src="assets/palette.svg" alt="Flume palette swatches" width="600">
</div>

<div align="center">
  <img src="screenshot.png" alt="Flume Theme Screenshot" width="1200">
  <p><sub>Screenshot uses <a href="https://www.jetbrains.com/lp/mono/">JetBrains Mono</a>.</sub></p>
</div>

## Features

- One intentional dark palette: one current, one source of truth.
- Tree-sitter, LSP semantic tokens, diagnostics, common plugin highlights, and terminal ANSI colors.
- Palette overrides, highlight overrides, transparent mode, optional terminal colors, and simple style hooks.
- Generated extras for Ghostty, Tmux, LSD, Pi, and Tuxedo.
- Reload/compile commands for theme work without leaving Neovim.

## Install

Requires Neovim 0.9+.

Using `lazy.nvim`:

```lua
{
    "mitander/flume.nvim",
    lazy = false,
    priority = 1000,
    opts = {},
    config = function(_, opts)
        require("flume").setup(opts)
        vim.cmd.colorscheme("flume")
    end,
}
```

Local development:

```lua
{
    "mitander/flume.nvim",
    dir = "~/path/to/flume.nvim",
    lazy = false,
    priority = 1000,
    opts = {},
    config = function(_, opts)
        require("flume").setup(opts)
        vim.cmd.colorscheme("flume")
    end,
}
```

## Configure

Defaults:

```lua
require("flume").setup({
    transparent = false,
    terminal_colors = true,
    overrides = {},
    highlights = {},
    styles = {
        comments = {},
        functions = {},
        keywords = {},
        strings = {},
        types = {},
        variables = {},
    },
})
```

| Option            | Purpose                                                                 |
| ----------------- | ----------------------------------------------------------------------- |
| `transparent`     | Removes editor background colors.                                       |
| `terminal_colors` | Sets `vim.g.terminal_color_0` through `15`.                             |
| `overrides`       | Overrides palette keys from `lua/flume/palette.lua`.                    |
| `highlights`      | Overrides highlight groups; values may be tables or `function(colors)`. |
| `styles`          | Adds style attrs to broad syntax roles, e.g. `{ italic = true }`.       |

Example:

```lua
require("flume").setup({
    transparent = true,
    styles = {
        comments = { italic = true },
        keywords = { bold = true },
    },
    overrides = {
        accent = "#73a6b6",
        syntax_namespace = "#f48a94", -- @module and legacy @namespace
    },
    highlights = {
        FloatBorder = function(c)
            return { fg = c.accent, bg = c.bg }
        end,
    },
})
```

Semantic palette keys include `syntax_attribute`, `syntax_boolean`,
`syntax_comment`, `syntax_doc_comment`, `syntax_constant`, `syntax_function`,
`syntax_type`, `syntax_keyword`, `syntax_namespace`, `syntax_primary`,
`syntax_property`, `syntax_punctuation`, `syntax_punctuation_bracket`,
`syntax_punctuation_special`, `syntax_string`, and `syntax_special`. More
specific Tree-sitter captures inherit these roles; `highlights` remains
available when you want to override an individual capture directly.

## Integrations

| Surface                               | Status           |
| ------------------------------------- | ---------------- |
| Neovim UI, diagnostics, terminal ANSI | Built in         |
| Tree-sitter captures                  | Built in         |
| LSP semantic tokens                   | Built in         |
| GitSigns, Oil                         | Built in         |
| Telescope, cmp, lazy.nvim, WhichKey   | Built in         |
| Mason, Trouble, Neo-tree, nvim-tree   | Built in         |
| Snacks picker                         | Built in         |
| Ghostty, Tmux, LSD, Pi, Tuxedo        | Generated extras |

## Commands

| Command                                    | Does                                                                        |
| ------------------------------------------ | --------------------------------------------------------------------------- |
| `:FlumeReload`                             | Recompile extras, reload the theme, and refresh Ghostty/Tmux when possible. |
| `:FlumeCompile`                            | Regenerate files in `extras/`.                                              |
| `:FlumeInstallExtras [ghostty\|tmux\|lsd]` | Symlink supported extras into standard config paths.                        |
| `:FlumeExtras`                             | Open copy-paste install commands for extras.                                |
| `:checkhealth flume`                       | Check terminal color support and generated extra files.                     |
| `:help flume`                              | Open the reference docs.                                                    |

## Extras

Generated files live in `extras/` and are checked in:

```text
extras/ghostty/flume
extras/tmux/colors.conf
extras/lsd/colors.yaml
extras/pi/flume.json
extras/tuxedo/flume.toml
```

Install supported extras from Neovim:

```vim
:FlumeInstallExtras
:FlumeInstallExtras ghostty
```

## Hacking

Palette source:

```text
lua/flume/palette.lua
```

Compile everything:

```sh
nvim --headless --cmd "set rtp+=." -c "lua require('flume.compiler').compile_all()" -c "qa"
```

Refresh the header screenshot:

```sh
./scripts/screenshot-window.sh
```

## License

MIT. See [LICENSE](LICENSE).
