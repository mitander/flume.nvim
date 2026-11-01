# Dusk examples

Dark palette with a violet background, amber types, teal functions and lavender keywords.
[Compare palettes](../gallery.md) · [Design ideas](../color-system.md#palette-direction).

[Go](#go) · [Working states](#diagnostics-and-working-states) · [Completion](#completion) ·
[LSP](#lsp) · [Integrations](#integrations) · [More languages](#more-languages)

## Go

[Compare palettes](../languages/go.md#dusk)

![Dusk Go syntax](../../assets/screenshots/dusk/go.png)

## More languages

<details>
<summary>Rust, Python, TypeScript/TSX, Zig, Elixir and TOML</summary>

## Rust

[Compare palettes](../languages/rust.md#dusk)

![Dusk Rust syntax](../../assets/screenshots/dusk/rust.png)

## Python

[Compare palettes](../languages/python.md#dusk)

![Dusk Python syntax](../../assets/screenshots/dusk/python.png)

## TypeScript

[Compare palettes](../languages/tsx.md#dusk)

![Dusk TypeScript and TSX syntax](../../assets/screenshots/dusk/tsx.png)

## Zig

[Compare palettes](../languages/zig.md#dusk)

![Dusk Zig syntax](../../assets/screenshots/dusk/zig.png)

## Elixir

[Compare palettes](../languages/elixir.md#dusk)

![Dusk Elixir syntax](../../assets/screenshots/dusk/elixir.png)

## TOML

[Compare palettes](../languages/toml.md#dusk)

![Dusk TOML syntax](../../assets/screenshots/dusk/toml.png)

</details>

## Diagnostics and working states

Real diff panes, changed words, search matches, selection, and fixture diagnostics with signs,
underlines, and virtual text.

![Dusk diagnostics, selection, search, and diffs](../../assets/screenshots/selection/dusk/go.png)

## Completion

Real gopls candidates in Blink's bordered menu with syntax-highlighted documentation.

![Dusk completion menu](../../assets/screenshots/completion/dusk/go.png)

## LSP

These captures combine Tree-sitter, semantic tokens, and server-provided hover signatures from gopls
and ZLS. Diagnostics are suppressed here.
[Capture provenance and supported versions](../showcase.md#working-state-and-lsp-captures).

### Go with gopls

![Dusk Go with gopls](../../assets/screenshots/lsp/dusk/go.png)

### Zig with ZLS

![Dusk Zig with ZLS](../../assets/screenshots/lsp/dusk/zig.png)

## Integrations

[Setup recipes](../workflows.md#external-tools) · [Lualine setup](../workflows.md#lualine). These
snapshots use real apps through Linux Ghostty; Pi/OpenCode restore synthetic offline sessions. They
do not qualify macOS Ghostty or Kitty rendering.

### Lualine

![Dusk with the Flume lualine theme](../../assets/screenshots/lualine/dusk/go.png)

### Neo-tree

![Dusk Neo-tree sidebar with icons and Git state](../../assets/screenshots/neotree/dusk/go.png)

### Terminal apps

![Dusk Tmux](../../assets/screenshots/integrations/tmux/dusk.png)
![Dusk LSD](../../assets/screenshots/integrations/lsd/dusk.png)
![Dusk OpenCode](../../assets/screenshots/integrations/opencode/dusk.png)
![Dusk Lazygit](../../assets/screenshots/integrations/lazygit/dusk.png)
![Dusk fzf](../../assets/screenshots/integrations/fzf/dusk.png)
![Dusk Delta](../../assets/screenshots/integrations/delta/dusk.png)
![Dusk Pi](../../assets/screenshots/integrations/pi/dusk.png)

Matching configuration files:

| Integration | Dusk configuration                                       |
| ----------- | -------------------------------------------------------- |
| Ghostty     | [Theme](../../extras/ghostty/flume-dusk)                 |
| Kitty       | [Theme](../../extras/kitty/flume-dusk.conf)              |
| Tmux        | [Theme](../../extras/tmux/colors-dusk.conf)              |
| LSD         | [Colors](../../extras/lsd/colors-dusk.yaml)              |
| OpenCode    | [Theme](../../extras/opencode/flume-dusk.json)           |
| Lazygit     | [Theme](../../extras/lazygit/flume-dusk.yml)             |
| fzf         | [Options](../../extras/fzf/flume-dusk.opts)              |
| Delta       | [Configuration](../../extras/delta/flume-dusk.gitconfig) |
| Pi          | [Theme](../../extras/pi/flume-dusk.json)                 |
