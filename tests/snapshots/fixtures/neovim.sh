#!/bin/sh
set -eu
cd /repo/examples
# -c runs after Neovim creates its initial window, unlike an early -u init.
exec nvim --clean -i NONE -c 'lua dofile("/repo/tests/snapshots/fixtures/neovim.lua")'
