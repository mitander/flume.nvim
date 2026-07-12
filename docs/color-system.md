# Flume color system

Flume uses one resolved color table, but its roles belong to four distinct layers. Keeping those layers separate makes overrides predictable and gives a future light palette the same semantic contract.

## Principles

1. **Quiet foundation.** Surfaces stay close in luminance so the editor recedes behind the code.
2. **Semantic color.** Diagnostics, diffs, matches, and syntax use named roles rather than terminal color slots.
3. **Controlled saturation.** Stronger color marks state or structure; ordinary identifiers remain neutral.
4. **Stable hierarchy.** Color families keep the same meaning across Tree-sitter, LSP, plugins, and generated extras.
5. **Explicit contrast.** Primary text and filled labels target 4.5:1 contrast. State-bearing secondary text and boundaries target 3:1 where the subdued design allows it.

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
- Broad LSP variable tokens defer to Tree-sitter, which can distinguish calls, members, and other syntactic roles more precisely. Python namespace tokens also defer because language servers commonly apply them to imported modules, classes, and callables alike.
- Import keywords follow namespaces, word-like operators follow punctuation, and preprocessor directives follow attributes. This keeps keyword-heavy languages from collapsing into one dominant hue.

Exact group overrides remain available for further language-specific exceptions. Such exceptions should correct a parser or language-server mismatch, not establish a new language-specific color system.

Language-qualified corrections live in `lua/flume/languages/`, one file per language, so they remain independently reviewable. The initial set covers Lua table constructors, Python namespaces, Rust enum constructors, TSX component constructors, and zls namespace behavior. Languages that are represented correctly by the generic Tree-sitter and LSP groups should not receive an empty override file.

### Terminal colors

`black` through `bright_white` are the sixteen ANSI slots. They are terminal primitives, not diagnostic or diff roles. The explicit `dim_*` values are retained as palette primitives for future terminal and integration work.

## Invariants

- Palette values are explicit `#RRGGBB` colors.
- Semantic state highlights do not consume ANSI roles directly.
- `on_accent` is never made transparent.
- `overrides` are applied after the base palette resolves.
- User `highlights` are applied last and therefore win.
- Generated extras compile from the canonical palette, not editor-local overrides.
