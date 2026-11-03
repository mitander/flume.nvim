import re
from dataclasses import dataclass


@dataclass(frozen=True)
class Pair:
    label: str
    foreground: str
    background: str
    target: float = 4.5

    def __post_init__(self) -> None:
        for color in (self.foreground, self.background):
            if not re.fullmatch(r"#[0-9a-fA-F]{6}", color):
                raise ValueError(f"Non-literal color in {self.label}")

    @property
    def ratio(self) -> float:
        low, high = sorted(map(luminance, (self.foreground, self.background)))
        return (high + 0.05) / (low + 0.05)


def luminance(color: str) -> float:
    channels = [int(color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    linear = [
        value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4
        for value in channels
    ]
    return sum(value * weight for value, weight in zip(linear, (0.2126, 0.7152, 0.0722)))


if __name__ == "__main__":
    pair = Pair("editor text", "#d0d2da", "#292938")
    verdict = "PASS" if pair.ratio >= pair.target else "FAIL"
    print(f"{pair.label}: {pair.ratio:.2f}:1 {verdict}")
