# Flume color system

Flume uses the same semantic roles across all four palettes. This guide explains those roles and the
mapping rules for contributors and custom consumers. The
[generated palette manifest](palette-manifest.md) lists exact values and tested contrast pairs from
the canonical Lua table.

## Palette direction

The V1 set contains four palettes: Dusk, Opal, Mira, and Mesa. Dusk keeps its violet canvas, amber
types, sage strings, dusty rose properties, and teal functions. Muted amber types and softened coral
literals keep repeated warm accents from dominating, while state colors and ANSI inks stay stronger.
Mira uses near-neutral charcoal surfaces with mineral blue functions and sea-glass strings.
Muted berry properties, sand types, and copper literals provide restrained warmth rather than
competing bright accents.
Opal pairs cool lilac paper with purple types and keywords, red fields and imports, copper literals,
sea-glass strings, and softened teal functions. Types stay in the purple family rather than adding
another warm accent beside red fields. The inks retain contrast on raised and diff surfaces, not
only on the canvas. Amber warning ink sits on a clearer yellow fill, independent of syntax colors.
Mesa pairs softer rose-gray paper with restrained mineral inks.
Mesa's slight mauve undertone avoids a yellow cast without making it a second Opal. Dusk and Opal
carry the stronger violet character, while Mira and Mesa provide more neutral foundations.
Light palettes use darker foregrounds, not inverted dark-palette RGB values.

Mira and Mesa retain the same function, type, keyword, string, and berry families. Their ink
mixtures and foundations differ; neither is an inversion of a dark or light sibling. The manifest
lists the exact colors.

The palettes are still evolving. Color changes should address readability or mapping problems while
preserving each palette's identity. Record significant visual changes in the
[changelog](../CHANGELOG.md).

## Principles

1. **Quiet foundation.** Surfaces stay close in luminance so the editor recedes behind the code.
2. **Semantic color.** Diagnostics, diffs, matches, and syntax use named roles rather than terminal
   color slots.
3. **Controlled saturation.** Stronger color marks state or structure; ordinary identifiers remain
   neutral.
4. **Stable hierarchy.** Color families keep the same meaning across Tree-sitter, LSP, plugins, and
   generated extras.
5. **Palette intensity.** A palette may change chroma, as Opal does, without changing semantic
   assignments or surface hierarchy.
6. **Explicit contrast.** Syntax text targets 4.5:1 on the canvas, cursor line, raised surfaces, and
   diff surfaces. Selected text uses a separate pair targeting 4.5:1; its fill targets 3:1 against
   the canvas and raised surfaces. Menu text, diagnostic virtual text, and filled labels also target
   4.5:1. Focused, state-bearing boundaries target 3:1. Decorative separators remain intentionally
   quieter and do not carry state by color alone.

## Layers

### Surfaces and text

`bg`, `surface`, and `surface_alt` establish depth. `element_active` is a quiet active-control
surface that retains syntax inks. `selection_bg` and `selection_fg` form a stronger pair for Visual
selection, completion selection, command-line menus, and terminal selection. These states replace
the original text color; they do not require brighter syntax throughout the palette.

`text` and `fg` are primary inks. `muted` renders readable secondary content, including hidden and
ignored filenames, fold controls, inactive status text, exported metadata, and quoted prose.
`placeholder` is for decoration or intentionally suppressed content, not filenames. `on_accent` is
reserved for text rendered on a filled accent or state color.

### Semantic states

`error`, `warning`, `success`, `info`, and `match` describe application state. `diff_add`,
`diff_change`, and `diff_delete` describe version-control state. Their default values may share hues
with ANSI colors, but users can override them independently. `diff_text_bg` marks changed words
while retaining syntax foregrounds. It is distinct from `diff_change_bg` and does not consume an
ANSI ink.

Search uses `match` text on `warn_bg`, with an underline. Current matches use bold, underlined
`text` on `diff_text_bg`. Visual selection replaces both the foreground and background while
retaining the search underline.

### Syntax

| Family    | Roles                                                                   |
| --------- | ----------------------------------------------------------------------- |
| Neutral   | `syntax_primary`, `syntax_comment`, `syntax_doc_comment`                |
| Structure | `syntax_function`, `syntax_type`, `syntax_keyword`, `syntax_namespace`  |
| Values    | `syntax_string`, `syntax_boolean`, `syntax_constant`, `syntax_property` |
| Detail    | `syntax_attribute`, `syntax_special`, `syntax_punctuation*`             |

Comments use low-chroma cool-gray ink, readable but secondary to ordinary code. Documentation
comments share the same ink so long prose blocks do not compete with syntax accents. Both roles
retain the syntax contrast target on canvas, raised, cursor-line, and diff surfaces rather than
fading toward placeholder text.

Specific Tree-sitter captures and LSP token types resolve through these families. Provider mappings
follow these rules:

- Constructors use `syntax_type`; they create typed values rather than behaving like ordinary
  functions.
- Enumeration members remain `syntax_constant` by default because most language servers model them
  as values. A language-qualified override may use `syntax_type` when a server also uses that token
  for constructors, as rust-analyzer does for enum variants.
- Modules and namespaces use `syntax_namespace`. Any workaround for an inaccurate language-server
  token must be language-qualified rather than weakening the generic group.
- Broad LSP variable tokens defer to Tree-sitter, which can distinguish calls, members, and other
  syntactic roles more precisely. Readonly and static modifiers do not turn ordinary bindings or
  fields into constants. Python namespace tokens also defer because some servers apply them to
  imported modules, classes, and callables alike.
- Import keywords follow namespaces, word-like operators follow punctuation, and preprocessor
  directives follow attributes. Legacy `Include`, `PreProc`, `Define`, and `PreCondit` follow the
  same roles.
- Macro names use the function family across legacy syntax, Tree-sitter, and LSP. String escapes use
  the special family, matching `SpecialChar`.

These mappings keep keyword-heavy languages from collapsing into one dominant hue.

Exact group overrides remain available for further language-specific exceptions. Such exceptions
should correct a parser or language-server mismatch, not establish a new language-specific color
system.

Language-qualified corrections live in `lua/flume/languages/`, one file per language, so they remain
independently reviewable. The set covers Lua table constructors, Python namespaces, Rust enum
constructors, TSX component constructors, and Zig's legacy built-in fallback. ZLS namespace tokens
use the generic namespace role. Languages that are represented correctly by the generic Tree-sitter
and LSP groups should not receive an empty override file.

### Integration colors

Plugin integrations must resolve visible colors through semantic roles instead of accepting
plugin-provided named colors. Actions and key bindings use `accent`; descriptions and secondary
metadata use `muted`; search matches use `match`; retained-ink active rows use `element_active`;
explicit selected text uses the `selection_fg` / `selection_bg` pair; success and version-control
state use their corresponding semantic roles. This prevents light-mode defaults such as fzf-lua's
`MediumSpringGreen` from leaking into any schema.

### Terminal colors

`black` through `bright_white` are the sixteen ANSI slots. They are terminal primitives, not
diagnostic or diff roles. The explicit `dim_*` values provide quieter ANSI-related inks, including
staged GitSigns.

## Invariants

- Palette values are explicit `#RRGGBB` colors.
- Semantic state highlights do not consume ANSI roles directly.
- `on_accent` is never made transparent.
- Global `overrides` are applied after the base palette resolves.
- The selected `schema_overrides[schema]` are applied after global overrides.
- User `highlights` are applied last and therefore win.
- Generated extras compile from the canonical palette, not editor-local overrides.
- Customization uses exact role overrides, not global saturation or chroma transforms.
- Contrast tests cover default opaque palettes. Transparency, user overrides, and terminal opacity
  require review against the actual rendered background.

## Verify language highlighting

Role-definition tests do not prove which captures a parser emits. The optional native lane opens
representative Zig, Rust, Python, TypeScript, TSX, Go, and Elixir sources from `examples/` and
checks actual captures in all four palettes.

Install the corresponding parsers and queries, then run from the repository root:

```sh
FLUME_TS_RUNTIME=/path/to/treesitter-runtime \
    nvim --headless --clean -c "lua dofile('scripts/check-highlights.lua')"
```

Replace the example path with a runtime containing `parser/` and `queries/`. This lane does not run
language servers or replace the parser-free `./scripts/check` gate.

For LSP-backed checks, open the same fixtures with the relevant server and use `:Inspect`. Inspect
semantic token modifiers as well as their base types.

| Language         | Expected distinction                                                                                                                             |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| Zig              | Tree-sitter treats `std` as a variable at the call site and `debug` as a member. ZLS can resolve both as namespaces; `print` remains a function. |
| Rust             | Tree-sitter uses constant roles for enum variants; rust-analyzer's enum-member tokens use the type role for constructors.                        |
| Python           | Types and constructors use the type role; methods and members remain distinct. Pyright may provide no semantic tokens.                           |
| TypeScript / TSX | Ordinary `const` bindings stay neutral. Namespace tokens use the namespace role; component tags keep their tag role.                             |
| Go               | Fields use the property role, methods use the function role, and gopls can resolve package qualifiers as namespaces.                             |
| Elixir           | Module aliases, function calls, atoms, and ordinary variables use distinct roles.                                                                |

Do not infer live highlighting from hand-assigned screenshot colors. Canonical
[captures](showcase.md) use actual Tree-sitter queries and record their runtime.

## Regenerate the manifest

After changing `lua/flume/palette.lua`, regenerate the exact roles and contrast pairs from the
repository root:

```sh
nvim --headless --clean -c "lua dofile('scripts/generate-palette-manifest.lua')"
```

This updates `docs/palette-manifest.md`. Run `./scripts/check` to verify it matches the palette
source.
