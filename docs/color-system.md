# Flume color system

A line of code can contain a function, a type, several variables and a field access. Giving every
name a different color adds activity, but does not necessarily explain the line. Flume reserves
color for a few recurring distinctions and leaves ordinary identifiers neutral.

Consider this Go fragment:

```go
func findUser(id int) User {
    return users[id]
}
```

The function name and types use different color families. Keywords mark the control structure. `id`
and `users` stay in the ordinary text color. You can follow the names without every repeated
variable adding another accent. The [Go gallery](languages/go.md) shows the same idea in context.

The same restraint applies outside code. A diagnostic or selection needs to be noticeable without
requiring the rest of the editor to become brighter. Backgrounds, ordinary text and state colors
therefore have different jobs.

## Palettes, roles and themes

A **palette** is a complete named set of colors: Dusk, Opal, Mira or Mesa. The Lua option `schema`
selects that name. It is not a separate kind of theme.

A **role** names a color's job, such as `syntax_function`, `selection_bg` or `error`. A Neovim
highlight group uses those roles to color part of the editor. For example, `Function` uses the
function role. External **themes** map the same palette roles to another application's settings.

Changing a role is different from changing a terminal color slot. An error may share a red hue with
ANSI red, but its meaning and override remain independent. This is what lets a light palette change
its UI without treating every red item as an error or every green panel as a successful operation.

The [generated palette manifest](palette-manifest.md) lists exact role values and tested contrast
pairs. The sections below explain the design and the mapping rules behind them.

## Palette direction

Dusk, Opal, Mira and Mesa share semantic roles but may assign different hue families to them.
Provider mappings and contrast targets stay consistent. Dusk and Mira use related violet dark
canvases with different ink intensity. Opal uses cool lilac paper, while Mesa uses quieter,
nearly neutral violet-gray paper and restrained mineral inks.

**Dusk** retains its violet dark canvas with amber types, teal functions, purple keywords, sage
strings, rose-red properties and softened coral literals. Clearer fields balance the warm type and
literal accents. State colors and ANSI inks carry stronger emphasis than ordinary syntax. Refining
this palette preserves those established color relationships rather than turning them into pastels.

**Mira** is the more open, easygoing dark palette, with a slightly lifted blue-violet canvas.
Matte honey types, sky-blue calls, lavender keywords, rose-red fields and namespaces, mint strings
and peach literals provide gentle landmarks rather than competing accents. Nearly achromatic text
avoids a blue cast, while lower-luminance syntax avoids an evenly bright pastel band without
changing the canvas. Honey and peach keep their warm relationship. Rose-red fields gain a little
chroma at essentially the same lightness. Types and calls still lead fields and secondary ink.
Comments and punctuation use readable neutral grays, retaining the contrast target on diff surfaces.
Coral-red errors and gold warnings keep stronger emphasis.
UI focus and informational states retain their independent teal ink.
Raised surfaces, cursor lines, statuslines and active rows stay quiet and close to the canvas.

The dark palettes are close relatives rather than unrelated hue collections. Dusk keeps a deeper
violet foundation, while Mira softens contrast between syntax families on a lighter, less violet
canvas without sacrificing text readability. Both retain independent ANSI and file-icon
inks. These can carry more color emphasis than source text without changing syntax or diagnostic
roles. Review them on terminal output, picker icons and exported diff surfaces rather than forcing
their RGB values to match syntax.

**Opal** pairs light lilac paper with deep apricot types, vivid violet keywords, pink-berry fields
and imports, copper literals, eucalyptus strings and clear blue functions. Apricot replaces the
gold that dominated type-heavy code without introducing another blue family. It is a darkened
peach-family ink, not Mira's pale peach copied onto light paper. Types and copper literals share a
warm family, balanced by blue calls, violet keywords and green strings. The intended balance is
colorful, not uniformly muted. Light lilac cursor-line and raised surfaces separate from the airy
canvas, with a deeper pink-lilac statusline tier. Both tiers and the pale green, gold, rose and blue
diff fills retain readable syntax ink. Amber warnings keep their independent yellow fill.

**Mesa** uses nearly neutral violet-gray paper, with deeper violet keywords, ochre types,
petrol-blue calls, clear jade strings and lighter berry fields and namespaces. Hue and lightness
both separate these families rather than clustering every ink into one dark band. Ochre remains
one local accent rather than an undertone across the whole editor. The canvas, raised surfaces,
cursor lines, statuslines and active rows share the faint cool tint, replacing the warm paper and
clay-colored panels. Both raised tiers retain readable comment contrast. These inks stay independent
of diagnostics, success colors and UI focus. A slightly darker, less chromatic canvas and restrained
mineral inks distinguish Mesa from Opal without requiring a warm/cool split between light palettes.

Choose by light or dark surroundings, canvas tint and ink intensity. There is no
language-specific palette: a function has the same role whether you are reading Go or Rust. The
[gallery](gallery.md) compares all four on the same fixtures.

Review balance in type-heavy code with few strings as well as mixed examples. Repeated named types
and constructors can dominate a real file even when a short, string-rich specimen looks balanced.
Keep useful counterweights in frequently occurring roles rather than depending on rare literals or
changing correct language-provider mappings to conceal a palette imbalance.

Light palettes are not inverted dark palettes. Pale backgrounds leave less room for a lighter
selection or diff fill, so they need dark text and deliberately chosen foreground/background pairs.
Dark palettes have more room for pastel syntax, but their ordinary text still does not need to be
white. The roles stay consistent while the RGB values and contrast relationships change.

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
5. **Palette identity.** A palette may change hue and chroma without changing provider role
   assignments or surface hierarchy. Balance repeated syntax in complete files, not just swatches.
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

Lazygit active rows use `element_active` with `selectedLineFgColor: ["default"]`, retaining filename
and Git-status inks. Do not put `selection_fg` on that quiet surface.

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

Delta and Lazygit's Delta pager retain ANSI syntax inks on `diff_add_bg`, `diff_delete_bg`,
`diff_add_emphasis`, and `diff_delete_emphasis`. These fills target 4.5:1 with ordinary terminal
text and ANSI slots 1–7 and 9–15. Slots 0 and 8 remain specialized black/decorative inks, not the
syntax foreground contract. Changed words are also underlined because light palettes leave little
luminance room for a stronger fill. OpenCode's add/delete labels appear on the canvas. Its brighter
diff signs, body text and retained syntax inks are checked on the actual diff fills.

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

Comments use low-chroma gray inks, readable but secondary to ordinary code. Documentation
comments share the same ink so long prose blocks do not compete with syntax accents. Both roles
retain the syntax contrast target on canvas, raised, cursor-line, and diff surfaces rather than
fading toward placeholder text.

Named constants use `syntax_constant`, sharing the neutral `syntax_primary` ink in every palette.
Uppercase identifiers remain distinguishable without competing with function calls. Numbers,
booleans, and built-in constants retain `syntax_boolean`; tags and symbol literals use
`syntax_special` to preserve their accent independently of named constants.

Specific Tree-sitter captures and LSP token types resolve through these families. Provider mappings
follow these rules:

- Constructors use `syntax_type`; they create typed values rather than behaving like ordinary
  functions. TypeScript and TSX `new` expressions share this rule. JSX component and native-element
  names retain their tag captures instead of recoloring every TSX constructor as a tag. Go factory
  calls named `New...` or `Make...` remain ordinary functions, despite the query's naming-based
  constructor capture. Composite literals retain their type captures.
- LSP `typeParameter` tokens use each palette's neutral identifier ink, distinguishing a parameter
  such as `T` from a named type such as `Box` without adding another accent family. This is not
  literal white or a comment-like dimming rule. Parser-only highlighting retains the type capture
  when its queries cannot distinguish parameters from named types. Do not guess symbol identity
  from names.
- Receiver captures for Rust `self`, Python `self`/`cls`, Lua `self`, and TypeScript/TSX
  `this`/`super` use neutral identifier ink. The TypeScript queries also place built-in object
  references in this family. More specific call, property and module captures still win. Literal
  captures remain accented, and other languages keep their existing built-in-variable fallback.
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
independently reviewable. The set covers Go factory calls, Lua table constructors, Python namespaces, Rust enum
constructors, receiver captures, and Zig's legacy built-in fallback. ZLS namespace tokens
use the generic namespace role. Languages that are represented correctly by the generic Tree-sitter
and LSP groups should not receive an empty override file.

### Integration colors

Plugin integrations must resolve visible colors through semantic roles instead of accepting
plugin-provided named colors. Actions and key bindings use `accent`; descriptions and secondary
metadata use `muted`; search matches use `match`; retained-ink active rows use `element_active`;
explicit selected text uses the `selection_fg` / `selection_bg` pair; success and version-control
state use their corresponding semantic roles. This prevents light-mode defaults such as fzf-lua's
`MediumSpringGreen` from leaking into any schema.

Pi keeps successful tool results on the neutral `surface` and pending tools on `surface_alt`.
Failures retain their tinted error panel. Routine success should not turn a transcript into large
green blocks or borrow version-control addition fills.

### File icon colors

`icon_neutral`, `icon_red`, `icon_copper`, `icon_orange`, `icon_yellow`, `icon_green`, `icon_cyan`,
`icon_blue`, `icon_purple`, and `icon_pink` provide stable file-icon hue families. Every palette
defines these roles explicitly, independently of syntax and ANSI slots. Light palettes keep gold,
orange and copper separate. Copper is redder and darker than orange, giving an earthy rust ink its
own family without changing brighter orange icons. Dusk and Mira retain softer shades of those same
families.

Consumers assign file types to families once, then resolve the selected palette's `icon_*` role. For
example, a consumer can use blue for Python, copper for Rust, purple for Lua, gold for JavaScript,
cyan for Go, and pink for Gleam. Brand colors are not mandatory. Review source, declaration,
compiled and configuration companions together so an alias does not gain an unrelated color. Assign
aliases sharing an icon highlight identity to the same family. Keep unreviewed formats quiet rather
than inferring their meaning from upstream RGB. Currently, consumers supply the file-type inventory
and the adapter that applies these roles.

The selected direction, not yet implemented, is an opt-in `nvim-web-devicons` integration with a
Flume-owned, reviewed identity-to-family catalog. Highlight definitions alone are insufficient:
consumers such as fzf-lua read provider RGB data and cache it across same-background palette
switches. Flume will own the provider updates, highlight agreement and picker-cache invalidation
needed to keep those colors coherent, while preserving upstream terminal fallbacks and restoring
pre-theming provider colors when another colorscheme takes over. This deliberately accepts upstream
catalog review as a maintenance responsibility. Unreviewed identities stay neutral, without RGB
classification. Picker layouts and file-discovery policy remain consumer-owned. Until the
integration ships, the inventory and adapter remain consumer-supplied.

Icon inks target 3:1 on the canvas, raised surfaces, cursor line, and retained-ink active rows. Keep
a filename or distinct glyph alongside color. Strong selections that replace foregrounds should use
`selection_fg` instead. The manifest records canvas and active-row contrast pairs. Tests also
preserve hue ranges, copper/orange hue and luminance separation, and separation between gold/orange
and blue/cyan. These checks prevent family collapse, but do not establish perceptual distinction for
every viewer or renderer. Review glyphs at actual picker size, together with filenames and selected
rows, across all palettes. Hundreds of file types cannot each have a unique hue. Distinct glyphs and
coherent identity families matter more than making every icon colorful.

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
representative Zig, Rust, Python, TypeScript, TSX, Go, and Elixir sources from `examples/`, plus
focused receiver, constructor, binding and generic-fallback specimens including Lua. It checks
actual captures and effective role colors in all four palettes.

Install the corresponding parsers and queries, then run from the repository root:

```sh
FLUME_TS_RUNTIME=/path/to/treesitter-runtime \
    nvim --headless --clean -c "lua dofile('scripts/check-highlights.lua')"
```

Replace the example path with a runtime containing `parser/` and `queries/`. This lane does not run
language servers or replace the parser-free `./scripts/check` gate.

With Go and gopls installed, separately check real semantic tokens:

```sh
nvim --headless --clean -c "lua dofile('scripts/check-semantic-tokens.lua')"
```

This uses a private Go module, home and caches with dependency and toolchain downloads disabled.
It checks generic declarations and references against named-type, function, factory-call and
literal controls in every palette. Field tokens vary across gopls versions: older versions can
emit broad variable tokens that defer to the separately checked parser roles. It observes actual gopls tokens and their resolved highlight roles,
not rendered pixels or other language servers. The pinned snapshot lane runs both checkers.

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
