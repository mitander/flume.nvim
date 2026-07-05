#!/bin/bash

# Script to automatically spawn Ghostty with the Flume theme,
# open Neovim with the sample file, position the cursor,
# and take a screenshot of the window.

# Ensure we are in the repository root
cd "$(dirname "$0")/.."

# Check if Ghostty is installed
if ! osascript -e 'id of application "Ghostty"' &>/dev/null; then
    echo "Error: Ghostty is not installed or not in Applications."
    exit 1
fi

# Resolve absolute paths
NVIM_PATH=$(command -v nvim)
if [ -z "$NVIM_PATH" ]; then
    NVIM_PATH="nvim"
fi

EXAMPLE_DIR="$(pwd)/examples"
FILE_NAME="flume.zig"
WORKING_DIR="$EXAMPLE_DIR"

# Ghostty is launched via macOS `open`, so the terminal process may not inherit
# the PATH from the shell that ran this script. Capture the user's login-shell
# PATH and pass it explicitly so Neovim can find tools such as zig and zls.
TERMINAL_PATH=$(/bin/zsh -lc 'print -r -- "$PATH"')
if [ -z "$TERMINAL_PATH" ]; then
    TERMINAL_PATH="$PATH"
fi

# Avoid Ghostty's macOS "Allow Ghostty to execute ...?" prompt by not using
# -e/--command. Instead, start the normal login shell and send the nvim command
# as startup input. Leave the temp file in /tmp long enough for Ghostty to read it.
INPUT_FILE=$(mktemp "${TMPDIR:-/tmp}/flume-screenshot-input.XXXXXX")
printf '%q %q %q %q %q\n' \
    "$NVIM_PATH" \
    "+18" \
    "+normal! w" \
    "+lua vim.defer_fn(function() vim.o.autochdir = false; pcall(vim.cmd, 'lcd %:p:h'); pcall(vim.cmd, 'Gitsigns detach') end, 500)" \
    "$FILE_NAME" >"$INPUT_FILE"

echo "Opening Ghostty with the Flume theme and screenshot settings..."
open -na Ghostty.app --args \
    --window-save-state=never \
    --quit-after-last-window-closed=true \
    --theme=flume \
    --font-size=19 \
    --window-width=102 \
    --window-height=28 \
    --window-padding-x=16 \
    --window-padding-y=16 \
    --working-directory="$WORKING_DIR" \
    --env="PATH=$TERMINAL_PATH" \
    --input="path:$INPUT_FILE"

# Give Ghostty and Neovim time to load LSP/Tree-sitter and draw
echo "Waiting for window to render..."
sleep 2.5

# Bring Ghostty to front and capture its window ID
WINDOW_ID=$(osascript -e '
tell application "Ghostty"
    activate
    try
        return id of window 1
    on error
        return ""
    end try
end tell')

if [ -n "$WINDOW_ID" ]; then
    echo "Capturing Ghostty window ID $WINDOW_ID..."
    # Capture only the window, omitting the drop shadow (-o)
    screencapture -o -l "$WINDOW_ID" screenshot.png
    echo "Screenshot successfully saved to screenshot.png"
    
    # Gracefully close the Ghostty window
    osascript -e '
    tell application "Ghostty"
        close window 1
    end tell'
else
    echo "Error: Could not retrieve Ghostty window ID. Please take screenshot manually."
fi

