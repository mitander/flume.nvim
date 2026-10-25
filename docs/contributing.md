# Contributing to Flume

For a highlight fix, include the language or plugin, the affected group, and a small example that
shows the problem. For a palette change, compare all four palettes and check selections, diffs, and
diagnostics as well as ordinary text.

## Local development

Load your checkout through your plugin manager or Neovim's runtime path. Enable reload-on-save in
your local setup:

```lua
require("flume").setup({ schema = "dusk", dev = true })
```

See `:help flume-dev` ([online](../doc/flume.txt)) for reload scope and recovery. Use `:FlumeReload`
for a manual reload.

## Checks

From the repository root, with Neovim, Python 3.11+, and StyLua 2.5.2 on `PATH`:

```sh
./scripts/check
```

This checks Lua formatting and runs Lua tests, artifact and manifest consistency
checks, local documentation links, whitespace and shell syntax checks, and Python
tests. Screenshot preflight checks committed provenance and dimensions. It does
not open an editor or external application. CI runs the same gate on Neovim 0.9.5 and stable.

The separate [integration snapshot lane](showcase.md#reproducible-integration-snapshots) runs Neovim
and all seven terminal-app integrations in a pinned container, including the README composite and
integration contact sheets:

```sh
./scripts/snapshots test
./scripts/snapshots update
```

`test` compares exact pixels without changing baselines. `update` replaces baselines after every
requested capture succeeds. Review its visual report and commit changed `assets/screenshots/`
images, sidecars, and the snapshot manifest with your code; updating does not approve a result. Both
commands require Python 3.11+ and a running local Docker-compatible runtime. CI runs snapshot tests
in a separate job, not once per Neovim version.

Format maintained Lua from the repository root before running the gate:

```sh
stylua --verify .
```

`stylua.toml` selects Lua 5.1 syntax for Neovim 0.9+, four-space indentation,
Unix line endings, and a 120-column wrapping guide. It prefers double quotes,
keeps call parentheses, and leaves require order unchanged. Use StyLua 2.5.2,
matching CI. Install it separately before running checks. The gate never installs tools.

`.styluaignore` excludes highlighting examples, exact snapshot fixtures, and
generated extras. Do not format these as ordinary Lua. For editor integrations,
pass `--respect-ignores` so explicit file paths also honor these exclusions.
Formatting verification does not replace runtime tests. The gate also rejects
trailing whitespace.

The portable shell runner, `scripts/check`, uses POSIX `sh` and two-space
indentation. With ShellCheck and shfmt installed, check shell style separately:

```sh
shellcheck -s sh scripts/check examples/ansi.sh tests/snapshots/fixtures/*.sh
shfmt -d -i 2 scripts/check
```

These tools are optional and are not installed or required by the gate. The ANSI
example and snapshot scripts are exact rendering fixtures. Check them without
rewriting their formatting or output.

When changing palette roles or exporters, regenerate their outputs:

```sh
nvim --headless --clean -c "lua dofile('scripts/generate-palette-manifest.lua')"
nvim --headless --clean -c "set rtp^=." -c "lua require('flume.compiler').compile_all({ activate = false })" -c "qa!"
```

The first command updates the role manifest. The second updates canonical extras without switching
shared themes. Run the gate again after regeneration.

## Checks that need installed tools

To check real Tree-sitter captures, follow the
[language validation procedure](color-system.md#verify-language-highlighting). To exercise the named
lualine theme with an installed checkout:

```sh
FLUME_LUALINE_RUNTIME=/path/to/lualine.nvim nvim --headless --clean -c "lua dofile('tests/lualine.lua')"
```

These checks supplement the parser-free gate. Neither runs language servers or proves that external
applications reload. Inspect those workflows in the actual application before claiming they work.

## Design and visual review

- [Color system](color-system.md) — role meanings, mapping rules, and contrast targets.
- [Integration review](integration-review.md) — measured foreground/background pairs.
- [Showcase production](showcase.md) — capture procedures and native evidence status.
- [Semantic export](semantic-export.md) — the contract for custom consumers.

When a source change makes committed screenshots stale, refresh them with the showcase procedures.
Capture real application output: do not recolor pixels or hand-assign syntax highlights to
approximate parser output. The maintained Linux Ghostty snapshots do not qualify macOS Ghostty or
Kitty rendering.
