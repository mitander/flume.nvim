#!/bin/sh
set -eu
export FZF_DEFAULT_OPTS_FILE="/repo/extras/fzf/flume-${FLUME_SCHEMA}.opts"
export FZF_DEFAULT_OPTS=''
printf '\033[2J\033[H'
# Keep equal matches in fixture order when palette descriptions change length.
exec fzf --sync --reverse --multi --border --query flume --tiebreak=index \
    --pointer '>' --marker '*' --bind 'result:select+down+unbind(result)' \
    --header 'Select a Flume palette' < /repo/tests/snapshots/fixtures/palettes.txt
