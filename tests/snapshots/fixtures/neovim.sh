#!/bin/sh
set -eu
if [ "${FLUME_NEOTREE:-0}" = 1 ]; then
    sh /repo/tests/snapshots/fixtures/neotree-repository.sh
fi
cd /repo/examples
# -c runs after Neovim creates its initial window, unlike an early -u init.
exec nvim --clean -i NONE -c 'lua dofile("/repo/tests/snapshots/fixtures/neovim.lua")'
