"""Exact pixel comparisons and a local, self-contained visual review report."""

import argparse
import html
import json
import shutil
from pathlib import Path

from common import CASES, read_manifest, verify_images


def compare_case(case: str, actual: Path, baseline: Path, report: Path) -> str | None:
    from PIL import Image, ImageChops

    shutil.copyfile(actual / f'{case}.png', report / f'{case}-actual.png')
    expected = baseline / f'{case}.png'
    if not expected.is_file():
        return 'Missing baseline'
    shutil.copyfile(expected, report / f'{case}-expected.png')
    with Image.open(expected) as old, Image.open(actual / f'{case}.png') as new:
        if old.size != new.size:
            return f'Dimensions changed: {old.size} → {new.size}'
        difference = ImageChops.difference(old.convert('RGBA'), new.convert('RGBA'))
        if difference.getbbox(alpha_only=False) is None:
            return None
        # Show every changed channel, including alpha, at full contrast in the report.
        visible = ImageChops.lighter(difference.convert('RGB'), difference.getchannel('A').convert('RGB'))
        visible.point(lambda value: 255 if value else 0).save(report / f'{case}-diff.png')
        return 'Pixels changed (no tolerance)'


def write_report(report: Path, findings: dict[str, str | None]) -> None:
    sections = []
    for case, finding in findings.items():
        images = []
        for label in ('expected', 'actual', 'diff'):
            name = f'{case}-{label}.png'
            if (report / name).exists():
                images.append(f'<figure><figcaption>{label}</figcaption><a href="{name}"><img src="{name}" alt="{case} {label}"></a></figure>')
        sections.append(f'<section><h2>{case}</h2><p>{html.escape(finding or "Unchanged")}</p><div>{"".join(images)}</div></section>')
    page = '<!doctype html><meta charset="utf-8"><title>Flume snapshot comparison</title>'
    page += '<style>body{font:16px sans-serif;margin:2rem;background:#eee;color:#222}div{display:flex;gap:1rem}figure{margin:0;flex:1;min-width:0}img{width:100%}section{margin-bottom:3rem}</style>'
    page += '<h1>Flume snapshot comparison</h1><p>Headless Ghostty application rendering; not native desktop screenshots.</p>'
    (report / 'index.html').write_text(page + ''.join(sections))
    (report / 'results.json').write_text(json.dumps(findings, indent=2) + '\n')


def compare(actual: Path, baseline: Path, report: Path, cases: list[str]) -> int:
    report.mkdir(parents=True, exist_ok=True)
    captured = read_manifest(actual)
    verify_images(actual, captured, cases)
    recorded = read_manifest(baseline)
    findings = {}
    for case in cases:
        finding = compare_case(case, actual, baseline, report)
        if case in recorded['cases']:
            try:
                verify_images(baseline, recorded, [case])
            except ValueError as error:
                finding = str(error)
            record = recorded['cases'][case]
            if isinstance(record, dict) and record.get('environment') != captured['cases'][case]['environment']:
                finding = 'Capture environment changed; update the baseline explicitly'
        elif finding is None:
            finding = 'Missing baseline provenance'
        findings[case] = finding
        print(f'{case}: {finding or "unchanged"}', flush=True)
    write_report(report, findings)
    return int(any(findings.values()))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--actual', type=Path, required=True)
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--case', choices=CASES, action='append', required=True)
    args = parser.parse_args()
    raise SystemExit(compare(args.actual, args.baseline, args.report, args.case))


if __name__ == '__main__':
    main()
