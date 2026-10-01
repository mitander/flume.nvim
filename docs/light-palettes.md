# Light palettes

Choose **Opal** for vivid inks on cool opalescent paper, or **Mesa** for restrained
inks on warm rose-mineral paper. Neither is a mechanical inversion of a dark
palette.

```lua
require("flume").setup({ schema = "opal" })
```

Both use neutral comment inks and subordinate diff backgrounds. Normal syntax
foregrounds meet 4.5:1 contrast on their declared backgrounds. ANSI white remains
a visible foreground; comments are not italicized unless configured through
`styles.comments`.

Exact colors and tested contrast pairs belong to the [palette
manifest](palette-manifest.md). See [palette origins](palette-origins.md) for
Mesa's design rationale.

## Configuration

Use `schema = "mesa"` to select Mesa. Customize individual roles through
`overrides`; Flume does not expose a global saturation transform.

See the [README configuration example](../README.md#configure) and
[reference manual](../doc/flume.txt) for options.
