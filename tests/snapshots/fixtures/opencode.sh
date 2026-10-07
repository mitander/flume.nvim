#!/bin/sh
set -eu
mkdir -p /tmp/fixture "$HOME/config/opencode/themes"
export XDG_CONFIG_HOME="$HOME/config" XDG_DATA_HOME="$HOME/data" XDG_CACHE_HOME="$HOME/cache" XDG_STATE_HOME="$HOME/state"
cp "/repo/extras/opencode/flume-$FLUME_SCHEMA.json" "$XDG_CONFIG_HOME/opencode/themes/flume.json"
printf '{"theme":"flume","cursor":{"style":"block","blinking":false}}\n' > "$XDG_CONFIG_HOME/opencode/tui.json"
mkdir -p "$XDG_STATE_HOME/opencode"
printf '{"animations_enabled":false}\n' > "$XDG_STATE_HOME/opencode/kv.json"
cd /tmp/fixture
# Keep this app fixture's code plain: syntax parsers have separate editor coverage.
sed "s/\`opal\`/\`$FLUME_SCHEMA\`/g" /repo/tests/snapshots/fixtures/opencode-session.json > /tmp/opencode-session.json
opencode --pure import /tmp/opencode-session.json > /tmp/opencode-import.log 2>&1
exec opencode --pure --session ses_flumequalifiedfixture /tmp/fixture
