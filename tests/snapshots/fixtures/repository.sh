#!/bin/sh
# Fixed names, modes, contents, dates and Git history; no host identity or configuration.
set -eu
mkdir -p /tmp/fixture
cd /tmp/fixture
git init -q -b main
git config user.name 'Flume Fixture'
git config user.email 'fixture@example.invalid'
git config commit.gpgsign false
printf 'schema = "dusk"\n' > palette.toml
printf 'old palette\n' > removed.txt
git add .
GIT_AUTHOR_DATE='2026-07-27T12:00:00Z' GIT_COMMITTER_DATE='2026-07-27T12:00:00Z' git commit -qm 'Initial palette fixture'
printf 'schema = "opal"\n' > palette.toml
rm removed.txt
printf '#!/bin/sh\nprintf "Flume\\n"\n' > executable.sh
chmod 755 executable.sh
printf 'exported palette\n' > added.txt
mkdir -p themes
ln -s palette.toml palette-link.toml
ln -s missing.toml broken-link.toml
git add added.txt
find . -not -path './.git/*' -exec touch -h -t 202607271200.00 {} +
