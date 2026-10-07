# Opal examples

Light palette with a cool paper canvas. [All galleries](../gallery.md).

[Go](#go) · [Rust](#rust) · [Python](#python) · [TypeScript](#typescript) ·
[Zig](#zig) · [Elixir](#elixir) · [TOML](#toml) ·
[Diagnostics and working states](#diagnostics-and-working-states) ·
[Completion](#completion) · [LSP](#lsp) · [Integrations](#integrations)

## Go

[Compare all themes](../languages/go.md#opal)

![Opal Go syntax](../../assets/screenshots/opal/go.png)

## Rust

[Compare all themes](../languages/rust.md#opal)

![Opal Rust syntax](../../assets/screenshots/opal/rust.png)

## Python

[Compare all themes](../languages/python.md#opal)

![Opal Python syntax](../../assets/screenshots/opal/python.png)

## TypeScript

[Compare all themes](../languages/tsx.md#opal)

![Opal TypeScript and TSX syntax](../../assets/screenshots/opal/tsx.png)

## Zig

[Compare all themes](../languages/zig.md#opal)

![Opal Zig syntax](../../assets/screenshots/opal/zig.png)

## Elixir

[Compare all themes](../languages/elixir.md#opal)

![Opal Elixir syntax](../../assets/screenshots/opal/elixir.png)

## TOML

[Compare all themes](../languages/toml.md#opal)

![Opal TOML syntax](../../assets/screenshots/opal/toml.png)

## Diagnostics and working states

Real diff panes, changed words, search matches, selection, and fixture diagnostics
with signs, underlines, and virtual text.

![Opal diagnostics, selection, search, and diffs](../../assets/screenshots/selection/opal/go.png)

## Completion

Native completion menu alongside the same diff and diagnostic fixture.

![Opal completion menu](../../assets/screenshots/completion/opal/go.png)

## LSP

These captures combine Tree-sitter with semantic tokens from gopls and ZLS.
Diagnostics are suppressed here to isolate provider coloring.
[Capture provenance and supported versions](../showcase.md#working-state-and-lsp-captures).

### Go with gopls

![Opal Go with gopls](../../assets/screenshots/lsp/opal/go.png)

### Zig with ZLS

![Opal Zig with ZLS](../../assets/screenshots/lsp/opal/zig.png)

## Integrations

[Setup recipes](../workflows.md#external-tools) · [Lualine setup](../workflows.md#lualine).
These snapshots use real apps through VHS; Pi/OpenCode restore synthetic offline
sessions. They do not prove native Ghostty/Kitty rendering.

### Lualine

![Opal with the Flume lualine theme](../../assets/screenshots/lualine/opal/go.png)

### Terminal apps

![Opal Tmux](../../assets/screenshots/integrations/tmux/opal.png)
![Opal LSD](../../assets/screenshots/integrations/lsd/opal.png)
![Opal OpenCode](../../assets/screenshots/integrations/opencode/opal.png)
![Opal Lazygit](../../assets/screenshots/integrations/lazygit/opal.png)
![Opal fzf](../../assets/screenshots/integrations/fzf/opal.png)
![Opal Delta](../../assets/screenshots/integrations/delta/opal.png)
![Opal Pi](../../assets/screenshots/integrations/pi/opal.png)

Matching configuration files:

| Integration | Opal configuration |
| --- | --- |
| Ghostty | [Theme](../../extras/ghostty/flume-opal) |
| Kitty | [Theme](../../extras/kitty/flume-opal.conf) |
| Tmux | [Theme](../../extras/tmux/colors-opal.conf) |
| LSD | [Colors](../../extras/lsd/colors-opal.yaml) |
| OpenCode | [Theme](../../extras/opencode/flume-opal.json) |
| Lazygit | [Theme](../../extras/lazygit/flume-opal.yml) |
| fzf | [Options](../../extras/fzf/flume-opal.opts) |
| Delta | [Configuration](../../extras/delta/flume-opal.gitconfig) |
| Pi | [Theme](../../extras/pi/flume-opal.json) |
