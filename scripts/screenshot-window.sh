#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

GHOSTTY_COLUMNS=112
GHOSTTY_ROWS=32
GHOSTTY_FONT_SIZE=19
GHOSTTY_PID=""
INPUT_FILE=""
RESTORE_SCHEMA=""
SCHEMA="${1:-dusk}"

fail() {
    echo "Error: $*" >&2
    exit 1
}

case "$SCHEMA" in
    dusk|opal|mira|mesa) ;;
    *) fail "Usage: $0 [dusk|opal|mira|mesa]" ;;
esac

RAW_SCREENSHOT="screenshot_raw-${SCHEMA}.png"
FINAL_SCREENSHOT="screenshot-${SCHEMA}.png"

cleanup() {
    if [ -n "$GHOSTTY_PID" ] && kill -0 "$GHOSTTY_PID" &>/dev/null; then
        echo "Closing Ghostty..."
        kill "$GHOSTTY_PID" &>/dev/null || true
    fi

    if [ -n "$INPUT_FILE" ]; then
        rm -f "$INPUT_FILE"
    fi

    if [ -n "$RESTORE_SCHEMA" ]; then
        nvim --headless --clean \
            -c "set runtimepath^=$(pwd)" \
            -c "lua require('flume.compiler').activate('$RESTORE_SCHEMA')" \
            -c "qa!" >/dev/null
        RESTORE_SCHEMA=""
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
    local finder window_id
    finder=$(mktemp "${TMPDIR:-/tmp}/flume-window-id.XXXXXX.swift")
    cat >"$finder" <<'SWIFT'
import CoreGraphics
import Foundation

let pid = Int32(CommandLine.arguments[1])!
let windows = CGWindowListCopyWindowInfo(
    [.optionOnScreenOnly, .excludeDesktopElements],
    kCGNullWindowID
) as? [[String: Any]] ?? []
let candidates = windows.compactMap { window -> (Int, Double)? in
    guard let owner = window[kCGWindowOwnerPID as String] as? Int,
          owner == Int(pid),
          let layer = window[kCGWindowLayer as String] as? Int,
          layer == 0,
          let number = window[kCGWindowNumber as String] as? Int,
          let bounds = window[kCGWindowBounds as String] as? [String: Any],
          let width = bounds["Width"] as? Double,
          let height = bounds["Height"] as? Double else { return nil }
    return (number, width * height)
}.sorted { $0.1 > $1.1 }
if let window = candidates.first { print(window.0) }
SWIFT

    window_id=$(swift "$finder" "$GHOSTTY_PID")
    rm -f "$finder"
    [ -n "$window_id" ] || fail "Could not identify the Ghostty capture window."
    screencapture -x -o -l "$window_id" "$RAW_SCREENSHOT"
    [ -s "$RAW_SCREENSHOT" ]
}

launch_ghostty() {
    local nvim_bin terminal_path example_dir runtime_cmd input_cmd ghostty_app ghostty_bin

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
    runtime_cmd="+set runtimepath^=$(pwd)"
    input_cmd="+lua vim.wait(500); require('flume').setup({ schema = '$SCHEMA' }); dofile('showcase.lua')"

    printf '%q %q %q %q %q %q\n' \
        "env" \
        "FLUME_SHOWCASE_SCHEMA=$SCHEMA" \
        "$nvim_bin" \
        "--clean" \
        "$runtime_cmd" \
        "$input_cmd" >"$INPUT_FILE"

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
        --env="NVIM_SCREENSHOT_MODE=1" \
        --input="path:$INPUT_FILE" &
    GHOSTTY_PID=$!
    disown "$GHOSTTY_PID" 2>/dev/null || true
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

osascript -e 'id of application "Ghostty"' &>/dev/null || fail "Ghostty is not installed or not in Applications."
command -v magick >/dev/null || fail "ImageMagick is required to save the screenshot."
command -v swift >/dev/null || fail "Swift is required to identify the Ghostty window."

require_screen_recording
RESTORE_SCHEMA=$( (cat extras/current/schema 2>/dev/null || true) | tr -d '\r\n' )
RESTORE_SCHEMA="${RESTORE_SCHEMA:-dusk}"
nvim --headless --clean \
    -c "set runtimepath^=$(pwd)" \
    -c "lua require('flume.compiler').activate('$SCHEMA')" \
    -c "qa!" >/dev/null
if [ "$RESTORE_SCHEMA" = "$SCHEMA" ]; then
    RESTORE_SCHEMA=""
fi
launch_ghostty

rm -f "$RAW_SCREENSHOT"

echo "Waiting for window to render..."
sleep 1.0
osascript -e 'tell application "Ghostty" to activate'

capture_ghostty_window || fail "Capture cancelled or failed."

cleanup
trap - EXIT

magick "$RAW_SCREENSHOT" -strip "PNG24:$FINAL_SCREENSHOT"
echo "Updated $FINAL_SCREENSHOT"
