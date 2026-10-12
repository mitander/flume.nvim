# Working on Flume

Use [README.md](README.md) for purpose and supported integrations when needed. Read the changed
behavior's implementation, direct tests, and the relevant owner below; do not load every guide.
Check Git status and preserve unrelated work.

| Task                                         | Owner                                            |
| -------------------------------------------- | ------------------------------------------------ |
| Development commands, checks, and formatting | [Contributing](docs/contributing.md)             |
| Palette roles, highlights, and contrast      | [Color system](docs/color-system.md)             |
| Exported semantic contract                   | [Semantic export](docs/semantic-export.md)       |
| Integration color review                     | [Integration review](docs/integration-review.md) |
| Screenshots and native rendering evidence    | [Showcase](docs/showcase.md)                     |

For changes, run `./scripts/check`. Palette or exporter changes also require the regeneration
commands in Contributing and validation of the resulting outputs. Screenshot changes follow the
Showcase procedures; baseline updates do not approve themselves. Parser-free checks do not prove
actual language captures or external application reloads. Keep missing native evidence explicit.

Do not activate shared themes, change live user configuration, or update visual baselines merely to
make a check pass. Use the repository's existing owners and conventions, not another project's Rust,
release, tracker, or qualification workflow.
