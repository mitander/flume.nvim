# Repository instructions

Flume is a Neovim colorscheme with canonical palettes and generated external-tool themes. Use
[Contributing](CONTRIBUTING.md) for the change workflow, [Development](docs/DEVELOPMENT.md) for
commands and [Testing](docs/TESTING.md#required-checks-for-a-change) for completion checks. Read
[Style](STYLE.md), the affected contract, implementation and direct tests. Preserve unrelated work.

## Technical constraints

- [Design](docs/DESIGN.md) assigns palette, editor, exporter and shared-state ownership.
  [Color system](docs/color-system.md) owns role meaning, mappings and contrast targets.
- [Semantic export](docs/semantic-export.md) owns the versioned consumer contract. Do not change it
  as an incidental refactor or infer activation from compilation.
- Palette/exporter changes need regeneration and validation. Do not hand-edit generated extras or
  `docs/palette-manifest.md`.
- [Showcase](docs/showcase.md) owns screenshot provenance and native rendering evidence. Baseline
  updates do not approve themselves. Parser-free checks do not prove actual captures or application
  reloads.

Run `./scripts/check` on finished inputs and keep missing native evidence explicit. Keep tests and
captures isolated from live user configuration. Do not activate shared themes, install tools or
update baselines merely to make a check pass. No commits, pushes or publication without a request.
Keep one writer per checkout.
