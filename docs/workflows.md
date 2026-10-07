# External-tool recipes

Use these includes when you want external tools to follow `:FlumeSync`.
The [help reference](../doc/flume.txt) lists installation destinations, active
filenames, shared-data options, and reload behavior. For a fixed palette instead,
use the palette-suffixed files in [`extras/`](../extras).

## Lualine

Lualine setup and palette changes are covered by `:help flume-lualine`
([online](../doc/flume.txt)).

## External tools

Run `:FlumeSync` once to create the active set before using these examples.
Print `require("flume").get_sync_dir()` in Neovim and replace `/absolute/path/to/flume-data`
with that directory. Select or include the active file in each application.
Keep these includes in your own shell and application configuration. Merge the
examples into existing settings rather than replacing your whole configuration.

For the five installable tools below, run the named `:FlumeInstallExtras` command
in Neovim first. It refuses regular files and directories but replaces symlinks;
check the destination if you already manage a theme there.

### Ghostty

Run `:FlumeInstallExtras ghostty`, then add this to your Ghostty config:

```ini
theme = flume
```

Reload Ghostty's configuration to see the theme. On macOS, future `:FlumeSync`
calls ask running Ghostty windows to reload. On other platforms, reload manually.
See [Ghostty's theme configuration](https://ghostty.org/docs/config/reference#theme).

### Kitty

Run `:FlumeInstallExtras kitty`, then add this after other color settings in
`~/.config/kitty/kitty.conf`:

```conf
include themes/flume.conf
```

Reload with Kitty's default `Ctrl+Shift+F5` shortcut after changing the shared
palette, or open a new Kitty instance. Flume does not request a Kitty reload.
See [Kitty's configuration guide](https://sw.kovidgoyal.net/kitty/conf/).

### Tmux

Run `:FlumeInstallExtras tmux`, then source the variables before your status and
window styles in `~/.tmux.conf`:

```tmux
source-file ~/.tmux/flume-theme.conf
```

The file supplies colors, not a statusline layout. Use those variables in your
existing styles. Tmux's `#{...}` formats read the colors when rendering; for example:

```tmux
set -g status-style "bg=#{thm_bg},fg=#{thm_fg}"
```

Run `tmux source-file ~/.tmux.conf` to apply your configuration. Future
`:FlumeSync` calls source that file when Neovim is running inside Tmux.
See the [Tmux manual](https://man.openbsd.org/tmux#source-file).

### LSD

With LSD 1.2+, run `:FlumeInstallExtras lsd`, then select custom colors in
`~/.config/lsd/config.yaml`:

```yaml
color:
  when: auto
  theme: custom
```

LSD reads `colors.yaml` from its configuration directory. If your LSD configuration lives under
`XDG_CONFIG_HOME`, link `<data-dir>/current/lsd.yaml` into that directory's
`lsd/colors.yaml`. LSD 1.2 searches `~/.config/lsd` first, so an existing
`colors.yaml` there takes precedence over the XDG location.
Older LSD versions can use `theme: ~/.config/lsd/colors.yaml`; LSD 1.2 warns
that this path-based setting is deprecated.

Run `lsd -l` to see metadata colors. New invocations read the shared palette;
file-name colors still follow `LS_COLORS`. Classic mode disables color.
See [LSD's configuration guide](https://github.com/lsd-rs/lsd#customizing-lsd-configuration-and-theming).

### OpenCode

Run `:FlumeInstallExtras opencode`, then use `/theme` in OpenCode to select
`flume`. To set it in configuration, merge this into `~/.config/opencode/tui.json`:

```json
{
  "$schema": "https://opencode.ai/tui.json",
  "theme": "flume"
}
```

Restart OpenCode after changing the shared palette if it still shows the old
colors. Flume does not request an OpenCode reload. These instructions follow the
[current OpenCode theme guide](https://opencode.ai/docs/themes/); older versions
may keep the theme setting in `opencode.json` instead.

### fzf

fzf supports `FZF_DEFAULT_OPTS_FILE` and reads the file for each invocation.
Use this instead of copying theme options into `FZF_DEFAULT_OPTS` at shell startup.
Keep unrelated options in `FZF_DEFAULT_OPTS`.

Fish:

```fish
set -gx FZF_DEFAULT_OPTS_FILE /absolute/path/to/flume-data/current/fzf.opts
```

Bash or Zsh:

```sh
export FZF_DEFAULT_OPTS_FILE=/absolute/path/to/flume-data/current/fzf.opts
```

This follows future synchronizations for new fzf invocations, including shell integrations.
An already running fzf instance does not reload. If your fzf lacks this option, upgrade it or load the file in a wrapper per invocation.

### Lazygit

Layer the active Flume file after your personal configuration:

```sh
lazygit --use-config-file "$HOME/.config/lazygit/config.yml,/absolute/path/to/flume-data/current/lazygit.yml"
```

Use your actual config location; `lazygit --print-config-dir` reports the default directory.
Keep keybindings and non-theme options in the personal file.
New invocations read the active set; this example does not reload an already running Lazygit instance.

### Delta

Include the active generated configuration after your personal Delta options:

```gitconfig
[include]
    path = /absolute/path/to/flume-data/current/delta.gitconfig
```

Remove duplicated fixed Flume colors and any later `light` or theme settings that override the include.
New Delta invocations then use the synchronized palette and its correct light/dark mode.
