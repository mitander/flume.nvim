Hide
Type "exec sh /repo/tests/snapshots/fixtures/delta.sh"
Enter
Wait+Screen /Flume diff fixture complete/
Show
# Wait checks terminal cells; allow the browser to paint the ready state.
Sleep 200ms
Screenshot "/output/delta-{{schema}}.png"
# Screenshot samples the next video frame; keep the ready screen unchanged.
Sleep 200ms
