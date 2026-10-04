import argparse
import json
from collections import Counter
from pathlib import Path


# Input: one JSON object per line, e.g. {"event": "page_view"}.
def count_events(path: Path) -> Counter[str]:
    counts: Counter[str] = Counter()
    with path.open(encoding="utf-8") as log:
        for number, line in enumerate(log, start=1):
            if not line.strip():
                continue
            record = json.loads(line)
            event = record.get("event") if isinstance(record, dict) else None
            if not isinstance(event, str) or not event.strip():
                raise ValueError(f"line {number}: expected a non-empty event name")
            counts[event] += 1
    return counts


def main() -> None:
    parser = argparse.ArgumentParser(description="Summarize a JSON-lines event log.")
    parser.add_argument("log", type=Path)
    parser.add_argument("--limit", type=int, default=5, help="number of events to show")
    args = parser.parse_args()
    if args.limit < 1:
        parser.error("--limit must be positive")

    try:
        counts = count_events(args.log)
    except (OSError, ValueError) as error:
        parser.exit(1, f"{args.log}: {error}\n")

    total = counts.total()
    print(f"{total:,} events across {len(counts)} names")
    for event, count in counts.most_common(args.limit):
        print(f"{event:<24} {count:>6,}  {count / total:>6.1%}")


if __name__ == "__main__":
    main()
