#!/bin/sh
set -eu
sh /repo/tests/snapshots/fixtures/repository.sh
mkdir -p /tmp/lazygit
cp "/repo/extras/lazygit/flume-$FLUME_SCHEMA.yml" /tmp/lazygit/theme.yml
cat > /tmp/lazygit/config.yml <<'CONFIG'
disableStartupPopups: true
gui:
  showRandomTip: false
  showCommandLog: false
  timeFormat: '2006-01-02'
  shortTimeFormat: '2006-01-02'
git:
  autoFetch: false
  autoRefresh: false
CONFIG
exec lazygit --use-config-dir /tmp/lazygit --use-config-file /tmp/lazygit/config.yml,/tmp/lazygit/theme.yml --path /tmp/fixture
