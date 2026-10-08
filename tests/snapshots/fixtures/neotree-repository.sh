#!/bin/sh
# A small project with deterministic Git states for the real Neo-tree sidebar.
set -eu
mkdir -p /tmp/flume-demo/src /tmp/flume-demo/docs /tmp/flume-demo/themes
cd /tmp/flume-demo
git init -q -b main
git config user.name 'Flume Fixture'
git config user.email 'fixture@example.invalid'
git config commit.gpgsign false
cp /repo/examples/flume.go src/main.go
printf '# Flume demo\n' > README.md
printf 'module example.invalid/flume\n\ngo 1.23\n' > go.mod
printf 'schema = "dusk"\n' > themes/palette.toml
printf 'Project notes\n' > docs/guide.md
git add .
GIT_AUTHOR_DATE='2026-07-27T12:00:00Z' GIT_COMMITTER_DATE='2026-07-27T12:00:00Z' git commit -qm 'Initial project'
printf 'schema = "opal"\n' > themes/palette.toml
printf '\nA small terminal palette demo.\n' >> README.md
printf 'package main\n' > src/palette.go
git add src/palette.go
printf 'Local capture notes\n' > notes.md
