# Mira and Mesa palette origins

Mira and Mesa began with accent relationships explored for `kapsel.cloud`.
They are independent Flume palettes, not exports of that website's CSS variables.

## Design decision

Keep the relationships between accents, but rebuild surfaces and color intensity
for dense editor text. Directly copying the website canvas produced green-slate
and olive backgrounds; its full-strength logo accents competed in syntax.

Mira uses violet-charcoal surfaces. Mesa uses warm rose-mineral surfaces.
Both keep ordinary identifiers neutral and assign color by role:

- cyan: functions and focus;
- coral: literals and special punctuation;
- amber: types and warnings;
- violet: keywords and control flow;
- magenta: namespaces, properties, and errors;
- teal: strings, additions, and success;
- blue: information and hints.

## Foundation hierarchy

Dark and light palettes share semantic roles, not inverted RGB values. Surfaces
stay close in luminance; selections and active controls use stronger surfaces.
Neutral text carries the reading hierarchy. Light palettes use darker inks to
meet text contrast targets.

## Semantic anchors

Small editor text uses mixed accents rather than pure logo colors. See the
[generated palette manifest](palette-manifest.md) for exact values and tested
contrast pairs.

## Diff and diagnostic surfaces

Diff backgrounds mix semantic colors with the palette foundation at low chroma.
Emphasis colors sit between those backgrounds and the state foregrounds, so
state remains recognizable without overpowering text.

The editor palette is owned by [`lua/flume/palette.lua`](../lua/flume/palette.lua).
Mapping rules and contrast targets are in the [color system](color-system.md).
