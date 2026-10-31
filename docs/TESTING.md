# Testing

Choose observations that can expose the changed behavior. Defined highlight roles do not prove what
a parser emits. Exact pixels preserve a captured result, but do not decide whether it is readable.
[Development](DEVELOPMENT.md) owns prerequisites and commands.

## Required checks for a change

| Change | Checks and observations |
| - | - |
| Ordinary source or documentation | `./scripts/check` and inspection of the finished diff |
| Palette roles or exporters | Ordinary gate, artifact regeneration and validation of generated outputs |
| Language-provider mapping | Ordinary gate and the affected real parser/LSP observation |
| Named lualine integration | Ordinary gate and installed-plugin check |
| Capture pipeline, scene, visual baseline or changed visual claims | Applicable checks and the affected snapshot lane, followed by visual review |
| External application reload behavior | Applicable checks and observation in the actual application |
| Authorization, durable ordering, recovery, hostile input or frozen external contract | Applicable checks plus independent read-only review |

Missing required evidence leaves the change incomplete. Do not activate shared themes or update a
baseline just to make a check pass. Editorial-only changes with unchanged capture inputs and visual
claims do not need new screenshots.

## Test boundaries

The ordinary gate checks Lua formatting/behavior, generated artifacts and manifests, links,
whitespace, syntax and Python tooling. It launches headless Neovim but needs no language parsers,
language servers or external application instances. Preflight validates existing screenshot
provenance and dimensions. It does not capture a new scene.

[Native language checks](color-system.md#verify-language-highlighting) open representative fixtures
with real Tree-sitter parsers and queries in all four palettes. They do not run language servers.
LSP checks additionally need the relevant server and inspection of semantic-token modifiers.

For the named lualine integration, supply an installed checkout explicitly:

```sh
FLUME_LUALINE_RUNTIME=/path/to/lualine.nvim nvim --headless --clean -c "lua dofile('tests/lualine.lua')"
```

This supplements the parser-free gate. It does not qualify another plugin version or external-app
reload.

## Native shell-tool integration

With Fish 3.5+, fzf, LSD 1.2+, Lazygit, Git, Neovim and Python already installed, run:

```sh
bash tests/fish-tools.sh
```

This copies the plugin into a disposable home before using the public installer. It checks Fish
startup, the installer's exact one-command adoption of stale session exports, real Lazygit
config-directory discovery, fzf's active options file, LSD filename colors and stable Git/Tmux/Pi
file paths. It does not target a live shell, select a shared theme or prove that
running Tmux/Pi instances reloaded. The ordinary gate syntax-checks the script and runs focused Fish
setup tests when Fish is available, without requiring the other applications. Those tests also
check preservation mode, persistent-variable isolation, quoted paths and stale-helper refresh with
an independent editor palette.

Application configuration repositories should test only their own composition, such as retaining
inherited colors and tool settings. Product installation and native tool checks belong here rather
than requiring a particular dotfiles checkout.

## Native tweak preview

The ordinary Lua gate exercises namespace isolation, draft editing/export, late callbacks, foreign
theme takeover, reload and scratch-buffer cleanup, including modified work without its old tab.
It checks the complete global highlight map with parsers unavailable and compares rendered normal
colors after last-window reuse. Plain-text fallback does not establish real language captures.

With the seven sample parsers and their highlight queries already installed, run:

```sh
FLUME_TS_RUNTIME=/path/to/treesitter-runtime \
    nvim --headless --clean -c "lua dofile('scripts/check-tweak.lua')"
```

The checker parses every fixture, requires a real highlighter and compares rendered screen-cell
attributes with independently checked role-color swatches in all four palettes. It edits a string
role live and keeps a contrasting global ink as a negative control. Merely reading highlight
configuration would not establish namespace resolution in actual parser output.

`FLUME_TWEAK_LANGUAGES=lua,rust,python,tsx,zig,go` selects an explicit subset when native parsers are
split across prepared runtimes. Unselected samples are not qualified. Requested missing parsers or
queries fail rather than being silently skipped. TypeScript can be checked separately with
`FLUME_TWEAK_LANGUAGES=typescript`. No tools or grammars are installed by this command.

## Snapshot and color evidence

[Showcase](showcase.md) owns the pinned capture environment, scene inventory, source/image sidecars,
exact comparisons and update rules. Linux Ghostty captures do not qualify macOS Ghostty or Kitty
rendering. Selection, tabs and live reload remain separate native observations.

[Integration review](integration-review.md) measures actual exported foreground/background pairs and
contrast targets. HTML color previews are not native screenshots or automatic aesthetic approval.
Review selected/matched text, inactive controls, diffs and light palettes in context.

The generated [palette manifest](palette-manifest.md) owns exact canonical roles and tested contrast
pairs. Preserve it as generated output rather than reformatting or hand-editing it.

## Hosted CI

[Quality](../.github/workflows/quality.yml) runs `./scripts/check` on Neovim 0.9.5 and stable.
Snapshots run once in a separate Linux job, not once per Neovim version. Its comparison report is
retained for seven days. A workflow definition or local commit is not evidence that a hosted run
passed.

Report the source or artifact, command, observed result and missing evidence. Configuration-contract
checks, parser captures, native rendering and actual reload observations establish different facts.
