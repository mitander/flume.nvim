#!/usr/bin/env bash
# Qualify public installation with native Fish, fzf, LSD, Lazygit and Git.
# shellcheck disable=SC2016 # Fish snippets must retain their literal variables.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/flume-tools-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT
TEST_ROOT="$(cd "$TEST_ROOT" && pwd -P)"
FISH="$(command -v fish)"
NVIM="$(command -v nvim)"
FZF="$(command -v fzf)"
LSD="$(command -v lsd)"
command -v lazygit >/dev/null

# Copy before activation so legacy forwarding cannot touch the working checkout.
fixture="$TEST_ROOT/plugin checkout"
mkdir -p "$fixture" "$TEST_ROOT/home/.config/lazygit"
cp -R "$ROOT/lua" "$ROOT/colors" "$ROOT/extras" "$fixture/"
rm -rf "$fixture/extras/current"
export HOME="$TEST_ROOT/home" XDG_CONFIG_HOME="$TEST_ROOT/home/.config"
export XDG_DATA_HOME="$TEST_ROOT/home/.local/share" XDG_CACHE_HOME="$TEST_ROOT/home/.cache"
export FLUME_DATA_DIR="$XDG_DATA_HOME/nvim/flume" FLUME_TEST_RUNTIME="$fixture"
export FLUME_TEST_COMMAND="$TEST_ROOT/adopt.fish"
export LS_COLORS='di=01;34:ow=30;42:tw=30;43:*.rs=35'
unset FZF_DEFAULT_OPTS_FILE LG_CONFIG_FILE FZF_DEFAULT_OPTS CONFIG_DIR
printf 'gui: {}\n' >"$XDG_CONFIG_HOME/lazygit/config.yml"

"$NVIM" --headless --clean \
  -c 'lua vim.opt.runtimepath:prepend(vim.env.FLUME_TEST_RUNTIME)' \
  -c 'lua require("flume").setup({ schema = "dusk", watch_sync = false })' \
  -c 'lua require("flume.state").activate("dusk")' \
  -c 'lua vim.ui.select = function(items, _, done) done(items[1]) end; local extras = require("flume.extras"); for _, name in ipairs({ "fish", "fish_tools", "tmux", "pi" }) do extras.install(name, function(result) assert(result.status == "linked", result.message); if name == "fish_tools" then assert(result.settings == "adopt"); vim.fn.writefile({ result.reload_command }, vim.env.FLUME_TEST_COMMAND) end end) end' \
  -c 'qa!' >"$TEST_ROOT/install.log" 2>&1

"$FISH" --private -c 'printf "%s\n" $FZF_DEFAULT_OPTS_FILE $LG_CONFIG_FILE $LS_COLORS $fish_color_error' >"$TEST_ROOT/settings"
printf '%s\n' "$FLUME_DATA_DIR/current/fzf.opts" \
  "$XDG_CONFIG_HOME/lazygit/config.yml,$FLUME_DATA_DIR/current/lazygit.yml" \
  'di=01;34:tw=30;43:*.rs=35:ow=0;35' >"$TEST_ROOT/expected"
grep '^set -g fish_color_error ' "$ROOT/extras/fish/flume-dusk.fish" | awk '{print $4}' >>"$TEST_ROOT/expected"
cmp "$TEST_ROOT/expected" "$TEST_ROOT/settings"

# Run the installer's exact quoted adoption command in an already-configured shell.
FZF_DEFAULT_OPTS_FILE=/old/fzf LG_CONFIG_FILE=/old/lazygit "$FISH" --private \
  -c 'source "$argv[1]"; printf "%s\n" $FZF_DEFAULT_OPTS_FILE $LG_CONFIG_FILE' -- "$FLUME_TEST_COMMAND" >"$TEST_ROOT/adopted"
printf '%s\n' "$FLUME_DATA_DIR/current/fzf.opts" \
  "$XDG_CONFIG_HOME/lazygit/config.yml,$FLUME_DATA_DIR/current/lazygit.yml" >"$TEST_ROOT/adopted-expected"
cmp "$TEST_ROOT/adopted-expected" "$TEST_ROOT/adopted"

# Lazygit, not Flume, owns custom configuration-directory selection.
mkdir "$TEST_ROOT/custom lazygit"
printf 'gui: {}\n' >"$TEST_ROOT/custom lazygit/config.yml"
CONFIG_DIR="$TEST_ROOT/custom lazygit" "$FISH" --private -c 'printf "%s\n" $LG_CONFIG_FILE' >"$TEST_ROOT/custom"
printf '%s\n' "$TEST_ROOT/custom lazygit/config.yml,$FLUME_DATA_DIR/current/lazygit.yml" >"$TEST_ROOT/custom-expected"
cmp "$TEST_ROOT/custom-expected" "$TEST_ROOT/custom"

# Native Git reads the same durable include path, independently of a plugin checkout.
git config --file "$TEST_ROOT/gitconfig" include.path "$FLUME_DATA_DIR/current/delta.gitconfig"
expected_delta="$(git config --file "$ROOT/extras/delta/flume-dusk.gitconfig" --get delta.flume.minus-style)"
actual_delta="$(git config --file "$TEST_ROOT/gitconfig" --includes --get delta.flume.minus-style)"
[[ "$actual_delta" == "$expected_delta" ]]
[[ "$(readlink "$HOME/.tmux/flume-theme.conf")" == "$FLUME_DATA_DIR/current/tmux.conf" ]]
[[ "$(readlink "$HOME/.pi/agent/themes/flume.json")" == "$FLUME_DATA_DIR/current/pi.json" ]]

# The generated fzf file is accepted by the installed application.
printf 'entry\n' | FZF_DEFAULT_OPTS_FILE="$FLUME_DATA_DIR/current/fzf.opts" "$FZF" --filter entry >"$TEST_ROOT/fzf"
grep -qx entry "$TEST_ROOT/fzf"

# LSD observes the shell rule, not merely the generated metadata theme.
mkdir "$TEST_ROOT/world-writable"
chmod 777 "$TEST_ROOT/world-writable"
export FLUME_TEST_LSD="$LSD" FLUME_TEST_DIRECTORY="$TEST_ROOT/world-writable"
"$FISH" --private -c 'command "$FLUME_TEST_LSD" --ignore-config --color always --icon never -d "$FLUME_TEST_DIRECTORY"' >"$TEST_ROOT/lsd"
python3 - "$TEST_ROOT/lsd" <<'PY'
from pathlib import Path
import sys

output = Path(sys.argv[1]).read_bytes()
assert b"\x1b[38;5;5m" in output, repr(output)
assert b"\x1b[48;" not in output, repr(output)
PY
printf 'PASS: public installation, Fish startup, native fzf/LSD and durable Git/Tmux/Pi paths\n'
