#!/usr/bin/env python3
"""Reject trailing spaces/tabs in tracked and nonignored working-tree text files."""

import os
import subprocess
import sys
from pathlib import Path

PATHS = ("*.lua", "*.md", "*.txt", "*.yml", "*.yaml", "*.sh", "scripts/check")


def git_paths(root: Path, *options: str) -> set[str]:
    result = subprocess.run(
        ["git", "ls-files", "-z", *options, "--", *PATHS],
        cwd=root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    )
    return {os.fsdecode(path) for path in result.stdout.split(b"\0") if path}


def check_whitespace(root: Path) -> int:
    try:
        paths = git_paths(root, "--cached", "--others", "--exclude-standard")
        deleted = git_paths(root, "--deleted")
    except (OSError, subprocess.CalledProcessError) as error:
        print(f"Cannot enumerate whitespace inputs: {error}", file=sys.stderr)
        return 2

    violations = False
    failures = False
    for name in sorted(paths):
        try:
            content = (root / name).read_bytes()
        except OSError as error:
            # Git's deleted inventory excludes intentional working-tree deletions,
            # not other read failures or paths that vanish after enumeration.
            if isinstance(error, FileNotFoundError) and name in deleted:
                continue
            print(f"Cannot read {name!r}: {error}", file=sys.stderr)
            failures = True
            continue

        for number, line in enumerate(content.split(b"\n"), start=1):
            if line.endswith((b" ", b"\t")):
                print(f"{name!r}:{number}: trailing whitespace", file=sys.stderr)
                violations = True

    if failures:
        return 2
    return 1 if violations else 0


def main() -> int:
    return check_whitespace(Path.cwd())


if __name__ == "__main__":
    raise SystemExit(main())
