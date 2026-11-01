# External-tool recipes

Use these includes when you want external tools to follow `:FlumeSync`. The
[help reference](../doc/flume.txt) lists installation destinations, active filenames, shared-data
options, and reload behavior. For a fixed palette instead, use the palette-suffixed files in
[`extras/`](../extras).

## Lualine

Lualine setup and palette changes are covered by `:help flume-lualine` ([online](../doc/flume.txt)).

## External tools

Run `:FlumeSync` once to create the active set before using these examples. Print
`require("flume").get_sync_dir()` in Neovim and replace `/absolute/path/to/flume-data` with that
directory. Select or include the active file in each application. Keep these includes in your own
shell and application configuration. Merge the examples into existing settings rather than replacing
your whole configuration.

For the installable tools below, run the named `:FlumeInstallExtras` command in Neovim first. It
refuses regular files and directories but replaces symlinks; check the destination if you already
manage a theme there.

### Ghostty

Run `:FlumeInstallExtras ghostty`, then add this to your Ghostty config:

```ini
theme = flume
```

Reload Ghostty's configuration to see the theme. Future `:FlumeSync` calls request reloads through
AppleScript on macOS, or `SIGUSR2` on Linux when `pkill` is available. Reload manually if that
request is unavailable or the running application does not apply it. See
[Ghostty's theme configuration](https://ghostty.org/docs/config/reference#theme).

### Kitty

Run `:FlumeInstallExtras kitty`, then add this after other color settings in
`~/.config/kitty/kitty.conf`:

```conf
include themes/flume.conf
```

Reload with Kitty's default `Ctrl+Shift+F5` shortcut after changing the shared palette, or open a
new Kitty instance. Flume does not request a Kitty reload. See
[Kitty's configuration guide](https://sw.kovidgoyal.net/kitty/conf/).

### Tmux

Run `:FlumeInstallExtras tmux`, then source the variables before your status and window styles in
`~/.tmux.conf`:

```tmux
source-file ~/.tmux/flume-theme.conf
```

The file supplies colors, not a statusline layout. Use those variables in your existing styles.
Tmux's `#{...}` formats read the colors when rendering; for example:

```tmux
set -g status-style "bg=#{thm_bg},fg=#{thm_fg}"
set -g window-status-style "bg=#{thm_bg},fg=#{thm_muted}"
set -g window-status-current-style "bg=#{thm_accent},fg=#{thm_on_accent},bold"
set -g message-style "bg=#{thm_surface},fg=#{thm_fg}"
set -g message-command-style "bg=#{thm_surface},fg=#{thm_accent}"
```

`message-command-style` applies to the vi command-mode prompt, not prompt insertion mode.
`thm_surface` is a raised UI background, `thm_muted` is readable secondary text, and
`thm_on_accent` is text on a filled accent or state color. The existing variables keep their
meanings. In particular, `thm_black` and `thm_gray` are ANSI black, not UI surfaces, and
`thm_lgray` is decorative placeholder ink, not inactive-label text.

Run `tmux source-file ~/.tmux.conf` to apply your configuration. Future `:FlumeSync` calls source
that file when Neovim is running inside Tmux. See the
[Tmux manual](https://man.openbsd.org/tmux#source-file).

### LSD

With LSD 1.2+, run `:FlumeInstallExtras lsd`, then select custom colors in
`~/.config/lsd/config.yaml`:

```yaml
color:
  when: auto
  theme: custom
```

LSD reads `colors.yaml` from its configuration directory. If your LSD configuration lives under
`XDG_CONFIG_HOME`, link `<data-dir>/current/lsd.yaml` into that directory's `lsd/colors.yaml`. LSD
1.2 searches `~/.config/lsd` first, so an existing `colors.yaml` there takes precedence over the XDG
location. Older LSD versions can use `theme: ~/.config/lsd/colors.yaml`; LSD 1.2 warns that this
path-based setting is deprecated.

Run `lsd -l` to see metadata colors. New invocations read the shared palette; file-name colors still
follow `LS_COLORS`. Classic mode disables color. See
[LSD's configuration guide](https://github.com/lsd-rs/lsd#customizing-lsd-configuration-and-theming).

For readable world-writable directory names (`drwxrwxrwx`), `:FlumeExtras` prints Fish and Bash/Zsh
commands that append `ow=0;35` to `LS_COLORS`. Add the appropriate command after existing
`LS_COLORS` setup in your shell configuration. It uses ANSI magenta on the normal background (pink
with Flume's terminal palette) and preserves other entries, including sticky-directory colors. This
targets non-sticky world-writable directories, not directories such as `/tmp` with the sticky bit
set. GNU `ls` also reads `LS_COLORS`, but macOS's built-in BSD `ls` does not. The YAML theme alone
cannot change filename colors.

### OpenCode

Run `:FlumeInstallExtras opencode`, then use `/theme` in OpenCode to select `flume`. To set it in
configuration, merge this into `~/.config/opencode/tui.json`:

```json
{
  "$schema": "https://opencode.ai/tui.json",
  "theme": "flume"
}
```

Restart OpenCode after changing the shared palette if it still shows the old colors. Flume does not
request an OpenCode reload. These instructions follow the
[current OpenCode theme guide](https://opencode.ai/docs/themes/); older versions may keep the theme
setting in `opencode.json` instead.

### Fish

Run `:FlumeInstallExtras fish` to choose how to load Fish colors:

- **Yes** links the active fragment into `~/.config/fish/conf.d/flume.fish`, or
  `$XDG_CONFIG_HOME/fish/conf.d/flume.fish` when set. New Fish shells load it automatically.
- **No** leaves your files alone and prints the manual snippet below with your actual active path.
  Canceling makes no changes.

The installer never edits `config.fish`. It refuses existing regular files and directories, but may
replace an existing symlink after confirmation. Fish loads `conf.d` before `config.fish`, so later
color settings can override Flume. If that happens, source the active fragment after those settings
in your Fish `config.fish` instead:

```fish
if status is-interactive
    source /absolute/path/to/flume-data/current/fish.fish
end
```

To try a fixed palette from a checkout instead:

```fish
source /absolute/path/to/flume.nvim/extras/fish/flume-mira.fish
```

Type `cargo ` and press Tab to see the completion pager. Completions use neutral text, descriptions
use muted text, and prefixes are underlined in the match color. The selected row uses Flume's
selection foreground and background, including its description. Alternate rows use the same colors
as ordinary rows so a previous Fish theme cannot leave stripes behind.

The fragment also colors command-line syntax, autosuggestions, history matches, and visual
selections. It sets session-global variables, not persistent universal variables, and does not
replace your prompt or key bindings. Existing shells need to source the active file again after
`:FlumeSync`. New shells read it at startup. There is no automatic Fish reload. See
[Fish's pager color variables](https://fishshell.com/docs/current/interactive.html#pager-color-variables).

### Fish tool setup

Fish 3.5+ users can replace manual fzf, Lazygit and filename-color plumbing with an optional setup
fragment:

```vim
:FlumeInstallExtras fish_tools
```

Choose **Install** to link `conf.d/flume-tools.fish`. **Do not install** or cancel leaves files
unchanged. Installation does not change an existing shell.

The installer then prints two quoted `source` commands. Run one in Fish:

- The first preserves configured tools' exports and supplies Flume defaults for unset tools.
- The second adds `--adopt` to replace the current session's fzf/Lazygit exports instead.

Both commands apply the filename-color rule described below. Neovim cannot change the parent
shell's environment. There is no need to clear variables or restart Fish.

This is separate from `:FlumeInstallExtras fish`, which only installs command-line syntax and pager
colors. Neither command edits `config.fish`. Normal startup respects explicit tool exports.
`--adopt` is a one-time source argument, not a persistent preference, and it does not modify Fish's
persistent universal variables. Reinstalling a stale tool fragment refreshes the complete
shared set without changing its selected palette.

The tool fragment keeps fzf on the stable shared `current/fzf.opts` path. It asks installed Lazygit
for its config directory and layers its personal `config.yml`, when present, before
`current/lazygit.yml`. This follows Lazygit's native macOS, XDG and custom-directory rules without a
second path resolver. If Lazygit is absent, its setup waits until a shell starts with it installed.
Without `--adopt`, existing `FZF_DEFAULT_OPTS_FILE` and `LG_CONFIG_FILE` variables take precedence,
including inherited and universal choices. Lazygit reads `LG_CONFIG_FILE` natively, so no shell
function or command wrapper is needed.

It also replaces the `ow` rule in `LS_COLORS` with `ow=0;35`, preserving other rules and remaining
unchanged when sourced repeatedly. This affects GNU `ls` and LSD, not macOS's built-in BSD `ls`.
Later personal configuration can override any of this setup. Existing running applications are not
reloaded. The manual recipes below remain available for other shells or custom arrangements.

### fzf

fzf supports `FZF_DEFAULT_OPTS_FILE` and reads the file for each invocation. Use this instead of
copying theme options into `FZF_DEFAULT_OPTS` at shell startup. Keep unrelated options in
`FZF_DEFAULT_OPTS`.

Fish:

```fish
set -gx FZF_DEFAULT_OPTS_FILE /absolute/path/to/flume-data/current/fzf.opts
```

Bash or Zsh:

```sh
export FZF_DEFAULT_OPTS_FILE=/absolute/path/to/flume-data/current/fzf.opts
```

This follows future synchronizations for new fzf invocations, including shell integrations. An
already running fzf instance does not reload. If your fzf lacks this option, upgrade it or load the
file in a wrapper per invocation.

### Lazygit

Install the active fragment with `:FlumeInstallExtras lazygit`. It creates:

```text
~/.config/lazygit/flume.yml
```

Set `LG_CONFIG_FILE` after your personal configuration:

```sh
export LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml,$HOME/.config/lazygit/flume.yml"
```

Use your actual config location; `lazygit --print-config-dir` reports the default directory. Keep
keybindings and non-theme options in the personal file. New invocations read the active symlink, so
future `:FlumeSync` calls update the theme without rewriting your configuration. An already running
Lazygit instance does not reload.

### Delta

Include the active generated configuration after your personal Delta options:

```gitconfig
[include]
    path = /absolute/path/to/flume-data/current/delta.gitconfig
```

Remove duplicated fixed Flume colors and any later `light` or theme settings that override the
include. New Delta invocations then use the synchronized palette and its correct light/dark mode.
