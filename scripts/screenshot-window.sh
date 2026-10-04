#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

GHOSTTY_COLUMNS=100
GHOSTTY_ROWS=48
ZIG_COLUMNS=112
ZIG_ROWS=32
GHOSTTY_FONT_SIZE=19
GHOSTTY_FONT_FAMILY="Maple Mono NF"
GHOSTTY_PID=""
INPUT_FILE=""
METADATA_FILE=""
SCHEMA="${1:-dusk}"
LANGUAGE="${2:-zig}"
KIND="${3:-syntax}"
RENDERER="showcase.lua"
case "$KIND" in
    syntax) ;;
    selection|completion)
        [ "$LANGUAGE" = go ] || { echo "State captures use Go" >&2; exit 1; }
        RENDERER="states.lua" ;;
    lsp)
        case "$LANGUAGE" in go|zig) ;; *) echo "LSP captures support Go and Zig" >&2; exit 1 ;; esac
        RENDERER="lsp-showcase.lua" ;;
    *) echo "Capture kind must be syntax, selection, completion, or lsp" >&2; exit 1 ;;
esac

fail() {
    echo "Error: $*" >&2
    exit 1
}

case "$SCHEMA" in
    dusk|opal|mira|mesa) ;;
    *) fail "Usage: $0 [dusk|opal|mira|mesa] [zig|rust|tsx|python|go|elixir|toml]" ;;
esac

case "$LANGUAGE" in
    zig|rust|tsx|python|go|elixir|toml) ;;
    *) fail "Unsupported language: $LANGUAGE" ;;
esac

# The compact Zig specimen drives the hero; other languages need more rows.
if [ "$KIND" = syntax ] && [ "$LANGUAGE" = zig ]; then
    GHOSTTY_COLUMNS=$ZIG_COLUMNS
    GHOSTTY_ROWS=$ZIG_ROWS
fi

RAW_SCREENSHOT=$(mktemp "${TMPDIR:-/tmp}/flume-capture.XXXXXX")
FINAL_SCREENSHOT="assets/screenshots/${SCHEMA}/${LANGUAGE}.png"
if [ "$KIND" != syntax ]; then
    FINAL_SCREENSHOT="assets/screenshots/${KIND}/${SCHEMA}/${LANGUAGE}.png"
fi
mkdir -p "$(dirname "$FINAL_SCREENSHOT")"

cleanup() {
    rm -f "$RAW_SCREENSHOT"
    if [ -n "$GHOSTTY_PID" ] && kill -0 "$GHOSTTY_PID" &>/dev/null; then
        echo "Closing Ghostty..."
        kill "$GHOSTTY_PID" &>/dev/null || true
    fi

    if [ -n "$INPUT_FILE" ]; then
        rm -f "$INPUT_FILE"
    fi

    if [ -n "$METADATA_FILE" ]; then
        rm -f "$METADATA_FILE"
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

    terminal_path="$PATH"

    example_dir="$(pwd)/examples"
    INPUT_FILE=$(mktemp "${TMPDIR:-/tmp}/flume-screenshot-input.XXXXXX")
    runtime_cmd="+set runtimepath^=$(pwd)"
    input_cmd="+lua require('flume').setup({ schema = '$SCHEMA', watch_sync = false }); dofile('$RENDERER')"

    printf '%q %q %q %q %q %q %q %q %q %q\n' \
        "env" \
        "FLUME_SHOWCASE_SCHEMA=$SCHEMA" \
        "FLUME_SHOWCASE_LANGUAGE=$LANGUAGE" \
        "FLUME_CAPTURE_KIND=$KIND" \
        "FLUME_TS_RUNTIME=${FLUME_TS_RUNTIME:-}" \
        "FLUME_SHOWCASE_METADATA=$METADATA_FILE" \
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
        --theme="$(pwd)/extras/ghostty/flume-$SCHEMA" \
        --font-size="$GHOSTTY_FONT_SIZE" \
        --font-family="$GHOSTTY_FONT_FAMILY" \
        --background-opacity=1 \
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

METADATA_FILE=$(mktemp "${TMPDIR:-/tmp}/flume-screenshot-metadata.XXXXXX")
repo_root="$(pwd)"
# Fail before opening a window if the real parser or highlight queries are missing.
(cd examples && FLUME_SHOWCASE_LANGUAGE="$LANGUAGE" FLUME_SHOWCASE_METADATA="$METADATA_FILE" nvim --headless --clean \
    -c "set runtimepath^=$repo_root" \
    -c "lua require('flume').setup({schema = '$SCHEMA', watch_sync = false}); dofile('showcase.lua')" \
    -c 'qa!')
[ -s "$METADATA_FILE" ] || fail "Install the $LANGUAGE parser and queries, or set FLUME_TS_RUNTIME."
require_screen_recording
# The GUI process must report its own successful initialization.
: > "$METADATA_FILE"
launch_ghostty

rm -f "$RAW_SCREENSHOT"

echo "Waiting for window to render..."
# Shell initialization can take longer than a fixed one-second delay.
attempts=50
[ "$KIND" != lsp ] || attempts=500
for ((_attempt = 0; _attempt < attempts; _attempt++)); do
    [ -s "$METADATA_FILE" ] && break
    sleep 0.1
done
osascript -e 'tell application "Ghostty" to activate'

[ -s "$METADATA_FILE" ] || fail "The parser-backed fixture did not finish loading."
sleep 0.2
capture_ghostty_window || fail "Capture cancelled or failed."
magick "$RAW_SCREENSHOT" -strip "PNG24:$FINAL_SCREENSHOT"
if [ "$KIND" = syntax ]; then
    python3 scripts/preflight-screenshots.py --record "$SCHEMA" "$LANGUAGE" "$METADATA_FILE"
else
    python3 scripts/preflight-screenshots.py --record-state "$KIND" "$SCHEMA" "$LANGUAGE" "$METADATA_FILE"
fi
cleanup
trap - EXIT
echo "Updated $FINAL_SCREENSHOT"
