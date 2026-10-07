# Mesa examples

Light palette with a warm paper canvas. [All galleries](../gallery.md).

[Go](#go) · [Rust](#rust) · [Python](#python) · [TypeScript](#typescript) ·
[Zig](#zig) · [Elixir](#elixir) · [TOML](#toml) ·
[Diagnostics and working states](#diagnostics-and-working-states) ·
[Completion](#completion) · [LSP](#lsp) · [Integrations](#integrations)

## Go

[Compare all themes](../languages/go.md#mesa)

![Mesa Go syntax](../../assets/screenshots/mesa/go.png)

## Rust

[Compare all themes](../languages/rust.md#mesa)

![Mesa Rust syntax](../../assets/screenshots/mesa/rust.png)

## Python

[Compare all themes](../languages/python.md#mesa)

![Mesa Python syntax](../../assets/screenshots/mesa/python.png)

## TypeScript

[Compare all themes](../languages/tsx.md#mesa)

![Mesa TypeScript and TSX syntax](../../assets/screenshots/mesa/tsx.png)

## Zig

[Compare all themes](../languages/zig.md#mesa)

![Mesa Zig syntax](../../assets/screenshots/mesa/zig.png)

## Elixir

[Compare all themes](../languages/elixir.md#mesa)

![Mesa Elixir syntax](../../assets/screenshots/mesa/elixir.png)

## TOML

[Compare all themes](../languages/toml.md#mesa)

![Mesa TOML syntax](../../assets/screenshots/mesa/toml.png)

## Diagnostics and working states

Real diff panes, changed words, search matches, selection, and fixture diagnostics
with signs, underlines, and virtual text.

![Mesa diagnostics, selection, search, and diffs](../../assets/screenshots/selection/mesa/go.png)

## Completion

Native completion menu alongside the same diff and diagnostic fixture.

![Mesa completion menu](../../assets/screenshots/completion/mesa/go.png)

## LSP

These captures combine Tree-sitter with semantic tokens from gopls and ZLS.
Diagnostics are suppressed here to isolate provider coloring.
[Capture provenance and supported versions](../showcase.md#working-state-and-lsp-captures).

### Go with gopls

![Mesa Go with gopls](../../assets/screenshots/lsp/mesa/go.png)

### Zig with ZLS

![Mesa Zig with ZLS](../../assets/screenshots/lsp/mesa/zig.png)

## Integrations

[Setup recipes](../workflows.md#external-tools) · [Lualine setup](../workflows.md#lualine).
These snapshots use real apps through VHS; Pi/OpenCode restore synthetic offline
sessions. They do not prove native Ghostty/Kitty rendering.

### Lualine

![Mesa with the Flume lualine theme](../../assets/screenshots/lualine/mesa/go.png)

### Terminal apps

![Mesa Tmux](../../assets/screenshots/integrations/tmux/mesa.png)
![Mesa LSD](../../assets/screenshots/integrations/lsd/mesa.png)
![Mesa OpenCode](../../assets/screenshots/integrations/opencode/mesa.png)
![Mesa Lazygit](../../assets/screenshots/integrations/lazygit/mesa.png)
![Mesa fzf](../../assets/screenshots/integrations/fzf/mesa.png)
![Mesa Delta](../../assets/screenshots/integrations/delta/mesa.png)
![Mesa Pi](../../assets/screenshots/integrations/pi/mesa.png)

Matching configuration files:

| Integration | Mesa configuration |
| --- | --- |
| Ghostty | [Theme](../../extras/ghostty/flume-mesa) |
| Kitty | [Theme](../../extras/kitty/flume-mesa.conf) |
| Tmux | [Theme](../../extras/tmux/colors-mesa.conf) |
| LSD | [Colors](../../extras/lsd/colors-mesa.yaml) |
| OpenCode | [Theme](../../extras/opencode/flume-mesa.json) |
| Lazygit | [Theme](../../extras/lazygit/flume-mesa.yml) |
| fzf | [Options](../../extras/fzf/flume-mesa.opts) |
| Delta | [Configuration](../../extras/delta/flume-mesa.gitconfig) |
| Pi | [Theme](../../extras/pi/flume-mesa.json) |
