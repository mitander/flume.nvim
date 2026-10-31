# Contributing

Start with [README](README.md) to install and use Flume. Read [Style](STYLE.md), the affected
[design boundary](docs/DESIGN.md), implementation and direct tests before changing behavior.

For a highlight fix, name the language or plugin, affected group and a small example that shows the
problem. For a palette change, compare all four palettes and check selections, diffs and diagnostics
as well as ordinary text.

## Setup

[Development](docs/DEVELOPMENT.md#setup) lists tools and local loading options. Prepare Neovim,
Python and the pinned StyLua explicitly. Checks do not install tools or activate shared themes.

## Make a change

From the repository root:

```sh
stylua --verify .
./scripts/check
```

Inspect the finished diff as well as the check results. Update the existing explanation when a
promise, supported procedure or design changes. Palette-role or exporter changes also need the
[regeneration commands](docs/DEVELOPMENT.md#regenerate-palette-artifacts) and checks of the
resulting outputs. Do not hand-edit the generated palette manifest or extras.

## Checks and review

[Testing](docs/TESTING.md#required-checks-for-a-change) selects parser, integration and screenshot
evidence. The ordinary gate is parser-free. It cannot prove actual language captures or external
application reloads. Screenshot baseline updates do not approve themselves.

Capture real application output rather than recoloring pixels or assigning syntax colors by hand.
Use [Showcase](docs/showcase.md) for the maintained pipeline and its platform limits. Keep missing
native evidence explicit. Changes to authorization, durable ordering, recovery, hostile input or
frozen external contracts require independent read-only review and the applicable checks.

## User-state safety

Do not activate shared themes, change live user configuration or update visual baselines merely to
make a check pass. Tests and captures must use isolated state. Do not install optional tools,
commit, publish or push without a request covering those effects. Coding agents should also read
[AGENTS.md](AGENTS.md).
