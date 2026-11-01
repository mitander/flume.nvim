# External-tool recipes

Extras are color configuration files for applications outside Neovim. Choose a
[fixed palette](#fixed-palettes) if you want an application to stay on one palette, or use the
shared paths below to follow `:FlumeSync`. Neither is required to use Flume in Neovim.

The [help reference](../doc/flume.txt) lists exact installation destinations, active filenames and
shared-data options.

## External tools

Choose your application below. Installing a link does not select its theme or reload it.

| Application                         | One-time setup                                                         | After `:FlumeSync`                                               |
| ----------------------------------- | ---------------------------------------------------------------------- | ---------------------------------------------------------------- |
| [Ghostty](#ghostty)                 | Install `ghostty`, then set `theme = flume`                            | Reload requested on macOS/Linux, manual reload if needed         |
| [Kitty](#kitty)                     | Install `kitty`, then include `themes/flume.conf`                      | Reload manually or open a new instance                           |
| [Tmux](#tmux)                       | Install `tmux`, source its variables and use them in your styles       | Configuration sourced when Neovim is inside Tmux                 |
| [LSD](#lsd)                         | Install `lsd`, then select `color.theme: custom`                       | New invocations read the theme                                   |
| [OpenCode](#opencode)               | Install `opencode`, then select `flume`                                | Restart if the running UI keeps the old palette                  |
| [Lazygit](#lazygit)                 | Install `lazygit`, then layer it with `LG_CONFIG_FILE`                 | New invocations read the theme                                   |
| [Pi](#pi)                           | Install `pi`, then select `flume`                                      | Theme link refreshed to notify Pi, reselect or restart if needed |
| [Fish colors](#fish)                | Install `fish` with consent, or source the fragment yourself           | Source again in existing shells, new shells load it at startup   |
| [Fish tool setup](#fish-tool-setup) | Install `fish_tools` with consent for fzf, Lazygit and filename colors | New tool invocations follow the shared paths                     |
| [fzf](#fzf)                         | Set `FZF_DEFAULT_OPTS_FILE`                                            | New invocations read the options                                 |
| [Delta](#delta)                     | Include the generated Git configuration                                | New invocations read the theme                                   |

Here, “install `ghostty`” means `:FlumeInstallExtras ghostty`, and likewise for the other named
installers. They refuse regular files and directories but replace symlinks. Check the destination
before installing if you already manage a theme there. fzf and Delta use manual includes instead.

Run `:FlumeSync` once to publish the active set. For recipes that need its absolute path, run:

```vim
:lua print(require("flume").get_sync_dir())
```

Replace `/absolute/path/to/flume-data` below with that directory. Keep includes in your own shell
and application configuration. Merge the examples into existing settings rather than replacing your
whole configuration. Shared themes use the palette's default colors, not editor-local overrides.

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
`thm_surface` is a raised UI background, `thm_muted` is readable secondary text, and `thm_on_accent`
is text on a filled accent or state color. The existing variables keep their meanings. In
particular, `thm_black` and `thm_gray` are ANSI black, not UI surfaces, and `thm_lgray` is
decorative placeholder ink, not inactive-label text.

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

### Pi

Run `:FlumeInstallExtras pi`, then select `flume` in Pi's theme settings. The installer links
`~/.pi/agent/themes/flume.json` to the shared active theme.

After `:FlumeSync`, Flume refreshes that link to notify Pi's theme watcher. If the running UI keeps
the old palette, reselect the theme or restart Pi. The notification does not prove that the UI
applied it.

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

Both commands apply the filename-color rule described below. Neovim cannot change the parent shell's
environment. There is no need to clear variables or restart Fish.

This is separate from `:FlumeInstallExtras fish`, which only installs command-line syntax and pager
colors. Neither command edits `config.fish`. Normal startup respects explicit tool exports.
`--adopt` is a one-time source argument, not a persistent preference, and it does not modify Fish's
persistent universal variables. Reinstalling a stale tool fragment refreshes the complete shared set
without changing its selected palette.

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
`FZF_DEFAULT_OPTS`. FZF reads the options file first, then `FZF_DEFAULT_OPTS`, then command-line
options. Remove copied `--color` settings from the latter two if they override the file's colors.
This route follows the shared `:FlumeSync` choice, not editor-local colorscheme switches.

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

#### fzf inside Neovim

For fzf.vim or Fzfx, configure the FZF Vim plugin's `g:fzf_colors` once in your picker setup:

```lua
vim.g.fzf_colors = {
    fg = { "fg", "Normal" },
    bg = { "bg", "Normal" },
    query = { "fg", "Normal" },
    hl = { "fg", "Search" },
    ["fg+"] = { "fg", "CursorLine", "Normal" },
    ["bg+"] = { "bg", "CursorLine", "Normal" },
    ["hl+"] = { "fg", "Search" },
    info = { "fg", "Comment" },
    header = { "fg", "Comment" },
    border = { "fg", "FloatBorder" },
    gutter = { "bg", "Normal" },
    prompt = { "fg", "Directory" },
    pointer = { "fg", "Special" },
    marker = { "fg", "Statement" },
    spinner = { "fg", "Special" },
}
```

Merge this with any existing `g:fzf_colors` mapping. The plugin resolves the current highlights
when opening a picker, so new pickers follow Flume palette changes, local overrides and switches to
other colorschemes. No `ColorScheme` callback or `:FlumeSync` is needed. Leave layout preferences
such as `--reverse` in `FZF_DEFAULT_OPTS`, but remove copied color settings from your appearance
callbacks and per-picker arguments. Already open pickers do not reload. Highlight colors that the
FZF Vim plugin cannot resolve fall back to FZF defaults.

This recipe follows editor highlights rather than reproducing the canonical external FZF export
exactly. An opaque `Normal` background is recommended for predictable surfaces. fzf-lua is a
separate plugin with its own highlight integration. See the
[FZF Vim color mapping reference](https://github.com/junegunn/fzf/blob/master/README-VIM.md#explanation-of-gfzf_colors).

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

## Fixed palettes

Each application directory in [`extras/`](../extras) contains one file per palette. Use that file
instead of the shared `current/` path when you do not want the application to follow `:FlumeSync`.
For example, Kitty can use Opal directly:

```conf
include /absolute/path/to/flume.nvim/extras/kitty/flume-opal.conf
```

Replace the checkout path and reload Kitty. This needs no installation command or shared state.
“Fixed” means the palette name does not follow synchronization. Its colors can still change when you
update Flume, so pin a release or commit if the appearance must stay unchanged. The
[artifact reference](../doc/flume.txt) lists filenames for the other applications.

## Lualine

Lualine is an editor-plugin integration, not a generated extra. Select `theme = "flume"` in your
existing lualine options. See `:help flume-lualine` ([online](../doc/flume.txt)) for the full
example and palette-following behavior.
