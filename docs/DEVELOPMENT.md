# Development

Prepare a local checkout, format a change and run the source gate from the repository root.
[Testing](TESTING.md) selects additional evidence. None of these source commands needs a shared
palette activation.

## Setup

Have Neovim, Python 3.11+ and StyLua 2.5.2 on `PATH`. StyLua matches the version used in CI. Install
tools separately before checking. The gate never installs them.

Load the checkout through your plugin manager or Neovim runtime path. For local reload-on-save,
enable development mode in that editor:

```lua
require("flume").setup({ schema = "dusk", dev = true })
```

After editing source, run `:FlumeSync` to reload source, regenerate extras and synchronize the
current palette. Add a palette name to switch at the same time. Development mode enables this
source refresh. Normal users sync bundled artifacts without regeneration.

Save-time reload and `:FlumeReload` update only the editor. Use them when checking a change without
publishing it to external tools. See `:help flume-dev` ([online](../doc/flume.txt)) for scope and
recovery. Development mode is local editor configuration, not a source-check prerequisite.

## Edit and check

```sh
stylua --verify .
./scripts/check
```

The first command formats Lua and verifies the resulting syntax tree. The gate checks formatting,
runs headless Lua tests, artifact/manifest consistency, local documentation links, whitespace, shell
syntax and Python tests. Screenshot preflight checks committed provenance and dimensions without
opening an interactive editor or external application.

[Style](../STYLE.md#formatting-and-lints) owns layout choices and exact-fixture exclusions.

## Regenerate palette artifacts

After changing palette roles or exporters:

```sh
nvim --headless --clean -c "lua dofile('scripts/generate-palette-manifest.lua')"
nvim --headless --clean -c "set rtp^=." -c "lua require('flume.compiler').compile_all({ activate = false })" -c "qa!"
```

The first command updates `docs/palette-manifest.md`. The second updates canonical extras without
switching shared themes. Inspect the generated diff and run `./scripts/check` again. Editor-local
overrides do not define committed exports.

## Optional shell checks

With ShellCheck and shfmt already installed:

```sh
shellcheck -s sh scripts/check examples/ansi.sh tests/snapshots/fixtures/*.sh
shfmt -d -i 2 scripts/check
```

These tools are optional and are not required or installed by the gate. The ANSI example and
snapshot scripts are exact rendering fixtures. Check them without rewriting their formatting or
output.

## Capture commands

The separate snapshot lane needs Python 3.11+ and a running local Docker-compatible runtime:

```sh
./scripts/snapshots test
./scripts/snapshots update
```

[Showcase](showcase.md#reproducible-integration-snapshots) owns provisioning, focused selection,
reports and publication behavior. The first run downloads/builds its pinned environment. `test`
never updates baselines. `update` replaces images only after the requested captures succeed, but
still requires visual review. Neither command is needed for an editorial-only change that leaves
capture inputs and visual claims unchanged.
