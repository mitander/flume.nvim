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

Specific Tree-sitter captures and LSP token types resolve through these families. Exact group overrides remain available for language-specific exceptions.

### Terminal colors

`black` through `bright_white` are the sixteen ANSI slots. They are terminal primitives, not diagnostic or diff roles. The explicit `dim_*` values are retained as palette primitives for future terminal and integration work.

## Invariants

- Palette values are explicit `#RRGGBB` colors.
- Semantic state highlights do not consume ANSI roles directly.
- `on_accent` is never made transparent.
- `overrides` are applied after the base palette resolves.
- User `highlights` are applied last and therefore win.
- Generated extras compile from the canonical palette, not editor-local overrides.
