# The look: hand-drawn minimal

Every app on the platform reads like a neat notebook page. The paper is white (warm charcoal at night), everything is drawn in ink, and one yellow marker swipe per screen shows what matters. Headings, buttons and nav words are hand-lettered in Caveat; everything you read is set in a plain, legible face (the reading "voice" each user picks).

This is Burrow's design system (Android-Showcase, `design/burrow-a/theme`), lifted out of one Android app so that every app, on every platform, draws the same way. The wobble function is bit-for-bit Burrow's, so a divider in a Flutter app and in Burrow's Compose code are the same line.

| Where | What |
| --- | --- |
| [`tokens.json`](tokens.json) | The source of truth: colours (light and dark), type, handwriting voices, spacing, stroke, motion |
| [`doodles.json`](doodles.json) | The 35 hand-drawn icons as SVG paths on a 24×24 grid |
| `packages/base_design` | The Flutter implementation: theme, components, doodles, fonts |
| `generated/` | The same tokens for non-Flutter apps: CSS (Spreix), Kotlin (Burrow), Swift (iOS widgets), SVG doodles |

Change a value in `tokens.json` or `doodles.json`, run `./base gen`, and every app picks it up on its next build. Never edit generated files.

## Rules (tokens 2.0.0)

The hand-drawn look stays; hand-lettering is for headings and buttons, and everything you read is a plain, legible sans. The reasons and the measurements are in [`REVIEW.md`](REVIEW.md).

1. **You read in the body face. You tap, and you find your place, in hand-lettering.** Caveat is for the app's own short words: the wordmark, page titles, section heads, rows that name a place in the app ("models", "privacy"), buttons, links and nav words. Four words or fewer.
2. **Caveat is never smaller than 24.** There is no `small` style.
3. **Data and user content are never hand-lettered.** Names of talks, people, models and files, article titles, memory facts, numbers with units, dates and times are in the body face. One exception: a single big figure (a record timer) at `display` size.
4. **Sentences are ink.** `pencil` is for meta lines of at most two lines. `graphite` is for placeholders and disabled things only; nothing that informs is graphite.
5. **Nothing readable is below 13.** Body is 16, long-form reading 17.
6. **Two weights in the body face: 400 and 600.** Every voice has both.
7. **Line length 45–75 characters, never under 28.** A text column next to a control is at least 200 wide; otherwise the control goes on its own line below the text (`ItemRow(below: …)`).
8. **One marker per screen, on a fact.** A number or one or two words, at most 16 characters (`MarkedText` asserts it). Never a page title by default, a tag row or a sentence.
9. **Red pen is a mark, not a paragraph.** Red is for the destructive button or link and the `!` doodle. A warning is an ink sentence with a red `!` in front.
10. **Wobble belongs to strokes, not to text.** Dividers, underlines, circles, progress, doodles and the marker swipe wobble; text sits on a straight baseline with nothing behind it but the marker or a flat smudge.
11. **Lowercase is for hand-lettered app words.** Body sentences are sentence case. Proper nouns and data keep their capitals everywhere ("ask Burrow", "Gemma 4 E2B", "Voz").
12. **No boxes around text.** Content sits on the paper, not on cards; group with a section head and space. The only fill is the smudge behind inputs, done notes and selected rows. No shadows or gradients.
13. **Every tap target is at least 48×48.** One ink pill per screen, at most three doodle buttons in a top row, at most four nav words.
14. **Spacing comes from the scale** (4, 8, 12, 16, 24, 40, 64). A section head has 40 above and 12 below.

And from before, still true: every page opens with a `PageIntro` (its name and one plain sentence); live rows end in an arrow; no hidden gestures; flows say their steps up front (`Steps`, `StepHead`); after something happens, say so and offer the next step (`DoneNote`); a switch is never used for something that can't be switched back; every animation goes through `context.motion(...)`; text tells the truth with real numbers.

## Which style for what

| What | Style | Colour |
| --- | --- | --- |
| Wordmark, welcome statement, record timer | `display` 52/58 | ink |
| Page title | `headline` 38/42 | ink |
| Section head, sheet title, empty-state line | `title` 30/34 | ink |
| A row that leads to a place in the app; switch titles | `door` 24/28 | ink |
| Buttons, links, nav words, choice pills | `label` 24/28 | ink (paper on the ink pill) |
| Title of a talk, article, person on its own page | `contentTitle` 22/28 600 | ink |
| Title of a content row (talk, person, model, file) | `rowTitle` 17/24 600 | ink |
| Summaries, transcripts, chat answers, article text | `reading` 17/26 | ink |
| Sentences, intros, field text, list items | `body` 16/24 | ink |
| Second line of a row, notes under a head | `meta` 14/20 | pencil |
| Timestamps, counts, sizes, "on this device" | `caption` 13/18 | pencil |
| Tags, step numbers, badges | `tag` 13/18 600 | ink |
| Placeholders like `[NAME_1]`, tool calls, logs | `mono` 13/20 | ink |
| Placeholder text in a field, disabled labels | the style of the live text | graphite |

The first five are Caveat; the rest are in the reading voice. Hand styles grow with the OS text size up to 1.3×; body styles follow it fully. Font sizes appear only in `tokens.json`: `./base check` fails on `fontSize:` in app code.

## Reading voices and light/dark

Headlines are always Caveat. The face you read in is a voice the user picks in *settings → handwriting*:

| Voice | Font |
| --- | --- |
| **friendly** (default) | Nunito 400/600 |
| formal | Inter 400/600 |
| neat hand | Shantell Sans, informality 0, 400/600 |

"loose hand" and "all handwritten" were removed in 2.0.0. Settings saved before 2.0 are moved to friendly once (`BaseSettings`, `typeVersion: 2`), and the settings page says so once; a stored retired voice maps to neat hand.

*settings → light or dark* is like the device, light, or dark, independent of the OS. Dark is a warm "night notebook", not white on black. Chart and person colours have a lifted dark set (`context.colors.series(i)`).

All fonts are bundled (SIL Open Font License, texts in `packages/base_design/fonts`). Monospace uses the platform's own (`Menlo`, `Roboto Mono`, `Consolas`, … from `font.mono`).

## Tokens

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| paper | `#FFFFFF` | `#1E1D1B` | Background |
| ink | `#1A1A1A` | `#E8E3D8` | Text, doodles, the ink pill (17.4:1 / 13.2:1) |
| pencil | `#555555` | `#B9B3A8` | Meta lines (7.5:1 / 8.1:1) |
| graphite | `#6B6B6B` | `#A39D92` | Placeholders and disabled only (5.3:1 / 6.3:1) |
| rule | ink at 20% | ink at 35% | Sketchy dividers; never the only edge of a control |
| smudge | `#F4F3EF` | `#2D2B28` | Input wells, selected rows, done notes, tags |
| marker | `#FFE45C` | `#D9BF45` | The single highlight; text on it is `markerInk` |
| red pen | `#C81E1E` | `#FF8A80` | Destructive actions and the `!` mark |

Every text colour is at least 4.5:1 on paper and on smudge in both themes (tested in `design_test.dart`). Spacing: 4 · 8 · 12 · 16 · 24 · 40 · 64, a 24 gutter. Sizes: 48 minimum target, ink pill 56, pills 48, fields 52, rows 56.

Wide screens: one column of 560 (`maxColumn`); long text at most 600 (`readingColumn`). From 840 a list (360) and its detail sit side by side (`TwoPane`, `context.isWide`); the detail is left-aligned with 40 padding. From 1000 the nav words become a rail on the left, 200 wide (`HandNav.rail`, picked by `BaseShell`), with the wordmark at the top and the gear and padlock at the bottom; pages are left-aligned after it.

## Components (`package:base_design`)

| Component | What it is |
| --- | --- |
| `HandPage` | The frame: a 56 top row (back doodle or wordmark, actions), a 560-wide column (centred, or left-aligned after a rail), optional sticky bottom for the ink pill (full width up to 400) |
| `HandLayout` | Tells pages they sit after a rail or in a detail pane (set by `BaseShell` and `TwoPane`) |
| `PageIntro` | Page name, one or two sentences in ink, a tilted doodle |
| `InkButton` | The one primary action. `busy`, `trailing` doodle, `danger`. Disabled: smudge, graphite outline and label |
| `PillButton`, `ChoicePill`, `HandLink`, `DoodleButton` | Secondary, radio-style, tertiary, icon-only (48dp target, tooltip) |
| `MarkedText`, `Marker` | The marker swipe behind one substring (follows line wraps), or behind any widget |
| `Door` | A row that leads to a place in the app (hand-lettered); `alert` adds the red exclamation |
| `ItemRow` | A row of content (talk, person, model, file): `rowTitle`, meta, caption, `aside` caption on the right, leading doodle or initial, `below` for a pill or progress, `selected` for list-detail |
| `Prose` | Long-form text at `reading`, at most 600 wide, selectable; renders bold, lists, quotes, code and headings (as row titles) |
| `SwitchRow`, `HandSwitch` | A drawn toggle and its row |
| `HandField` | A text well on smudge |
| `HandNav`, `HandNav.rail` | Words as navigation: along the bottom, or a rail on the left from 1000 |
| `SectionHead`, `Body`, `Meta`, `OnDeviceStamp` | Typography helpers |
| `Steps`, `StepHead`, `DoneNote`, `HandEmpty` | Flow helpers |
| `HandTag`, `PickMark`, `Snapshot` | Tags in the body face on smudge, drawn ticks, tilted photos |
| `HandDivider`, `HandProgress`, `HandUnderline`, `HandCircle` | Wobbly strokes |
| `showHandSheet`, `confirmSheet` | Bottom sheets with a squiggle handle |
| `TwoPane` | List (360) and detail side by side from 840 |
| `DoodleIcon` | The 35 doodles. Use these, never Material icons |

Read colours with `context.colors`, styles with `context.type`, and never write a hex colour or a font family in app code: `./base check` fails the build if you do. The starter app's **design** tab shows every component in the current theme and voice.

## Adding to the system

A component that two apps need goes into `packages/base_design`, not into either app. Follow the `design-system` skill: build it from tokens, add it to the starter's design tab and to `test/design_test.dart`, check it at 360 wide in light and dark with the neat hand voice (the widest), and list it in the table above.
