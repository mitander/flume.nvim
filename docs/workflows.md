# Shared workflows

Use these examples to follow Flume palettes without putting machine-specific paths or UI layouts into the plugin.

## Remember the synchronized palette

Treat the configured schema as a fallback, not mutable state:

```lua
require("flume").setup({
    schema = "mesa",
    follow_sync = true,
})
```

On startup, `follow_sync` reads the validated schema from `extras/current/schema`.
Missing or invalid state uses the configured fallback. Setup does not write either file.

`:FlumeSync mira` activates the Mira integration set and applies Mira in the editor.
The next startup follows Mira. Your Lua configuration still says `schema = "mesa"`.
`:FlumeReload` preserves the current editor palette, even when another palette is active globally.

`follow_sync` controls startup selection. `watch_sync` controls changes while the editor runs.
Both options must be false for an editor that remains independent of shared palette choices.
The defaults are `follow_sync = false` and `watch_sync = true`.

The active state belongs to the plugin checkout. Editors sharing that checkout share the choice.
Deleting or replacing the checkout can remove that state; the configured fallback then applies.
`:colorscheme flume-mesa` changes only the editor, not the remembered integration choice.
`require("flume").get_active_schema()` returns the canonical active schema, or `nil`.

## Develop the colorscheme

Enable reload-on-save in your local development configuration:

```lua
require("flume").setup({ schema = "mesa", follow_sync = true, dev = true })
```

Saving Lua files under this checkout's `lua/` directory reloads Flume's source modules.
Nested language modules and the lualine theme are included. Symlinked checkout paths work too.
Reload preserves the current schema, overrides, and options. It emits `ColorScheme` without activating external integrations.
A failed reload restores the previous modules and theme; fixing and saving the source retries the reload.
The hook does not replace a different active colorscheme. Set `dev = false` to remove it.

Run `./scripts/check` before submitting changes.
To test the native lualine integration with an installed checkout:

```sh
FLUME_LUALINE_RUNTIME=/path/to/lualine.nvim nvim --headless --clean -c "lua dofile('tests/lualine.lua')"
```

## Lualine

Flume supplies a named theme, not a statusline layout:

```lua
require("lualine").setup({
    options = { theme = "flume" },
    -- Keep your own sections and component options here.
})
```

Lualine reloads named themes on `ColorScheme`. No additional callback is needed.
A precomputed theme table or component color table can retain old colors.
Use component color functions when colors must follow palette changes.

## External tools

Run `:FlumeSync` once to create `extras/current` before using these examples.
Replace `/absolute/path/to/flume.nvim` with your checkout or plugin-manager installation path.
Flume does not modify shell startup files, Git configuration, or application state.

### fzf

fzf supports `FZF_DEFAULT_OPTS_FILE` and reads the file for each invocation.
Use this instead of copying theme options into `FZF_DEFAULT_OPTS` at shell startup.
Keep unrelated options in `FZF_DEFAULT_OPTS`.

Fish:

```fish
set -gx FZF_DEFAULT_OPTS_FILE /absolute/path/to/flume.nvim/extras/current/fzf.opts
```

Bash or Zsh:

```sh
export FZF_DEFAULT_OPTS_FILE=/absolute/path/to/flume.nvim/extras/current/fzf.opts
```

This follows future synchronizations for new fzf invocations, including shell integrations.
An already running fzf instance does not reload. If your fzf lacks this option, upgrade it or load the file in a wrapper per invocation.

### Lazygit

Layer the active Flume file after your personal configuration:

```sh
lazygit --use-config-file "$HOME/.config/lazygit/config.yml,/absolute/path/to/flume.nvim/extras/current/lazygit.yml"
```

Use your actual config location; `lazygit --print-config-dir` reports the default directory.
Keep keybindings and non-theme options in the personal file.
New invocations read the active set; this example does not reload an already running Lazygit instance.

### Delta

Include the active generated configuration after your personal Delta options:

```gitconfig
[include]
    path = /absolute/path/to/flume.nvim/extras/current/delta.gitconfig
```

Remove duplicated fixed Flume colors and any later `light` or theme settings that override the include.
New Delta invocations then use the synchronized palette and its correct light/dark mode.
