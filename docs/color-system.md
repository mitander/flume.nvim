# Flume color system

Flume resolves each named palette through one schema contract. Its roles belong to four distinct layers, keeping overrides predictable across all four appearances. The [palette origins](palette-origins.md) explain how downstream design work informed Mira and Mesa without owning their public names. The [generated palette manifest](palette-manifest.md) lists every exact role and tested contrast pair directly from the canonical Lua table.

## Principles

1. **Quiet foundation.** Surfaces stay close in luminance so the editor recedes behind the code.
2. **Semantic color.** Diagnostics, diffs, matches, and syntax use named roles rather than terminal color slots.
3. **Controlled saturation.** Stronger color marks state or structure; ordinary identifiers remain neutral.
4. **Stable hierarchy.** Color families keep the same meaning across Tree-sitter, LSP, plugins, and generated extras.
5. **Palette intensity.** A palette may change chroma, as Opal does, without changing semantic assignments or surface hierarchy.
6. **Explicit contrast.** Primary text and filled labels target 4.5:1 contrast. Focused, state-bearing boundaries target 3:1. Decorative separators remain intentionally quieter and do not carry state by color alone.

## Layers

### Surfaces and text

`bg`, `surface`, and `surface_alt` establish depth. `element_active` marks selections and active controls. `text`, `fg`, `muted`, and `placeholder` form the text hierarchy. `on_accent` is reserved for text rendered on a filled accent or state color.

### Semantic states

`error`, `warning`, `success`, `info`, and `match` describe application state. `diff_add`, `diff_change`, and `diff_delete` describe version-control state. Their default values may share hues with ANSI colors, but users can override them independently.

### Syntax

| Family | Roles |
| --- | --- |
| Neutral | `syntax_primary`, `syntax_comment`, `syntax_doc_comment` |
| Structure | `syntax_function`, `syntax_type`, `syntax_keyword`, `syntax_namespace` |
| Values | `syntax_string`, `syntax_boolean`, `syntax_constant`, `syntax_property` |
| Detail | `syntax_attribute`, `syntax_special`, `syntax_punctuation*` |

Specific Tree-sitter captures and LSP token types resolve through these families. Provider mappings follow these rules:

- Constructors use `syntax_type`; they create typed values rather than behaving like ordinary functions.
- Enumeration members remain `syntax_constant` by default because most language servers model them as values. A language-qualified override may use `syntax_type` when a server also uses that token for constructors, as rust-analyzer does for enum variants.
- Modules and namespaces use `syntax_namespace`. Any workaround for an inaccurate language-server token must be language-qualified rather than weakening the generic group.
- Broad LSP variable tokens defer to Tree-sitter, which can distinguish calls, members, and other syntactic roles more precisely. Readonly and static modifiers do not turn ordinary bindings or fields into constants. Python namespace tokens also defer because some servers apply them to imported modules, classes, and callables alike.
- Import keywords follow namespaces, word-like operators follow punctuation, and preprocessor directives follow attributes. This keeps keyword-heavy languages from collapsing into one dominant hue.

Exact group overrides remain available for further language-specific exceptions. Such exceptions should correct a parser or language-server mismatch, not establish a new language-specific color system.

Language-qualified corrections live in `lua/flume/languages/`, one file per language, so they remain independently reviewable. The set covers Lua table constructors, Python namespaces, Rust enum constructors, TSX component constructors, and Zig's legacy built-in fallback. ZLS namespace tokens use the generic namespace role. Languages that are represented correctly by the generic Tree-sitter and LSP groups should not receive an empty override file.

### Integration colors

Plugin integrations must resolve visible colors through semantic roles instead of accepting plugin-provided named colors. Actions and key bindings use `accent`; descriptions and secondary metadata use `muted`; search matches use `match`; selections use `element_active`; success and version-control state use their corresponding semantic roles. This prevents light-mode defaults such as fzf-lua's `MediumSpringGreen` from leaking into any schema.

### Terminal colors

`black` through `bright_white` are the sixteen ANSI slots. They are terminal primitives, not diagnostic or diff roles. The explicit `dim_*` values are retained as palette primitives for future terminal and integration work.

## Invariants

- Palette values are explicit `#RRGGBB` colors.
- Semantic state highlights do not consume ANSI roles directly.
- `on_accent` is never made transparent.
- `overrides` are applied after the base palette resolves.
- User `highlights` are applied last and therefore win.
- Generated extras compile from the canonical palette, not editor-local overrides.
- Global saturation/chroma transforms are not a v0.2.0 API; exact role-level overrides remain the supported customization boundary.

## Verify language highlighting

Role-definition tests do not prove which captures a parser emits. The optional
native lane opens representative Zig, Rust, Python, TypeScript, TSX, Go, and
Elixir sources from `examples/` and checks actual captures in all four palettes.

Install the corresponding parsers and queries, then run from the repository root:

```sh
FLUME_TS_RUNTIME=/path/to/treesitter-runtime \
    nvim --headless --clean -c "lua dofile('scripts/check-highlights.lua')"
```

Replace the example path with a runtime containing `parser/` and `queries/`.
This lane does not run language servers or replace the parser-free
`./scripts/check` gate.

For LSP-backed checks, open the same fixtures with the relevant server and use
`:Inspect`. Inspect semantic token modifiers as well as their base types.

| Language | Expected distinction |
| --- | --- |
| Zig | Tree-sitter treats `std` as a variable at the call site and `debug` as a member. ZLS can resolve both as namespaces; `print` remains a function. |
| Rust | Tree-sitter uses constant roles for enum variants; rust-analyzer's enum-member tokens use the type role for constructors. |
| Python | Types and constructors use the type role; methods and members remain distinct. Pyright may provide no semantic tokens. |
| TypeScript / TSX | Ordinary `const` bindings stay neutral. Namespace tokens use the namespace role; component tags keep their tag role. |
| Go | Fields use the property role, methods use the function role, and gopls can resolve package qualifiers as namespaces. |
| Elixir | Module aliases, function calls, atoms, and ordinary variables use distinct roles. |

## Regenerate the manifest

After changing `lua/flume/palette.lua`, regenerate the exact roles and contrast
pairs from the repository root:

```sh
nvim --headless --clean -c "lua dofile('scripts/generate-palette-manifest.lua')"
```

This updates `docs/palette-manifest.md`. Run `./scripts/check` to verify it matches
the palette source.
