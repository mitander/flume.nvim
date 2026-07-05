<div align="center">
  <!-- <h1>flume.nvim</h1> -->
  <p>
    <strong>Organic synthesis. Soft contrast. Resonant code.</strong><br>
    Inspired by One Dark, Duskfox and Kanagawa.
  </p>
</div>

<br>

<div align="center">
  <img src="screenshot.png" alt="Flume Theme Screenshot" width="1200">
  <p><sub>Screenshot uses the <a href="https://www.jetbrains.com/lp/mono/">JetBrains Mono</a> font.</sub></p>
</div>

## Install

### nvim

#### Install from GitHub

Using `lazy.nvim`:

```lua
{
    "mitander/flume.nvim",
    lazy = false,
    priority = 1000,
    opts = {
        transparent = false, -- Set to true to disable background colors
        overrides = {},      -- Map highlight groups or colors to override
    },
    config = function(_, opts)
        require("flume").setup(opts)
        vim.cmd.colorscheme("flume")
    end,
}
```

#### Local clone

```lua
{
    "mitander/flume.nvim",
    dir = "~/path/to/flume.nvim",
    lazy = false,
    priority = 1000,
    opts = {
        transparent = false,
    },
    config = function(_, opts)
        require("flume").setup(opts)
        vim.cmd.colorscheme("flume")
    end,
}
```

### Hacking on the theme

If you are modifying colors or configurations:

1. Edit colors in `lua/flume/palette.lua` (the palette is the source of truth).
2. Reload theme with `:FlumeReload`. This recompiles generated extras, reloads nvim, reloads Ghostty with its macOS `Cmd+Shift+,` action when the generated Ghostty theme changed, and sources Tmux config when the generated Tmux theme changed. If you use a mapping like `<leader>rl`, map it to the command or public API:

```lua
vim.keymap.set("n", "<leader>rl", "<cmd>FlumeReload<cr>")
-- or: vim.keymap.set("n", "<leader>rl", require("flume").reload)
```

3. Compile the theme for other applications without reloading anything with `:FlumeCompile`, or from a shell:

```sh
nvim --headless --cmd "set rtp+=." -c "lua require('flume.compiler').compile_all()" -c "qa"
```

4. Launch the Ghostty screenshot environment: `./scripts/screenshot-window.sh`.

## Extras

Flume includes theme configurations for other applications (such as Ghostty, Tmux, and LSD) under the `extras/` directory. Since these are pre-compiled and checked into the repository, you do not need to compile them unless you are customizing the color palette.

### Setup using nvim commands

You can automatically symlink the extras to their standard locations from within nvim. Existing regular files are never overwritten; move them aside first if you want Flume to manage that path.

To symlink **all** extras:

```vim
:FlumeInstallExtras
```

To symlink a **specific** extra:

```vim
:FlumeInstallExtras ghostty
:FlumeInstallExtras tmux
:FlumeInstallExtras lsd
```

To view the exact, expanded terminal commands tailored to your machine's installation path:

```vim
:FlumeExtras
```

### Manual setup (terminal)

If you prefer to configure manually, you can run the following terminal commands. Replace `<flume_dir>` with the path where the plugin is installed (typically `~/.local/share/nvim/lazy/flume.nvim` on macOS/Linux if using `lazy.nvim`).

#### Ghostty

Symlink the theme into Ghostty's theme directory:

```bash
mkdir -p ~/.config/ghostty/themes
ln -sf <flume_dir>/extras/ghostty/flume ~/.config/ghostty/themes/flume
```

Then enable it in `~/.config/ghostty/config`:

```ini
theme = flume
```

#### Tmux

Symlink the tmux theme variables into your tmux config directory:

```bash
mkdir -p ~/.tmux
ln -sf <flume_dir>/extras/tmux/colors.conf ~/.tmux/flume-theme.conf
```

Then source it in your `~/.tmux.conf`:

```tmux
source-file "~/.tmux/flume-theme.conf"
```

#### LSD

Symlink the lsd theme variables:

```bash
mkdir -p ~/.config/lsd
ln -sf <flume_dir>/extras/lsd/colors.yaml ~/.config/lsd/colors.yaml
```

## License

Licensed under the MIT License. See [LICENSE](LICENSE) for details.
