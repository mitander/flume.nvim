#!/usr/bin/env python3
"""Check local Markdown links in release documentation."""

import re
import sys
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent
FILES = (ROOT / "README.md", *sorted((ROOT / "docs").glob("*.md")))
LINK = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")


def main() -> None:
    failures: list[str] = []
    for document in FILES:
        for target in LINK.findall(document.read_text()):
            target = target.split()[0].strip("<>")
            if target.startswith(("http://", "https://", "mailto:", "#")):
                continue

            path_text = unquote(target.split("#", 1)[0])
            if path_text and not (document.parent / path_text).resolve().exists():
                failures.append(f"{document.relative_to(ROOT)}: missing {target}")

    if failures:
        print("\n".join(failures), file=sys.stderr)
        raise SystemExit(1)
    print(f"Markdown links passed: {len(FILES)} files")


if __name__ == "__main__":
    main()
