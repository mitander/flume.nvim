#!/usr/bin/env python3
"""Review actual exported color pairs; native applications remain the visual authority."""

from __future__ import annotations

import argparse
import html
import json
import re
import subprocess
from dataclasses import asdict, dataclass
from pathlib import Path

SCHEMAS = ("dusk", "opal", "mira", "mesa")
ARTIFACTS = {
    "ghostty": "ghostty/flume-{}",
    "kitty": "kitty/flume-{}.conf",
    "tmux": "tmux/colors-{}.conf",
    "lsd": "lsd/colors-{}.yaml",
    "opencode": "opencode/flume-{}.json",
    "lazygit": "lazygit/flume-{}.yml",
    "fzf": "fzf/flume-{}.opts",
    "delta": "delta/flume-{}.gitconfig",
    "pi": "pi/flume-{}.json",
}
HEX = re.compile(r"#[0-9a-fA-F]{6}\Z")


@dataclass(frozen=True)
class Pair:
    label: str
    foreground: str
    background: str
    target: float = 4.5

    def __post_init__(self) -> None:
        if not HEX.fullmatch(self.foreground) or not HEX.fullmatch(self.background):
            raise ValueError(f"Non-literal color in {self.label}")

    @property
    def ratio(self) -> float:
        return contrast(self.foreground, self.background)


def luminance(color: str) -> float:
    channels = [int(color[offset : offset + 2], 16) / 255 for offset in (1, 3, 5)]
    linear = [
        value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4
        for value in channels
    ]
    return sum(
        value * weight for value, weight in zip(linear, (0.2126, 0.7152, 0.0722))
    )


def contrast(first: str, second: str) -> float:
    low, high = sorted((luminance(first), luminance(second)))
    return (high + 0.05) / (low + 0.05)


def xterm_color(index: int, ansi: dict[int, str]) -> str:
    if not 0 <= index <= 255:
        raise ValueError(f"Invalid xterm index: {index}")
    if index < 16:
        return ansi[index]
    if index >= 232:
        value = 8 + 10 * (index - 232)
        return f"#{value:02x}{value:02x}{value:02x}"
    index -= 16
    levels = (0, 95, 135, 175, 215, 255)
    return "#" + "".join(
        f"{levels[channel]:02x}" for channel in (index // 36, index // 6 % 6, index % 6)
    )


def artifact(root: Path, app: str, schema: str, ref: str | None = None) -> str:
    path = "extras/" + ARTIFACTS[app].format(schema)
    if ref is None:
        return (root / path).read_text()
    result = subprocess.run(
        ["git", "show", f"{ref}:{path}"],
        cwd=root,
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout


def terminals(text: str, app: str) -> tuple[dict[str, str], dict[int, str]]:
    if app == "ghostty":
        values = dict(re.findall(r"^([\w-]+) = (#[\da-fA-F]{6})$", text, re.MULTILINE))
        ansi = {
            int(index): color
            for index, color in re.findall(
                r"^palette = (\d+)=(#[\da-fA-F]{6})$", text, re.MULTILINE
            )
        }
    else:
        values = dict(re.findall(r"^(\w+)\s+(#[\da-fA-F]{6})$", text, re.MULTILINE))
        ansi = {index: values[f"color{index}"] for index in range(16)}
    if set(ansi) != set(range(16)):
        raise ValueError(f"Incomplete {app} ANSI palette")
    return values, ansi


def alias_colors(data: dict, definitions: str, mapping: str) -> dict[str, str]:
    def resolve(value: str, seen: frozenset[str] = frozenset()) -> str:
        if HEX.fullmatch(value):
            return value
        if value in seen:
            raise ValueError(f"Cyclic alias: {value}")
        return resolve(data[definitions][value], seen | {value})

    return {key: resolve(value) for key, value in data[mapping].items()}


def integration_pairs(
    root: Path, app: str, schema: str, ref: str | None = None
) -> list[Pair]:
    text = artifact(root, app, schema, ref)
    terminal, ansi = terminals(artifact(root, "ghostty", schema, ref), "ghostty")
    terminal_bg = terminal["background"]
    pairs: list[Pair] = []

    def add(label: str, foreground: str, background: str, target: float = 4.5) -> None:
        pairs.append(Pair(label, foreground, background, target))

    if app in ("ghostty", "kitty"):
        values, slots = terminals(text, app)
        separator = "-" if app == "ghostty" else "_"
        add("Normal text", values["foreground"], values["background"])
        add(
            "Selected text",
            values[f"selection{separator}foreground"],
            values[f"selection{separator}background"],
        )
        cursor_text = "cursor-text" if app == "ghostty" else "cursor_text_color"
        cursor = "cursor-color" if app == "ghostty" else "cursor"
        add("Cursor text", values[cursor_text], values[cursor])
        if app == "kitty":
            for state in ("active", "inactive"):
                add(
                    f"{state.title()} tab",
                    values[f"{state}_tab_foreground"],
                    values[f"{state}_tab_background"],
                )
        for index, color in slots.items():
            add(f"ANSI {index} on terminal", color, values["background"])
    elif app == "fzf":
        values = dict(re.findall(r"([\w+]+):(#[\da-fA-F]{6})", text))
        for label, foreground, background in (
            ("Normal row", "fg", "bg"),
            ("Selected row", "fg+", "bg+"),
            ("Search match", "hl", "bg"),
            ("Match inside selected row", "hl+", "bg+"),
            ("Header", "header", "bg"),
            ("Prompt", "prompt", "bg"),
            ("Query", "query", "bg"),
        ):
            add(label, values[foreground], values[background])
        add("Boundary", values["border"], values["bg"], 3)
    elif app == "opencode":
        values = alias_colors(json.loads(text), "defs", "theme")
        for role in (
            "text",
            "textMuted",
            "syntaxComment",
            "markdownBlockQuote",
            "error",
            "warning",
            "success",
        ):
            add(role, values[role], values["background"])
        add("Text on element", values["text"], values["backgroundElement"])
        add("Muted text on panel", values["textMuted"], values["backgroundPanel"])
        for side in ("Added", "Removed"):
            add(f"Diff {side.lower()}", values[f"diff{side}"], values[f"diff{side}Bg"])
            add(
                f"Diff {side.lower()} number",
                values["diffLineNumber"],
                values[f"diff{side}LineNumberBg"],
            )
        add("Focused boundary", values["borderActive"], values["background"], 3)
    elif app == "pi":
        data = json.loads(text)
        values = alias_colors(data, "vars", "colors")
        bg = data["vars"]["bg"]
        for role in (
            "text",
            "muted",
            "dim",
            "syntaxComment",
            "warning",
            "error",
            "success",
        ):
            add(role + " on palette canvas", values[role], bg)
        add("Selected text", values["text"], values["selectedBg"])
        add("User message", values["userMessageText"], values["userMessageBg"])
        for state in ("Pending", "Success", "Error"):
            add(
                f"Tool {state.lower()} title",
                values["toolTitle"],
                values[f"tool{state}Bg"],
            )
            add(
                f"Tool {state.lower()} output",
                values["toolOutput"],
                values[f"tool{state}Bg"],
            )
        add("Focused boundary on palette canvas", values["borderAccent"], bg, 3)
    elif app == "lazygit":
        values = dict(
            re.findall(r'^\s+(\w+): \["(#[\da-fA-F]{6})"', text, re.MULTILINE)
        )
        for role in ("defaultFgColor", "optionsTextColor", "unstagedChangesColor"):
            add(role + " on terminal", values[role], terminal_bg)
        for role in ("selectedLineBgColor", "inactiveViewSelectedLineBgColor"):
            add(role, values["defaultFgColor"], values[role])
        add(
            "Cherry-picked commit",
            values["cherryPickedCommitFgColor"],
            values["cherryPickedCommitBgColor"],
        )
        add("Active border", values["activeBorderColor"], terminal_bg, 3)
        add("Searching border", values["searchingActiveBorderColor"], terminal_bg, 3)
    elif app == "tmux":
        values = dict(re.findall(r'%hidden (\w+)="(#[\da-fA-F]{6})"', text))
        for role in ("thm_fg", "thm_lgray", "thm_accent", "thm_red", "thm_green"):
            add(role + " on thm_bg (illustrative)", values[role], values["thm_bg"])
        add(
            "thm_black on accent (illustrative)",
            values["thm_black"],
            values["thm_accent"],
        )
    elif app == "lsd":
        section = ""
        for line in text.splitlines():
            heading = re.match(r"^([\w-]+):\s*$", line)
            if heading:
                section = heading[1] + "."
            match = re.match(r"^(\s*)([\w-]+):\s*(\d+)", line)
            if match:
                indent, key, index = match.groups()
                label = (section if indent else "") + key
                # Slots 0..15 follow Ghostty, not the stock xterm palette.
                add(
                    label + " (Ghostty host)",
                    xterm_color(int(index), ansi),
                    terminal_bg,
                )
    elif app == "delta":
        values = dict(
            re.findall(r'^\s+([\w-]+) = .*?"(#[\da-fA-F]{6})"', text, re.MULTILINE)
        )
        for role in (
            "file-style",
            "hunk-header-style",
            "line-numbers-minus-style",
            "line-numbers-plus-style",
        ):
            add(role + " on terminal", values[role], terminal_bg)
        for style in (
            "minus-style",
            "minus-emph-style",
            "plus-style",
            "plus-emph-style",
        ):
            for index, color in ansi.items():
                add(f"ANSI {index} on {style} (Ghostty host)", color, values[style])
    else:
        raise ValueError(f"Unsupported integration: {app}")
    return pairs


def measurements(
    root: Path, ref: str | None = None
) -> dict[str, dict[str, list[Pair]]]:
    result = {
        app: {schema: integration_pairs(root, app, schema, ref) for schema in SCHEMAS}
        for app in ARTIFACTS
    }
    if ref is None:
        hierarchy = {}
        for schema in SCHEMAS:
            colors = json.loads(
                (root / f"extras/palette/flume-{schema}.json").read_text()
            )["colors"]
            hierarchy[schema] = [
                Pair(f"{text} on {surface}", colors[text], colors[surface])
                for surface in ("bg", "surface", "surface_alt", "element_active")
                for text in ("text", "fg", "muted", "placeholder")
            ]
        result = {"palette hierarchy": hierarchy, **result}
    return result


def render(current: dict, baseline: dict | None = None) -> str:
    sections = []
    for app, schemas in current.items():
        cards = []
        for schema, pairs in schemas.items():
            previous = (
                {pair.label: pair for pair in baseline.get(app, {}).get(schema, [])}
                if baseline
                else {}
            )
            rows = []
            for pair in pairs:
                old = previous.get(pair.label)
                changed = baseline is not None and old != pair
                status = "below" if pair.ratio < pair.target else "meets"
                before = ""
                if changed:
                    before = (
                        f"Before: {old.foreground} / {old.background} ({old.ratio:.2f}:1)"
                        if old
                        else "New pair"
                    )
                classes = status + (" changed" if changed else " unchanged")
                rows.append(
                    f'<li class="{classes}"><strong>{html.escape(pair.label)}</strong>'
                    f'<div class="sample" style="color:{pair.foreground};background:{pair.background}">'
                    "Aa 0123 — selected / match</div>"
                    f"<code>{pair.foreground} / {pair.background}</code>"
                    f"<span>{pair.ratio:.2f}:1 · target {pair.target:g}:1 · {status}</span>"
                    f"<small>{html.escape(before)}</small></li>"
                )
            flagged = sum(pair.ratio < pair.target for pair in pairs)
            cards.append(
                f"<article><h3>{schema.title()} · {flagged} below target</h3><ul>{''.join(rows)}</ul></article>"
            )
        sections.append(
            f'<section><h2>{html.escape(app)}</h2><div class="grid">{"".join(cards)}</div></section>'
        )
    return (
        """<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Flume integration review</title>
<style>
body{font:15px system-ui,sans-serif;margin:24px;background:#f5f5f5;color:#202020}h1{margin-bottom:8px}
.grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px}article{min-width:0}
ul{padding:0;list-style:none}li{background:white;padding:12px;margin:8px 0;border-left:4px solid #888}
li.below{border-color:#a83131}li.changed{outline:2px solid #286aba}.sample{padding:16px;margin:8px 0;font:16px monospace}
code,span,small{display:block;margin-top:6px;overflow-wrap:anywhere}small{color:#555}
#changes:checked~main .unchanged{display:none}@media(max-width:900px){.grid{grid-template-columns:repeat(2,minmax(0,1fr))}}
</style><h1>Flume integration review</h1>
<p>Actual exported pairs. Red: below contrast target. Blue outline: changed from baseline.
Ratios use sRGB relative luminance; they do not measure readability or certify accessibility.</p>
<p>These are HTML color previews, not native screenshots. Tmux pairs are illustrative: your statusline owns the layout.
LSD and Delta assume Flume Ghostty ANSI slots and canvas. Pi canvas pairs assume its palette canvas.
Syntax fonts, opacity, terminal settings, and application overrides require native review.</p>
<input type="checkbox" id="changes"><label for="changes">Show only changed pairs (requires baseline)</label>
<main>"""
        + "".join(sections)
        + "</main></html>\n"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root", type=Path, default=Path(__file__).resolve().parent.parent
    )
    parser.add_argument(
        "--baseline-ref",
        help="Compare with committed artifacts at a Git ref, e.g. v0.2.0",
    )
    parser.add_argument(
        "--output", type=Path, default=Path("/tmp/flume-integration-review.html")
    )
    parser.add_argument(
        "--json-output",
        type=Path,
        help="Also write resolved measurements for snapshot review",
    )
    args = parser.parse_args()
    if args.baseline_ref and not re.fullmatch(
        r"[A-Za-z0-9][A-Za-z0-9._/-]*", args.baseline_ref
    ):
        parser.error("baseline-ref must be a commit hash or ordinary branch/tag name")
    current = measurements(args.root)
    baseline = measurements(args.root, args.baseline_ref) if args.baseline_ref else None
    args.output.write_text(render(current, baseline))
    if args.json_output:
        data = {
            app: {
                schema: [
                    asdict(pair) | {"ratio": round(pair.ratio, 6)} for pair in pairs
                ]
                for schema, pairs in schemas.items()
            }
            for app, schemas in current.items()
        }
        args.json_output.write_text(json.dumps(data, indent=2) + "\n")
    print(args.output)
    for app, schemas in current.items():
        flagged = sum(
            pair.ratio < pair.target for pairs in schemas.values() for pair in pairs
        )
        print(
            f"{app}: {flagged} pairs below target (review findings, not an automated release veto)"
        )


if __name__ == "__main__":
    main()
