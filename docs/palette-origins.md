# Mira and Mesa palette origins

Mira and Mesa began with accent relationships explored for `kapsel.cloud`, a
separate downstream project. Their public names describe independent Flume
palettes: neither is a Kapsel theme or a direct export of website CSS variables.

A website can support large branded color fields, illustrations, and sparse
accent use. An editor holds dense text against the same background for hours.
Copying the website canvas (`#282e34` / `#e5e2d9`) directly made the schemas read
green-slate and olive at editor scale, while copying the full logo accents made
syntax groups compete with one another.

## Design decision

Keep the source design's **relationships between accents**, then rebuild the
neutral foundations and color intensity for an editor:

- violet-charcoal dark surfaces replace the green-slate website canvas;
- warm rose-mineral light surfaces replace the yellow-green canvas cast;
- neutral identifiers carry the code's reading flow;
- cyan marks functions and structural affordances;
- coral marks literals and special punctuation;
- amber marks types and warnings;
- violet marks keywords and control flow;
- magenta marks namespaces, properties, and errors;
- teal marks strings, additions, and success;
- blue marks information and hints.

This follows the same method as the built-in Flume schemas: inspiration defines
the atmosphere and semantic vocabulary, while editor-specific surfaces,
contrast, and hierarchy determine the final colors.

## Foundation hierarchy

| Role | Mira | Mesa | Reasoning |
| --- | --- | --- | --- |
| Background | `#24212f` | `#f3ede8` | Quiet violet/mineral foundation without a green cast |
| Active line | `#2b2838` | `#ebe3de` | Visible through luminance, not a saturated tint |
| Raised surface | `#292634` | `#ebe3de` | Close to the canvas so panes do not become cards |
| Strong surface | `#353142` | `#ded4d1` | Reserved for selections and active controls |
| Primary text | `#d9d4df` | `#423d47` | Warm neutral reading path |
| Secondary text | `#cbc5d2` | `#58515d` | Lower emphasis without becoming faint |
| Muted text | `#918a9a` | `#706976` | Comments and peripheral UI |
| Focus accent | `#72b5bf` | `#356f80` | Source cyan, mixed for the target background |

Dark and light are paired by role rather than by mechanically inverting RGB
values. Both preserve the same temperature and semantic assignments, but light
mode uses darker, less saturated inks to meet text contrast requirements.

## Semantic anchors

| Meaning | Mira | Mesa | Source idea |
| --- | --- | --- | --- |
| Error / deletion | `#dd789b` | `#974c68` | Logo magenta |
| Warning / change | `#d8a36b` | `#80541f` | Logo orange |
| Success / addition | `#84b39f` | `#4b6d65` | Brand teal |
| Information / hint | `#72a8c7` | `#356a83` | Brand blue |
| Keyword | `#b69bd2` | `#6c538b` | Project-metadata violet |
| Function / accent | `#72b5bf` | `#356f80` | Cyan interaction accent |

The website's pure logo colors remain appropriate for logos, fills, artwork, and
large state marks. The editor uses mixed versions because small text needs both
contrast and restraint.

## Diff and diagnostic surfaces

Diff backgrounds are low-chroma mixtures of each semantic color with the theme
foundation. They should be perceived after the text, not before it. Emphasis
colors sit between those backgrounds and the foreground semantic anchors.

This is why additions are not bright green panels and deletions are not vivid
magenta panels: the state remains recognizable without breaking long-session
readability.

## If kapsel.cloud adopts the improvements

Treat these as possible **foundation tokens**, not as a generated copy of the
editor palette:

| Website role | Dark option | Light option |
| --- | --- | --- |
| Canvas | `#24212f` | `#f3ede8` |
| Surface | `#292634` | `#ebe3de` |
| Strong surface | `#353142` | `#f8f5f3` |
| Text | `#d9d4df` | `#423d47` |
| Body | `#cbc5d2` | `#58515d` |
| Muted | `#918a9a` | `#706976` |
| Boundary | `#4b485a` | `#c8c0c4` |
| Text accent | `#72b5bf` | `#356f80` |

Before changing the website:

1. capture both themes at desktop, mobile, and 320 px;
2. keep the existing pure Kapsel colors for the logo and meaningful large fills;
3. use the mixed semantic colors for small text;
4. recheck normal-text, control-boundary, and focus-ring contrast;
5. compare the glitch artwork and receipt surfaces—the new violet foundation
   changes how their accent colors are perceived.

The schema source of truth for the editor remains
[`lua/flume/palette.lua`](../lua/flume/palette.lua). The broader role contract is
in [`color-system.md`](color-system.md).
