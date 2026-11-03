# Mesa examples

Light palette with faint violet-gray paper, ochre types, deeper violet keywords, petrol-blue calls, jade
strings and lighter berry fields.
[Compare palettes](../gallery.md) · [Design ideas](../color-system.md#palette-direction).

[Go](#go) · [Working states](#diagnostics-and-working-states) · [Completion](#completion) ·
[LSP](#lsp) · [Integrations](#integrations) · [More languages](#more-languages)

## Go

[Compare palettes](../languages/go.md#mesa)

![Mesa Go syntax](../../assets/screenshots/mesa/go.png)

## More languages

<details>
<summary>Rust, Python, TypeScript/TSX, Zig, Elixir and TOML</summary>

## Rust

[Compare palettes](../languages/rust.md#mesa)

![Mesa Rust syntax](../../assets/screenshots/mesa/rust.png)

## Python

[Compare palettes](../languages/python.md#mesa)

![Mesa Python syntax](../../assets/screenshots/mesa/python.png)

## TypeScript

[Compare palettes](../languages/tsx.md#mesa)

![Mesa TypeScript and TSX syntax](../../assets/screenshots/mesa/tsx.png)

## Zig

[Compare palettes](../languages/zig.md#mesa)

![Mesa Zig syntax](../../assets/screenshots/mesa/zig.png)

## Elixir

[Compare palettes](../languages/elixir.md#mesa)

![Mesa Elixir syntax](../../assets/screenshots/mesa/elixir.png)

## TOML

[Compare palettes](../languages/toml.md#mesa)

![Mesa TOML syntax](../../assets/screenshots/mesa/toml.png)

</details>

## Diagnostics and working states

Real diff panes, changed words, search matches, selection, and fixture diagnostics with signs,
underlines, and virtual text.

![Mesa diagnostics, selection, search, and diffs](../../assets/screenshots/selection/mesa/go.png)

## Completion

Real gopls candidates in Blink's bordered menu with syntax-highlighted documentation.

![Mesa completion menu](../../assets/screenshots/completion/mesa/go.png)

## LSP

These captures combine Tree-sitter, semantic tokens, and server-provided hover signatures from gopls
and ZLS. Diagnostics are suppressed here.
[Capture provenance and supported versions](../showcase.md#working-state-and-lsp-captures).

### Go with gopls

![Mesa Go with gopls](../../assets/screenshots/lsp/mesa/go.png)

### Zig with ZLS

![Mesa Zig with ZLS](../../assets/screenshots/lsp/mesa/zig.png)

## Integrations

[Setup recipes](../workflows.md#external-tools) · [Lualine setup](../workflows.md#lualine). These
snapshots use real apps through Linux Ghostty; Pi/OpenCode restore synthetic offline sessions. They
do not qualify macOS Ghostty or Kitty rendering.

### Lualine

![Mesa with the Flume lualine theme](../../assets/screenshots/lualine/mesa/go.png)

### Neo-tree

![Mesa Neo-tree sidebar with icons and Git state](../../assets/screenshots/neotree/mesa/go.png)

### Terminal apps

![Mesa Tmux](../../assets/screenshots/integrations/tmux/mesa.png)
![Mesa LSD](../../assets/screenshots/integrations/lsd/mesa.png)
![Mesa OpenCode](../../assets/screenshots/integrations/opencode/mesa.png)
![Mesa Lazygit](../../assets/screenshots/integrations/lazygit/mesa.png)
![Mesa fzf](../../assets/screenshots/integrations/fzf/mesa.png)
![Mesa Delta](../../assets/screenshots/integrations/delta/mesa.png)
![Mesa Pi](../../assets/screenshots/integrations/pi/mesa.png)

Matching configuration files:

| Integration | Mesa configuration                                       |
| ----------- | -------------------------------------------------------- |
| Ghostty     | [Theme](../../extras/ghostty/flume-mesa)                 |
| Kitty       | [Theme](../../extras/kitty/flume-mesa.conf)              |
| Tmux        | [Theme](../../extras/tmux/colors-mesa.conf)              |
| LSD         | [Colors](../../extras/lsd/colors-mesa.yaml)              |
| OpenCode    | [Theme](../../extras/opencode/flume-mesa.json)           |
| Lazygit     | [Theme](../../extras/lazygit/flume-mesa.yml)             |
| fzf         | [Options](../../extras/fzf/flume-mesa.opts)              |
| Delta       | [Configuration](../../extras/delta/flume-mesa.gitconfig) |
| Pi          | [Theme](../../extras/pi/flume-mesa.json)                 |
