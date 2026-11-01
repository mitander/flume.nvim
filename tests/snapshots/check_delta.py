"""Observe native Delta SGR output, independently of exporter style parsing."""

import argparse
import json
import os
import re
import shlex
import shutil
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Cell:
    text: str
    foreground: str
    background: str
    underline: bool


def cells(output: str, colors: dict[str, str]) -> list[Cell]:
    names = ("black", "red", "green", "yellow", "blue", "magenta", "cyan", "white")
    ansi = [colors[name] for name in names] + [colors["bright_" + name] for name in names]
    foreground, background, underline = colors["fg"], colors["terminal_bg"], False
    result = []
    position = 0
    for match in re.finditer(r"\x1b\[([0-9;]*)([A-Za-z])", output):
        result.extend(
            Cell(text, foreground, background, underline)
            for text in output[position : match.start()]
        )
        position = match.end()
        if match[2] != "m":
            continue
        codes = [int(value or "0") for value in match[1].split(";")]
        index = 0
        while index < len(codes):
            code = codes[index]
            index += 1
            if code == 0:
                foreground, background, underline = colors["fg"], colors["terminal_bg"], False
            elif code in (38, 48):
                if codes[index] != 2:
                    raise ValueError("Native fixture requires RGB or 16-color SGR")
                color = "#" + "".join(
                    f"{channel:02x}" for channel in codes[index + 1 : index + 4]
                )
                index += 4
                if code == 38:
                    foreground = color
                else:
                    background = color
            elif code == 39:
                foreground = colors["fg"]
            elif code == 49:
                background = colors["terminal_bg"]
            elif 30 <= code <= 37 or 90 <= code <= 97:
                foreground = ansi[code - (30 if code < 90 else 82)]
            elif 40 <= code <= 47 or 100 <= code <= 107:
                background = ansi[code - (40 if code < 100 else 92)]
            elif code in (4, 24):
                underline = code == 4
    result.extend(Cell(text, foreground, background, underline) for text in output[position:])
    return result


def contrast(first: str, second: str) -> float:
    def luminance(color: str) -> float:
        channels = [int(color[index : index + 2], 16) / 255 for index in (1, 3, 5)]
        linear = [
            channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4
            for channel in channels
        ]
        return sum(value * weight for value, weight in zip(linear, (0.2126, 0.7152, 0.0722)))

    low, high = sorted((luminance(first), luminance(second)))
    return (high + 0.05) / (low + 0.05)


def check_output(output: str, colors: dict[str, str]) -> None:
    rendered = cells(output, colors)
    plain = "".join(cell.text for cell in rendered)
    probes = (
        ('print(select_palette("dusk"))', "dusk", "green", "diff_delete_emphasis", True),
        ('print(select_palette("opal"))', "opal", "green", "diff_add_emphasis", True),
        ("return name.upper()", ".upper()", "fg", "diff_add_emphasis", True),
        ("return name.upper()", "return", "magenta", "diff_add_bg", False),
        ("return name", "return", "magenta", "diff_delete_bg", False),
        ("return name", "name", "fg", "diff_delete_bg", False),
    )
    for line, token, ink, surface, underlined in probes:
        start = plain.index(line) + line.index(token)
        for cell in rendered[start : start + len(token)]:
            actual = (cell.foreground, cell.background, cell.underline)
            if actual != (colors[ink], colors[surface], underlined):
                raise ValueError(f"{token}: unexpected native attributes {cell}")
            ratio = contrast(cell.foreground, cell.background)
            if ratio < 4.5:
                raise ValueError(f"{token}: native contrast {ratio:.2f}:1 is below 4.5:1")


def check(root: Path, app: str, schema: str) -> None:
    colors = json.loads((root / f"extras/palette/flume-{schema}.json").read_text())["colors"]
    executable = shutil.which("delta")
    if executable is None:
        raise ValueError("Install Delta separately before native qualification")
    with tempfile.TemporaryDirectory(prefix="flume-delta-native-") as temporary:
        home = Path(temporary)
        arguments = []
        if app == "delta":
            shutil.copyfile(root / f"extras/delta/flume-{schema}.gitconfig", home / ".gitconfig")
        else:
            config = (root / f"extras/lazygit/flume-{schema}.yml").read_text()
            command = re.search(r"^\s+pager: '(.*)'$", config, re.MULTILINE)
            if command is None:
                raise ValueError("Missing Lazygit pager")
            pager = shlex.split(command[1])
            if pager[0] != "delta":
                raise ValueError("Lazygit fixture requires a Delta pager")
            arguments = pager[1:]
        environment = {
            "PATH": os.environ.get("PATH", os.defpath),
            "HOME": temporary,
            "XDG_CONFIG_HOME": temporary,
            "XDG_DATA_HOME": temporary,
            "GIT_CONFIG_NOSYSTEM": "1",
            "TERM": "xterm-256color",
            "COLORTERM": "truecolor",
        }
        if not any(argument.startswith("--paging=") for argument in arguments):
            arguments.append("--paging=never")
        result = subprocess.run(
            [executable, *arguments, "--true-color=always", "--width=100"],
            input=(root / "tests/snapshots/fixtures/delta.diff").read_text(),
            cwd=home,
            env=environment,
            text=True,
            capture_output=True,
            check=True,
            timeout=15,
        )
        check_output(result.stdout, colors)
    print(f"PASS: native {app}/{schema} diff inks, normal/emphasis fills and underlines")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--app", choices=("delta", "lazygit"), action="append")
    parser.add_argument("--schema", choices=("dusk", "opal", "mira", "mesa"), action="append")
    args = parser.parse_args()
    for app in args.app or ("delta", "lazygit"):
        for schema in args.schema or ("dusk", "opal", "mira", "mesa"):
            check(args.root.resolve(), app, schema)


if __name__ == "__main__":
    main()
