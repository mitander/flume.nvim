Hide
Type "exec sh /repo/tests/snapshots/fixtures/fzf.sh"
Enter
Wait+Screen /4\/4 \(1\)/
Wait+Screen /> flume-opal:/
Show
# Wait checks terminal cells; allow the browser to paint the ready state.
Sleep 200ms
Screenshot "/output/fzf-{{schema}}.png"
# Screenshot samples the next video frame; keep the ready screen unchanged.
Sleep 200ms
