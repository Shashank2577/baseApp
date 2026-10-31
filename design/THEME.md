# The look: hand-drawn minimal

Every app on the platform reads like a neat notebook page. The paper is white (warm charcoal at night), everything is drawn in ink, and one yellow marker swipe per screen shows what matters. Headings are hand-lettered in Caveat; the explanations sit quietly underneath in the handwriting "voice" each user picks.

This is Burrow's design system (Android-Showcase, `design/burrow-a/theme`), lifted out of one Android app so that every app, on every platform, draws the same way. The wobble function is bit-for-bit Burrow's, so a divider in a Flutter app and in Burrow's Compose code are the same line.

| Where | What |
| --- | --- |
| [`tokens.json`](tokens.json) | The source of truth: colours (light and dark), type, handwriting voices, spacing, stroke, motion |
| [`doodles.json`](doodles.json) | The 35 hand-drawn icons as SVG paths on a 24×24 grid |
| `packages/base_design` | The Flutter implementation: theme, components, doodles, fonts |
| `generated/` | The same tokens for non-Flutter apps: CSS (Spreix), Kotlin (Burrow), Swift (iOS widgets), SVG doodles |

Change a value in `tokens.json` or `doodles.json`, run `./base gen`, and every app picks it up on its next build. Never edit generated files.

## Principles

1. **Each screen has one idea and one ink pill.** One `InkButton` per screen. Anything secondary is a `PillButton`; anything minor is a `HandLink`.
2. **Only one thing gets the marker.** The yellow swipe goes behind a single word or number per screen ("2.4 GB", "nothing", "once"). If two things are highlighted, neither stands out.
3. **Content sits on the paper, not on cards.** No cards, gradients or shadows. Sections are separated by white space and sketchy hairlines (`HandDivider`). The only fill is the pale smudge behind inputs and done notes.
4. **Words do the navigation.** The bottom bar is two to four hand-lettered words (`HandNav`); the current one gets a loose circle that draws itself in. No icon tab bars.
5. **Photos are snapshots.** Small, white border, slightly tilted, 2dp lift (`Snapshot`). Private photos are always blurred.
6. **The red pen is only for private or destructive things.** `alert` on a `Door`, `danger` on an `InkButton`, *wipe everything*.
7. **The text tells the truth.** "recoverable for 30 days", "nothing of yours left this device" with the real byte count, "shared with 2 other apps".

## UX rules

1. **Every page says what it's for.** A `PageIntro` opens each page: its name and one plain sentence.
2. **Anything tappable looks tappable.** Live rows (`Door`) end in a circled arrow; rows that lead nowhere are drawn in pencil with no arrow.
3. **No hidden gestures.** No long-press, no tap-on-title. Choices are drawn (`PickMark`), and every action is a visible button.
4. **Flows say their steps up front** (`Steps`), and number the stages of a page (`StepHead`).
5. **After something happens, say so and offer the next step** (`DoneNote`). Failures say what to do.
6. **Permissions show their state.** A switch is never used for something that can't be switched back off.
7. **Respect reduced motion.** Every animation goes through `context.motion(...)`, which is zero when the OS asks for less motion.

## Handwriting voices and light/dark

Headlines are always Caveat. The quieter text is a voice the user picks in *settings → handwriting*:

| Voice | Font | Scale |
| --- | --- | --- |
| formal | Inter | 1.00 |
| friendly | Nunito | 1.02 |
| **neat hand** (default) | Shantell Sans, informality 0 | 0.98 |
| loose hand | Shantell Sans, informality 100 | 0.98 |
| all handwritten | Patrick Hand | 1.14 |

*settings → light or dark* is like the device, light, or dark, independent of the OS. The status-bar icons follow the app's choice. Dark is a warm "night notebook", not white on black: thin strokes bloom and the marker glares on pure black.

All fonts are bundled (SIL Open Font License, texts in `packages/base_design/fonts`), so the look works offline.

## Tokens

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| paper | `#FFFFFF` | `#1E1D1B` | Background |
| ink | `#1A1A1A` | `#E8E3D8` | Text, doodles, the ink pill |
| pencil | `#6B6B6B` | `#B9B3A8` | Meta and secondary text |
| graphite | `#A3A3A3` | `#948E84` | Placeholders, disabled |
| rule | ink at 15% | ink at 30% | Sketchy dividers |
| smudge | `#F4F3EF` | `#2D2B28` | Input wells, selected rows, done notes |
| marker | `#FFE45C` | `#D9BF45` | The single highlight; text on it is `markerInk` |
| red pen | `#DC2626` | `#FF8A80` | Private and destructive only |

Type: Caveat display 52, headline 40, title 30, door 26, label 21, small 18; body 15/22 and meta 13/18 in the user's voice; monospace 12 for `[NAME_1]` and timestamps. Spacing: 4 · 8 · 16 · 24 · 40 · 64, a 24 gutter and a 560 max column. Lists and details sit side by side from 700 wide (`TwoPane`, `context.isWide`).

## Components (`package:base_design`)

| Component | What it is |
| --- | --- |
| `HandPage` | The frame: top row (back doodle or wordmark, actions), a centred 560-wide column, optional sticky bottom for the ink pill |
| `PageIntro` | Page name (marker optional), one sentence, a tilted doodle |
| `InkButton` | The one primary action. `busy`, `trailing` doodle, `danger` |
| `PillButton`, `ChoicePill`, `HandLink`, `DoodleButton` | Secondary, radio-style, tertiary, icon-only (48dp target, tooltip) |
| `MarkedText`, `Marker` | The marker swipe behind one substring (follows line wraps), or behind any widget |
| `Door` | A list row that leads somewhere; `alert` adds the red exclamation |
| `SwitchRow`, `HandSwitch` | A drawn toggle and its row |
| `HandField` | A text well on smudge |
| `HandNav` | The words-as-navigation bottom bar |
| `SectionHead`, `Body`, `Meta`, `OnDeviceStamp` | Typography helpers |
| `Steps`, `StepHead`, `DoneNote`, `HandEmpty` | Flow helpers |
| `HandTag`, `PickMark`, `Snapshot` | Labels, drawn ticks, tilted photos |
| `HandDivider`, `HandProgress`, `HandUnderline`, `HandCircle` | Wobbly strokes |
| `showHandSheet`, `confirmSheet` | Bottom sheets with a squiggle handle |
| `TwoPane` | List and detail side by side on wide screens |
| `DoodleIcon` | The 35 doodles. Use these, never Material icons |

Read colours with `context.colors`, styles with `context.type`, and never write a hex colour or a font family in app code: `./base check` fails the build if you do. The starter app's **design** tab shows every component in the current theme and voice.

## Adding to the system

A component that two apps need goes into `packages/base_design`, not into either app. Follow the `design-system` skill: build it from tokens, add it to the starter's design tab and to `test/design_test.dart`, check it at 360 wide in light and dark with the handwritten voice (the widest), and list it in the table above.
