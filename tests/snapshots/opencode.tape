Hide
Type "exec sh /repo/tests/snapshots/fixtures/opencode.sh"
Enter
Wait+Screen /select_palette/
Show
# Markdown syntax styling is asynchronous even for plain code fences.
Sleep 2s
Screenshot "/output/{{case}}.png"
Sleep 200ms
