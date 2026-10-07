Hide
Type "exec sh /repo/tests/snapshots/fixtures/lazygit.sh"
Enter
Wait+Screen /palette.toml/
Type "2"
Wait+Screen /exported palette/
Show
# Git status and diff loading finish separately; let the completed UI paint.
Sleep 700ms
