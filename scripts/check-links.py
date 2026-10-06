#!/usr/bin/env python3
"""Check local Markdown and HTML links in release documentation."""

import re
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent
FILES = (ROOT / "README.md", *sorted((ROOT / "docs").rglob("*.md")))
LINK = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")


class HTMLLinks(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.targets: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        for name, value in attrs:
            if name in ("href", "src") and value:
                self.targets.append(value)


def link_targets(text: str) -> list[str]:
    html = HTMLLinks()
    html.feed(text)
    markdown = [target.split()[0].strip("<>") for target in LINK.findall(text)]
    return markdown + html.targets


def main() -> None:
    failures: list[str] = []
    for document in FILES:
        for target in link_targets(document.read_text()):
            target = target.strip()
            if target.startswith(("http://", "https://", "mailto:", "#")):
                continue

            path_text = unquote(target.split("#", 1)[0])
            if path_text and not (document.parent / path_text).resolve().exists():
                failures.append(f"{document.relative_to(ROOT)}: missing {target}")

    if failures:
        print("\n".join(failures), file=sys.stderr)
        raise SystemExit(1)
    print(f"Documentation links passed: {len(FILES)} files")


if __name__ == "__main__":
    main()
