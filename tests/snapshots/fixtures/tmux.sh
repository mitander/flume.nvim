#!/bin/sh
set -eu
mkdir -p /tmp/fixture
cat > /tmp/tmux.conf <<CONFIG
source-file /repo/extras/tmux/colors-$FLUME_SCHEMA.conf
set -g status-style 'bg=#{thm_bg},fg=#{thm_fg}'
set -g status-left '#[fg=#{thm_accent}] Flume #[default]'
set -g status-justify centre
set -g status-right '#[fg=#{thm_red}]error #[fg=#{thm_green}]success #[fg=#{thm_yellow}]warning '
set -g status-right-length 40
set -g window-status-style 'fg=#{thm_muted},bg=#{thm_bg}'
set -g window-status-format ' #W '
set -g window-status-current-format ' #W '
set -g window-status-current-style 'fg=#{thm_on_accent},bg=#{thm_pink},bold'
set -g message-style 'fg=#{thm_fg},bg=#{thm_surface}'
set -g message-command-style 'fg=#{thm_accent},bg=#{thm_surface}'
set -g default-terminal tmux-256color
set -as terminal-features ',xterm-256color:RGB'
set -g automatic-rename off
CONFIG
exec tmux -L flume -f /tmp/tmux.conf \
  new-session -s flume -n term -c /tmp/fixture 'sleep 120' \; \
  new-window -n agent -c /tmp/fixture 'clear; printf "Tmux palette variables and active window\n\nThe exported theme supplies colors; this fixture supplies the layout.\n\nTMUX FIXTURE READY\n"; sleep 120' \; \
  new-window -d -n git -c /tmp/fixture 'sleep 120'
