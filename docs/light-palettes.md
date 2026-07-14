# Light palettes

Opal and Mesa are deliberate light appearances, not mechanical inversions of
their dark counterparts.

| Palette | Background | Surface | Strong surface | Character |
| --- | --- | --- | --- | --- |
| **Opal** (`flume-opal`) | `#f2eff7` | `#ebe6f0` | `#ddd6e3` | Vivid Flume inks on cool opalescent paper |
| **Mesa** (`flume-mesa`) | `#f3ede8` | `#ebe3de` | `#ded4d1` | Warm rose-mineral paper with restrained inks |

Both use neutral, low-chroma comment inks. Opal uses `#706b70`; Mesa uses
`#6f6a6f` against its warmer foundation. Documentation comments use `#6c686d`
in both palettes.

Normal syntax foregrounds meet 4.5:1 contrast on their declared backgrounds.
ANSI white remains a visible foreground rather than paper white. Diff surfaces
remain subordinate to text, and comments are not italicized unless configured
through `styles.comments`.

Exact values and contrast pairs are generated in the [palette
manifest](palette-manifest.md). The origins of Mira and Mesa are documented in
[palette origins](palette-origins.md).

## Configuration

```lua
require("flume").setup({ schema = "opal" })
```

Flume intentionally exposes role-level overrides instead of a global saturation
percentage. Chroma transforms would also require gamut mapping, contrast
revalidation, and profile-aware generated extras.

```lua
require("flume").setup({
    schema = "mesa",
    overrides = {
        syntax_comment = "#777177",
        syntax_keyword = "#693990",
    },
})
```
