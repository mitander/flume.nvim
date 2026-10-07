#!/bin/sh
set -eu
export GIT_CONFIG_NOSYSTEM=1
cp "/repo/extras/delta/flume-${FLUME_SCHEMA}.gitconfig" "$HOME/.gitconfig"
printf '\033[2J\033[H\033[?25l'
delta --paging never --line-numbers < /repo/tests/snapshots/fixtures/delta.diff
printf '\nFlume diff fixture complete\n'
exec sleep infinity
