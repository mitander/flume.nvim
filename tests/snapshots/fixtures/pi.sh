#!/bin/sh
set -eu
mkdir -p /tmp/fixture /tmp/pi-agent
cp /repo/tests/snapshots/fixtures/pi-session.jsonl /tmp/pi-session.jsonl
printf '{"quietStartup":true,"showThinkingBlock":true}\n' > /tmp/pi-agent/settings.json
cd /tmp/fixture
export PI_CODING_AGENT_DIR=/tmp/pi-agent PI_OFFLINE=1 PI_TELEMETRY=0 PI_TRUE_COLOR=1
clear
exec pi --offline --provider google --model gemini-3.1-pro-preview --no-extensions --no-mcp --no-skills --no-prompt-templates --no-context-files --no-themes --theme "/repo/extras/pi/flume-$FLUME_SCHEMA.json" --use-theme "flume-$FLUME_SCHEMA" --session /tmp/pi-session.jsonl --tui-mode regular
