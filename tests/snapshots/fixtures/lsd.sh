#!/bin/sh
set -eu
sh /repo/tests/snapshots/fixtures/repository.sh
mkdir -p "$HOME/.config/lsd"
cp "/repo/extras/lsd/colors-$FLUME_SCHEMA.yaml" "$HOME/.config/lsd/colors.yaml"
printf 'color:\n  when: always\n  theme: custom\n' > "$HOME/.config/lsd/config.yaml"
clear
printf 'Flume file types, permissions, sizes, dates and Git state\n\n'
lsd --config-file "$HOME/.config/lsd/config.yaml" --color always --icon never --blocks permission,size,date,name,git --date +%Y-%m-%d -l --git /tmp/fixture
printf '\nLSD FIXTURE READY\n'
sleep 120
