#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

GHOSTTY_COLUMNS=102
GHOSTTY_ROWS=26
GHOSTTY_FONT_SIZE=19
GHOSTTY_PID=""
INPUT_FILE=""

fail() {
    echo "Error: $*" >&2
    exit 1
}

cleanup() {
    if [ -n "$GHOSTTY_PID" ] && kill -0 "$GHOSTTY_PID" &>/dev/null; then
        echo "Closing Ghostty..."
        kill "$GHOSTTY_PID" &>/dev/null || true
    fi

    if [ -n "$INPUT_FILE" ]; then
        rm -f "$INPUT_FILE"
    fi
}

screen_recording_allowed() {
    local probe
    probe=$(mktemp "${TMPDIR:-/tmp}/flume-screenshot-probe.XXXXXX.png")

    if screencapture -x -R 0,0,1,1 "$probe" &>/dev/null && [ -s "$probe" ]; then
        rm -f "$probe"
        return 0
    fi

    rm -f "$probe"
    return 1
}

require_screen_recording() {
    if screen_recording_allowed; then
        return
    fi

    echo "macOS denied Screen Recording permission for this terminal."
    echo "Grant permission, quit/reopen the terminal, then retry."
    echo ""
    echo "System Settings -> Privacy & Security -> Screen Recording"
    echo ""
    echo "sudo/password cannot grant this macOS privacy permission."
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture" &>/dev/null || true
    exit 1
}

capture_ghostty_window() {
    local err_file
    err_file=$(mktemp "${TMPDIR:-/tmp}/flume-screenshot-error.XXXXXX")

    echo ""
    echo "=========================================================="
    echo " ACTION REQUIRED: click the Ghostty window with the camera."
    echo "=========================================================="
    echo ""

    if screencapture -o -w screenshot_raw.png 2>"$err_file" && [ -s screenshot_raw.png ]; then
        rm -f "$err_file"
        return 0
    fi

    cat "$err_file" >&2
    rm -f "$err_file" screenshot_raw.png

    echo "Retrying with screen-backed window capture. Click Ghostty again."
    screencapture -i -W -S -o screenshot_raw.png && [ -s screenshot_raw.png ]
}

launch_ghostty() {
    local nvim_bin terminal_path example_dir input_cmd ghostty_app ghostty_bin

    nvim_bin=$(command -v nvim || true)
    if [ -z "$nvim_bin" ]; then
        nvim_bin="nvim"
    fi

    terminal_path=$(/bin/zsh -lc 'print -r -- "$PATH"')
    if [ -z "$terminal_path" ]; then
        terminal_path="$PATH"
    fi

    example_dir="$(pwd)/examples"
    INPUT_FILE=$(mktemp "${TMPDIR:-/tmp}/flume-screenshot-input.XXXXXX")
    input_cmd="+lua vim.defer_fn(function() vim.o.autochdir = false; pcall(vim.cmd, 'lcd %:p:h'); pcall(vim.cmd, 'Gitsigns detach') end, 500)"

    printf '%q %q %q %q %q\n' \
        "$nvim_bin" \
        "+18" \
        "+normal! w" \
        "$input_cmd" \
        "flume.zig" >"$INPUT_FILE"

    ghostty_app=$(osascript -e 'POSIX path of (path to application "Ghostty")')
    ghostty_bin="${ghostty_app}Contents/MacOS/ghostty"

    echo "Opening Ghostty with the Flume theme and screenshot settings..."
    "$ghostty_bin" \
        --window-save-state=never \
        --quit-after-last-window-closed=true \
        --theme=flume \
        --font-size="$GHOSTTY_FONT_SIZE" \
        --window-width="$GHOSTTY_COLUMNS" \
        --window-height="$GHOSTTY_ROWS" \
        --window-padding-x=16 \
        --window-padding-y=16 \
        --working-directory="$example_dir" \
        --env="PATH=$terminal_path" \
        --input="path:$INPUT_FILE" &
    GHOSTTY_PID=$!
    disown "$GHOSTTY_PID" 2>/dev/null || true
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

osascript -e 'id of application "Ghostty"' &>/dev/null || fail "Ghostty is not installed or not in Applications."

require_screen_recording
launch_ghostty

rm -f screenshot_raw.png

echo "Waiting for window to render..."
sleep 1.0
osascript -e 'tell application "Ghostty" to activate'

capture_ghostty_window || fail "Capture cancelled or failed."

cleanup
trap - EXIT

python3 "$(dirname "$0")/compose_header.py"
echo "Updated screenshot.png"
