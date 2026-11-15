# Readability review and the new readable system

Reviewed 15 November 2026 against `design/tokens.json` 1.0.0, `packages/base_design`, Burrow 3.3 (Android-Showcase) and PhoneDots 0.8. This file is a spec. Nothing in any app was changed.

**The decision in one paragraph.** The hand-drawn look stays, but hand-lettering goes back to being a heading and a button, and everything you actually read becomes a plain, clearly legible sans. Today almost every sentence on a page is 13–15sp grey handwriting, and anything bigger is cursive Caveat. From 2.0.0 the default reading face is Nunito at 16sp in ink, Caveat is never smaller than 24sp and never carries data or user content, grey text is darker, the two most handwritten voices are removed, and nothing readable is below 13sp. Pages get about 15–20% taller. That is the price, and it is worth paying.

## How this was checked

Every screen was rendered and looked at:

- baseApp: the starter app and the `base_core` pages at 390×844 @3x, light and dark, in all five voices, plus 1280×800.
- PhoneDots: 19 screens in demo mode with realistic content, light and dark.
- Burrow: the 69 committed PNGs in `Android-Showcase/design/burrow-a/theme/shots` and `explorations`.

Screenshots are in the session scratchpad (temporary; re-render with the tests in `tests/`):

```
/tmp/claude-0/-home-user/2752f20a-abf8-59b2-9fe6-fa1c6c8db9cb/scratchpad/shots/
  baseapp/    phonedots/    burrow/    sheets/    proposal/    tests/    README.txt
```

File names below are relative to that folder. `proposal/old-vs-new-light.png` and `-dark.png` show the same content in the current and the proposed system side by side; look at those first.

Contrast ratios are WCAG 2 ratios computed from the token hex values. Font measurements were read from the bundled `.ttf` files (x-height from the `x` glyph, average advance over an English sentence).

---

## 1. Findings, most damaging first

### 1. The text people read is the smallest, greyest and most decorated text on the page

On a typical page the only ink-black text is the Caveat headings. The sentences are `body` 15/22 or `meta` 13/18, in the default voice Shantell Sans, and most of them are `pencil` grey.

- `PageIntro` draws its purpose sentence with `Body(purpose, color: c.pencil)`. So the first paragraph of every page is grey (`baseapp/light-08-models.png`, `phonedots/light-17-diagnostics.png`: five grey lines, `burrow/21-ask-setup.png`).
- `Meta` is 13sp `pencil`. Burrow uses `bodySmall` (13sp) 19 times and 11–12sp label styles 13 times; PhoneDots uses `bodySmall` 19 times. In `phonedots/light-11-models.png` every word that describes a model is 13sp.
- `pencil` on `paper` is 5.33:1 in light (4.80:1 on `smudge`). It passes AA on paper, but for thin 13sp strokes of a handwriting font it reads as faint. It fails AA inside wells.
- Shantell Sans is 11% wider than Nunito (average advance 0.508em against 0.456em) with a bouncing rhythm. It is a good label face and a tiring paragraph face. In `sheets/ba-voices.png` the same page in Inter or Nunito reads at a glance; the default is the third column.

### 2. Caveat is used far below the size where it can be read, and for data

Caveat's x-height is 0.36em. Inter's is 0.546em. So Caveat needs to be about 1.5× the point size to look as big:

| Caveat token | x-height | Looks like Inter at |
| --- | --- | --- |
| `small` 18 | 6.5sp | 12sp |
| `label` 21 | 7.6sp | 14sp |
| nav and ink button 23 | 8.3sp | 15sp |
| `door` 26 | 9.4sp | 17sp |

It is also slanted, connected, lowercase and has ambiguous digits (the open 4, the crossed 7, 1 against l). Where it hurts:

- Tags, the step numbers (`type.small` at 15sp in `Steps`), the note under switches, `HandLink` ("undo", "clear", "no" at 21sp).
- Data and names: `Gemma 3 270M`, `gemma 4 e2b · 2.6 GB`, `voz · 337 MB`, `0 B on this phone` (`sheets/zoom-pd-models.png`, `burrow/17-models.png`). File names: `Priya Shah(+447700900123)_20241030181205.mp3` in Caveat (`burrow/27-add-recording.png`).
- User content: saved article titles wrap to three lines of Caveat (`phonedots/light-08-saved.png`, `light-09-saved-detail.png`); memory facts are Caveat **in pencil** (`phonedots/light-14-memory.png`: "My dentist is Dr. Rao, second Tuesday of the month at 9:15").
- The navigation words are Caveat 23 in pencil. With five words (PhoneDots) `FittedBox` shrinks them further (`phonedots/light-12-you.png`).

### 3. `graphite` carries real information at 2.5:1, and the disabled primary button is unreadable

- `graphite` `#A3A3A3` on paper is 2.52:1, on `smudge` 2.27:1. It is used for placeholders in every `HandField`, for "sees · hears · uses tools · thinks" (`models_screen.dart:177`), and for the model and speed line under every chat answer (`message_view.dart:195`, visible as "demo engine" in `phonedots/light-04-chat.png`).
- A disabled `InkButton` is the whole button at 35% opacity: white on `#AFAFAF`, 2.19:1. On Burrow's ask page the main action looks like this whenever the field is empty (`burrow/22-ask.png`, `24-ask-answer.png`). The one button on the screen is the hardest thing to read.
- Dark mode has the same disabled-button problem (`proposal/old-vs-new-dark.png`, left).

### 4. The hierarchy is flat: every level is bold Caveat within a few points of each other

In use today: page title 40, sheet title 34, `title` 30, door 28, section head 27, step head 26, switch row 24, button and nav 23, label 21, small 18. Burrow's UI code hard-codes 20 different font sizes, PhoneDots 19, and `components.dart` overrides a token size in eight places.

- A section head (27) and the rows under it (28) are the same weight and size. In `phonedots/light-11-models.png` "gemma · the brain" (a section) and "gemma 4 e2b · 2.6 GB" (a row) cannot be told apart, and both wrap.
- The quiet note beside a section head collides with it and wraps: "headlines stay hand-lettered" (`baseapp/light-07-settings.png`), "what we read · 1530 characters" (`phonedots/light-09-saved-detail.png`).
- Caveat line heights are 1.04–1.1 (42/40, 33/30). The font's natural line is 1.26. Wrapped headings are cramped.

### 5. Text is squeezed beside buttons, so descriptions run four lines at 25 characters

Model rows put the description next to a 150dp download pill. The text column is about 190dp, 25 characters a line (`baseapp/light-08-models.png`, `phonedots/light-11-models.png`, `burrow/17-models.png`). On the phone the full column gives 46 characters, which is fine; the damage is done by trailing controls. Burrow's talks intro wraps around a floating record button for the same reason (`burrow/04-talks.png`).

### 6. Too much on each screen, and no clear main action

- PhoneDots chat home: a wordmark, a "demo" link and four icons in the top row, a two-line preview banner, a greeting, a three-line paragraph, six doors, a composer and five nav words. The sixth door is cut off behind the composer (`phonedots/light-03-chat-empty.png`).
- Burrow talk notes: language pill, tags, audio note, a boxed summary, decided, key points, to-dos, people and transcript in one scroll (`burrow/07-talk-notes.png`). The summary and the ask answer sit in outlined boxes, which the system's own rule 3 forbids ("no cards").
- Burrow setup: three permissions, the download, the model list and Indian languages on one page, clipped under the button (`burrow/02-ask-first.png`).
- Ten "download" pills in a column (`burrow/17-models.png`); six red "forget" pills in a column (`phonedots/light-16-privacy.png`).
- The assistant's work (thinking, steps, timings in Caveat) sits above its answer, so the answer starts half a screen down (`phonedots/light-06b-chat-top.png`).

### 7. The marker and the red pen have stopped meaning anything

- The marker is on the whole page title of models, logs, design and "the models" (`PageIntro(mark: …)`), on tags, on the selected voice, and on the fact that matters. Rule 2 says one per screen; most screens have two or three.
- Red is used for whole paragraphs of advice (`burrow/12-vault-locked.png`, `21-ask-setup.png`): 13sp red text at 4.83:1.
- In dark mode a marked heading flips to dark-on-yellow in the middle of light text; it works for one word and is heavy on a whole title (`baseapp/dark-08-models.png`).

### 8. Lowercase is applied to things that are not headings

Lowercase hand-lettered headings are part of the look. But proper nouns and data are lowercased too: "gemma 4 e2b", "voz", "english", "functiongemma 270m". Capitals are how the eye finds names in a list.

### 9. Small things that add up

- **No monospace font.** `BaseType.mono` asks for `fontFamily: 'monospace'`, which is only an alias on Android and Linux. On iOS, macOS and web it falls back to the default face. It is also 12sp pencil. The logs page is 12sp grey (`baseapp/light-10-logs.png`).
- **Tap targets.** `HandLink` is 40dp high; `HandTag` with `onTap` is 27dp; the red delete cross in memory is a bare 20dp doodle; `PillButton` is 44dp. PhoneDots has five targets in a 390dp top row.
- **`series` colours have no dark set.** `#1A1A1A` on dark paper is 1.03:1 (invisible, see the first swatch in `baseapp/dark-04-design.png`); the rest are 2.4–3.4:1.
- **Markdown is shown raw** on the starter's ask page (`**Gemma 4 E2B**`, `baseapp/light-06-ask-answer.png`). PhoneDots has a renderer (`lib/widgets/rich_text.dart`); the platform does not.
- **Wide screens.** At 1280 wide the 560 column floats in the middle while the nav words spread across the whole window (`baseapp/wide-today.png`).
- **Five voices, two of which are worse readers.** "loose hand" moves letters off the baseline; "all handwritten" (Patrick Hand) is condensed and needs a 1.14 scale to be legible (`sheets/ba-voices.png`).

### What is working and stays

Paper, ink, one accent. Doodles. Words as navigation with the drawn circle. The wobbly divider, underline and progress line. `PageIntro` giving each page a name and a sentence. Truthful copy. Dark mode's warm charcoal: its contrast is already better than light (ink 13.2:1, pencil 8.1:1).

---

## 2. The new readable system (tokens 2.0.0)

### 2.1 Rules

1. **You read in the body face. You tap, and you find your place, in hand-lettering.** Caveat is for the app's own short words: the wordmark, page titles, section heads, row titles that name a place in the app ("models", "privacy"), buttons, links and nav words. Four words or fewer.
2. **Caveat is never smaller than 24sp.** There is no `small` and no 21sp `label` any more.
3. **Data and user content are never hand-lettered.** Names of talks, people, models and files, article titles, memory facts, numbers with units, dates and times are set in the body face. One exception: a single big figure (the record timer, one hero number) at `display` size.
4. **Sentences are ink.** `pencil` is for meta lines of at most two lines. `graphite` is for placeholders and disabled things only. Nothing that informs is drawn in `graphite`.
5. **Nothing readable is below 13sp.** Body is 16, long-form reading is 17.
6. **Two weights only in the body face: 400 and 600.** All three voices have both.
7. **Line length 45–75 characters, never under 28.** A text column next to a control must be at least 200dp wide; otherwise the control goes on its own line below the text.
8. **One marker per screen, on a fact.** A number or one or two words (at most 16 characters). Never a page title by default, never a tag row, never a sentence.
9. **Red pen is a mark, not a paragraph.** Red is for the destructive button or link and the `!` doodle. A warning is an ink sentence with a red `!` in front.
10. **Wobble belongs to strokes, not to text.** Dividers, underlines, circles, progress, doodles and the marker swipe wobble. Text always sits on a straight baseline, is never tilted, and never has a stroke or texture behind it other than the marker swipe or a flat `smudge` fill.
11. **Lowercase is for hand-lettered app words.** Body sentences are sentence case. Proper nouns and data keep their capitals everywhere, including inside hand-lettering ("ask Burrow", "Gemma 4 E2B", "Voz").
12. **No boxes around text.** Summaries and answers sit on the paper. Group with a section head and space.
13. **Every tap target is at least 48×48dp.** One ink pill per screen, at most three doodle buttons in a top row, at most four nav words on a phone.
14. **Spacing comes from the scale** (4, 8, 12, 16, 24, 40, 64). 24 before a section head on a phone is not enough: use 40 above and 12 below.

### 2.2 `design/tokens.json`: the new values

Replace the listed groups with these. Groups not shown (`radius`, `stroke`, `motion`, `elevation`) do not change.

```json
{
  "version": "2.0.0",
  "color": {
    "light": {
      "paper":     { "value": "#FFFFFF" },
      "ink":       { "value": "#1A1A1A",   "use": "Text, doodles, the ink button. 17.4:1 on paper." },
      "pencil":    { "value": "#555555",   "use": "Meta lines, at most two lines. 7.5:1 on paper, 6.7:1 on smudge." },
      "graphite":  { "value": "#6B6B6B",   "use": "Placeholders and disabled only. 5.3:1 on paper, 4.8:1 on smudge." },
      "rule":      { "value": "#331A1A1A", "use": "Sketchy hairline dividers (ink at 20%). ARGB. Decoration, never the only edge of a control." },
      "smudge":    { "value": "#F4F3EF" },
      "marker":    { "value": "#FFE45C",   "use": "One swipe per screen, behind a fact." },
      "markerInk": { "value": "#1A1A1A",   "use": "13.7:1 on marker." },
      "redPen":    { "value": "#C81E1E",   "use": "Destructive actions and the ! mark. 5.7:1 on paper, 5.2:1 on smudge; paper on it 5.7:1." }
    },
    "dark": {
      "paper":     { "value": "#1E1D1B" },
      "ink":       { "value": "#E8E3D8",   "use": "13.2:1 on paper." },
      "pencil":    { "value": "#B9B3A8",   "use": "8.1:1 on paper, 6.8:1 on smudge." },
      "graphite":  { "value": "#A39D92",   "use": "Placeholders and disabled only. 6.3:1 on paper, 5.2:1 on smudge." },
      "rule":      { "value": "#59E8E3D8", "use": "Ink at 35%. ARGB." },
      "smudge":    { "value": "#2D2B28" },
      "marker":    { "value": "#D9BF45" },
      "markerInk": { "value": "#1E1D1B",   "use": "9.2:1 on marker." },
      "redPen":    { "value": "#FF8A80",   "use": "7.4:1 on paper." }
    },
    "series":     ["#1A1A1A", "#8A6D1F", "#3E6B5A", "#7A4A6B", "#4A5E85", "#9A4B3C", "#5F6B2E", "#6B6B6B"],
    "seriesDark": ["#E8E3D8", "#BD9834", "#6EA691", "#B890AC", "#8E9DBC", "#C98E82", "#92A34D", "#9B9B9B"]
  },
  "font": {
    "hand": "Caveat",
    "mono": { "family": "monospace", "fallback": ["Menlo", "SF Mono", "Roboto Mono", "Consolas", "DejaVu Sans Mono", "Courier New"] },
    "voices": [
      { "id": "friendly", "label": "friendly",  "note": "Nunito, a rounded sans",     "family": "Nunito",       "informality": null, "scale": 1.0 },
      { "id": "formal",   "label": "formal",    "note": "Inter, a crisp sans",        "family": "Inter",        "informality": null, "scale": 1.0 },
      { "id": "neat",     "label": "neat hand", "note": "Shantell Sans, marker-neat", "family": "ShantellSans", "informality": 0,    "scale": 1.0 }
    ],
    "defaultVoice": "friendly"
  },
  "type": {
    "hand": {
      "display":  { "size": 52, "lineHeight": 58, "weight": 700, "letterSpacing": -0.01 },
      "headline": { "size": 38, "lineHeight": 42, "weight": 700 },
      "title":    { "size": 30, "lineHeight": 34, "weight": 700 },
      "door":     { "size": 24, "lineHeight": 28, "weight": 600 },
      "label":    { "size": 24, "lineHeight": 28, "weight": 600 }
    },
    "body": {
      "contentTitle": { "size": 22, "lineHeight": 28, "weight": 600 },
      "reading":      { "size": 17, "lineHeight": 26, "weight": 400 },
      "rowTitle":     { "size": 17, "lineHeight": 24, "weight": 600 },
      "body":         { "size": 16, "lineHeight": 24, "weight": 400 },
      "meta":         { "size": 14, "lineHeight": 20, "weight": 400 },
      "caption":      { "size": 13, "lineHeight": 18, "weight": 400 },
      "tag":          { "size": 13, "lineHeight": 18, "weight": 600 },
      "mono":         { "size": 13, "lineHeight": 20, "weight": 400 }
    }
  },
  "space": { "xs": 4, "s": 8, "sm": 12, "m": 16, "l": 24, "xl": 40, "xxl": 64,
             "gutter": 24, "maxColumn": 560, "readingColumn": 600,
             "listPane": 360, "railWidth": 200, "twoPaneBreakpoint": 840, "railBreakpoint": 1000 },
  "size":  { "minTap": 48, "minText": 13, "minHand": 24, "inkButton": 56, "pill": 48, "field": 52,
             "icon": 24, "iconSmall": 20, "row": 56 },
  "alpha": { "faded": 0.38 }
}
```

The same change as a diff of values:

| Token | 1.0.0 | 2.0.0 | Why |
| --- | --- | --- | --- |
| `color.light.pencil` | `#6B6B6B` 5.33:1 | `#555555` 7.46:1 | Meta is thin and small; give it AAA |
| `color.light.graphite` | `#A3A3A3` 2.52:1 | `#6B6B6B` 5.33:1 | Placeholders must pass AA, also on smudge (4.80) |
| `color.light.rule` | ink 15% (1.36:1) | ink 20% (1.53:1) | Dividers were close to invisible on bright screens |
| `color.light.redPen` | `#DC2626` 4.83:1 | `#C81E1E` 5.74:1 | Passes on smudge too (5.17) |
| `color.dark.graphite` | `#948E84` 5.18 / 4.34 on smudge | `#A39D92` 6.25 / 5.24 | Fails AA in wells today |
| `color.dark.rule` | ink 30% | ink 35% | Same reason as light |
| `color.seriesDark` | none | eight colours, each ≥ 6.0:1 on dark paper | Person and chart colours were 1.0–3.4:1 |
| `font.defaultVoice` | `neat` | `friendly` | Finding 1 |
| `font.voices` | five | three: `friendly`, `formal`, `neat`; all scale 1.0 | `loose` and `handwritten` removed |
| `font.mono` | none | family plus fallback list | Finding 9 |
| `type.hand.display` | 52/54 | 52/58 | Line height |
| `type.hand.headline` | 40/42 | 38/42 | Line height 1.1; fewer wraps |
| `type.hand.title` | 30/33 | 30/34 | Line height |
| `type.hand.door` | 26/30 | 24/28 | Clear step below `title`; one size instead of 24/26/28 overrides |
| `type.hand.label` | 21/24 | 24/28 | Minimum hand size |
| `type.hand.small` | 18/21 | removed | Below minimum; replaced by `body.tag` |
| `type.body.bodyLarge` | 16/23 | removed; use `reading` 17/26 | Long-form role |
| `type.body.body` | 15/22 | 16/24 | |
| `type.body.meta` | 13/18 | 14/20 | |
| `type.body.caption`, `tag`, `rowTitle`, `contentTitle`, `reading` | none | new | Roles for data and user content |
| `type.body.mono` | 12/16 | 13/20 | |
| `space.sm` | none | 12 | The value everyone hard-codes |
| `space.twoPaneBreakpoint` | 700 | 840 | A 360 list plus a 480 detail |
| `space.readingColumn`, `listPane`, `railWidth`, `railBreakpoint` | none | 600, 360, 200, 1000 | Wide layout |
| `size.*` | none | new group | Minimum sizes as tokens |
| `alpha.disabledButton`, `alpha.disabledLink` | 0.35, 0.4 | removed | Disabled states use `graphite`, not opacity |

Measures that result: body 16sp Nunito in the 560 column is about 70 characters a line; reading 17sp in the 600 column is about 71; on a 390 phone both are 44–47.

Generator work (`tools/base_tool/lib/gen.dart`), small: emit `seriesDark`; emit `font.mono` (family and fallback list); add `size` to the groups emitted next to `space`, `radius` and `stroke` (Dart, CSS, Kotlin, Swift). New keys under `type.hand` and `type.body` and the colour changes need no generator change.

Fonts: delete `fonts/patrickhand_regular.ttf` and `OFL-patrick-hand.txt` and their `pubspec.yaml` entry. No font is added.

### 2.3 Voices

| Voice | Font | Status |
| --- | --- | --- |
| **friendly** (default) | Nunito 400/600 | Rounded, warm next to Caveat, reads cleanly at 13–17sp in both themes |
| formal | Inter 400/600 | The crispest option |
| neat hand | Shantell Sans, informality 0, 400/600 | Stays as a choice for people who want handwriting throughout |
| loose hand | Shantell Sans, informality 100 | **Removed.** Letters leave the baseline (rule 10) |
| all handwritten | Patrick Hand | **Removed.** Condensed; needed a 1.14 scale to be legible |

Migration, in `BaseSettings.load` (and the same in Burrow's and PhoneDots' settings): if the stored settings have no `typeVersion: 2`, set the voice to `friendly`, write `typeVersion: 2`. This is deliberate: every existing install has `neat` stored, so changing only the default would fix nothing. After that, a stored `loose` or `handwritten` maps to `neat`. The settings page shows a one-line `DoneNote` once: "Reading text is now a plain font. Change it under handwriting."

### 2.4 Which style for what

| What | Style | Colour |
| --- | --- | --- |
| Wordmark, welcome statement, record timer | `hand.display` | ink |
| Page title | `hand.headline` | ink |
| Section head, sheet title, empty-state line | `hand.title` | ink |
| A row that leads to a place in the app; switch titles | `hand.door` | ink |
| Buttons, links, nav words, choice pills | `hand.label` | ink (paper on the ink pill) |
| Title of a talk, article, person on its own page | `body.contentTitle` | ink |
| Title of a content row (talk, person, model, file, saved item) | `body.rowTitle` | ink |
| Summaries, transcripts, chat answers, article text | `body.reading` | ink |
| Sentences, intros, field text, list items, to-dos | `body.body` | ink |
| Second line of a row, notes under a head | `body.meta` | pencil |
| Timestamps, counts, sizes, "on this device" | `body.caption` | pencil |
| Tags, step numbers, badges | `body.tag` | ink |
| Placeholders like `[NAME_1]`, tool calls, logs | `body.mono` | ink |
| Placeholder text in a field, disabled labels | the style of the live text | graphite |

### 2.5 Components

Names are the classes in `packages/base_design/lib/src/components.dart`. Burrow's `ui/hand/HandUi.kt` has a composable of the same name for each unless noted; PhoneDots' `lib/widgets/hand.dart` likewise. Remove every `copyWith(fontSize: …)` and `fontSize = ….sp` override named below; after this change a font size appears only in tokens.

| Component | Change |
| --- | --- |
| `Meta` | `type.meta` 14/20, `pencil`. Kotlin: `bodyStyle(14f, 20f)`. |
| `Body` | `type.body` 16/24, `ink`. Remove the `color` use for whole paragraphs. Kotlin: `bodyStyle(16f, 24f)`. |
| **`Prose`** (new) | Long-form text: `type.reading` 17/26, max width `readingColumn`, 12 between paragraphs. Renders `**bold**`, `-` and `1.` lists, `>` quotes and `` `code` `` (mono). Markdown headings render as `rowTitle`, never Caveat. Selectable. Port from PhoneDots `lib/widgets/rich_text.dart`. Kotlin: new `Prose` in `HandUi.kt`. |
| `PageIntro` | Title `type.headline` 38/42. Purpose is `Body` in **ink**, one or two sentences. Gap 8, bottom 24. Doodle 32 (was 40). `mark` stays as a parameter but no shared page passes it for the whole title: remove it from `ModelsPage`, `LogsPage`, the onboarding models step and the starter's design page. |
| `SectionHead` | `type.title` 30/34 (remove the 27 override). 40 above (16 for the first on a page), 12 below. The `note` goes on its own line under the head as `Meta`, not on the right. |
| `InkButton` | Label `type.label` 24/28 (remove 23). Height `size.inkButton`. In `HandPage.bottom` it is full width up to 400. **Disabled:** `smudge` fill, 1.6 `graphite` outline, `graphite` label, no trailing doodle, opacity 1. |
| `PillButton`, `ChoicePill` | Label `type.label` 24/28. Min height `size.pill` 48 (was 44), horizontal padding 20. Disabled: `graphite` outline and label, opacity 1. |
| `HandLink` | `type.label` 24/28. Padding 12 vertical, 8 horizontal, so the target is 48 high and at least 48 wide. Disabled: `graphite`, no opacity. |
| `DoodleButton` | No change (48 target, 24–26 doodle). At most three in a top row. |
| `Door` | For the app's own places only. Title `type.door` 24/28 (remove the 28 default), at most two lines. Meta 14/20. Min height 64. Keeps the circled arrow. |
| **`ItemRow`** (new) | For content: talks, people, models, files, saved items, memory facts. Title `type.rowTitle` 17/24, two lines max. Optional meta (14/20 pencil, two lines max) and caption line (13/18 pencil). Optional leading doodle 24 or initial circle 40. Trailing: a plain `arrow` doodle 20 in pencil when it opens something, or one widget (switch, link, caption). Min height `size.row`. 12 vertical padding. Kotlin and PhoneDots: new `ItemRow`. |
| `SwitchRow` | Title `type.door` 24/28 from the token (remove the 24 override). Body `Meta` 14/20. |
| `HandField` | Text `type.body` 16/24 ink; placeholder `graphite`. Min height `size.field`. Leading doodle 20 pencil. |
| `HandTag` | Text `type.tag` 13/18 in the body face (was Caveat 18). Unmarked: `smudge` fill, no outline. Marked: `marker` fill, `markerInk`. Padding 12 × 5. With `onTap`, the hit area is padded to 48 high. |
| `OnDeviceStamp` | `type.caption` 13/18 pencil, lock 16. |
| `Steps` | Number in `type.tag` inside the 24 circle (was Caveat 15). Text `type.body` 16/24 (was 14/19). 8 between steps. |
| `StepHead` | `type.door` 24/28 (remove 26). Circle 32. |
| `DoneNote` | Text `type.body` 16/24 ink on `smudge`. The action is a `HandLink`. |
| `HandEmpty` | Title `type.title`. Body `type.body` in pencil, centred, max width 280. |
| `MarkedText`, `Marker` | Drawing unchanged. In debug, assert the marked string is at most 16 characters. |
| `HandNav` | Words `type.label` 24/28 (remove 23). Selected: ink, weight 700, drawn circle. Others: pencil, 600. Equal-width cells at least 48 high. No "·" separators. At most four words; `FittedBox` may not go below 20sp. **Wide:** from `railBreakpoint` the same words are a vertical rail on the left (`HandNav.rail`), `railWidth` wide: wordmark at the top, words 12 apart, settings and privacy doodles at the bottom. `BaseShell` picks the form. |
| `HandPage` | Column `maxColumn`. Top row 56 high. With the rail, the column is left-aligned in the remaining space with 40 padding, not centred in the window. |
| `TwoPane` | `listWidth` default `listPane` 360 (was 380). Detail content is capped at `readingColumn` and left-aligned with 40 padding. Uses the 840 breakpoint. |
| `showHandSheet`, `confirmSheet` | Title `type.title` 30/34 (remove 34). Body `type.body`. |
| `HandDivider`, `HandProgress`, `HandUnderline`, `HandCircle`, `HandSwitch`, `PickMark`, `Snapshot`, `DoodleIcon` | No change. |

Theme (`theme.dart`, Burrow `Theme.kt`, PhoneDots `lib/theme/theme.dart`):

- `BaseType`: add `contentTitle`, `reading`, `rowTitle`, `caption`, `tag`; remove `small`, `bodyLarge`, `body16`. `mono` becomes `fontFamily: monoFamily, fontFamilyFallback: monoFallback`, 13/20, **ink**.
- Material `TextTheme` mapping: `displayLarge`, `displayMedium` → display; `displaySmall`, `headlineLarge`, `headlineMedium` → headline; `headlineSmall`, `titleLarge` → title; `titleMedium` → door; `titleSmall`, `labelLarge` → label; `bodyLarge` → reading; `bodyMedium` → body; `bodySmall` → meta; `labelMedium`, `labelSmall` → caption. No 11 or 12sp style remains.
- `seriesColor(index)` takes the brightness and reads `seriesDark` in dark.
- Text scaling: body styles follow the OS text size fully; hand styles are clamped at 1.3× so headings do not push the content off the screen.

Shared pages in `base_core` (every app gets these):

- **Models.** One `ItemRow` per model: name in `rowTitle` with its real capitals, size as a caption on the right, the summary as meta at full width, then the state on its own line: a `PillButton` "download" under the text, or a caption "on this device · shared with 2 apps". One marker on the bytes on this device. If more than three are missing, one pill "download all (491 MB)" at the top and the per-row buttons become `HandLink`s.
- **Privacy.** Marker on "nothing". Ledger lines are `Body` rows with a tick doodle, not Caveat.
- **Logs.** `type.mono` 13/20 ink, selectable, newest first. Title unmarked.
- **Settings.** Handwriting is three rows with a live sample in each voice. The "headlines stay hand-lettered" note moves under the head.
- **Onboarding.** Promises on the welcome page are `ItemRow`s (title 17/600, meta 14).

---

## 3. Reimagined designs for the two existing apps

Both apps keep the paper, the doodles, the words along the bottom and one ink pill. What changes: fewer things per screen, the answer or the list first, the main action always in the same place (the sticky ink pill), and content set in the body face.

### 3.1 Burrow (Android)

**Navigation.** Four words: `today · talks · ask · people`. "ask" becomes a tab because it is the reason the notes are worth keeping; today no longer carries an ask field. "photos" leaves the bar: tidy, private sweep, the vault and share check are reached from a "tools" section on today (and photos permission is asked there, on first use). Mask is in the same section. Gear and padlock stay top-right on the four home pages.

#### today

Job: show what needs you, and let you start a recording.

```
┌──────────────────────────────────────┐
│ burrow.                       ⚙  🔒 │
│                                      │
│ good morning, Sam                    │  hand.headline
│ Sat 31 Oct                           │  caption
│                                      │
│ [3 things] need you                  │  hand.title, marker on "3 things"
│                                      │
│ ☐ Send the budget                    │  body 16
│   Marco · due Fri 6 Nov              │  meta
│ ☐ Book the launch venue              │
│   Priya · due Sat 7 Nov              │
│ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ │
│ new notes                            │  hand.title
│ Q3 roadmap sync                    → │  ItemRow, rowTitle
│   1 decision · 3 to-dos · 42 min     │
│ Call with Mum                      → │
│   No summary yet                     │
│ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ │
│ tools                                │
│ mask a message                    (→)│  Door, hand.door
│ photos                            (→)│
│                                      │
│ ╭──────────── record  🎙 ──────────╮ │  the ink pill, sticky
│ (today)    talks     ask    people   │
└──────────────────────────────────────┘
```

Cut: the instruction line ("Only what needs you. Tap a line…"), "312 photos checked", the ask field, the talk name and timestamp repeated on every to-do (open the to-do to see its source). "voices to name — 2" appears as a row under the to-dos only when there are any. When nothing needs you: "all quiet." with the marker, and the tools.

#### talks

Job: find a talk, or start one.

```
┌──────────────────────────────────────┐
│ talks                    import  ⚙ 🔒│  "import" is a HandLink
│ Everything you recorded, with notes. │  body, ink, one sentence
│ ┌──────────────────────────────────┐ │
│ │ 🔍 search what was said          │ │
│ └──────────────────────────────────┘ │
│ Design crit                        → │
│   Fri 30 Oct · 31 min                │
│   Writing the notes, part 2 of 3     │  caption + thin HandProgress
│ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ │
│ Q3 roadmap sync                    → │
│   Fri 30 Oct · 42 min · Priya, Marco │
│   roadmap · budget · hiring          │  caption, not pills
│ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ │
│ Call with Mum                      → │
│   Thu 29 Oct · 18 min                │
│ ╭──────────── record  🎙 ──────────╮ │
│  today    (talks)    ask    people   │
└──────────────────────────────────────┘
```

Cut: the round record button in the top corner and the four-line intro that wrapped around it; the two import pills (one "import" link opens a sheet with three rows: a recording file, a phone call, a chat export); year and clock time in every row (show the year only when it is not this year).

#### record

Keep it; it is the calmest screen in the app. The timer is `display`. The two centred grey paragraphs become one left-aligned `Body` sentence ("Tell people you're recording.") and a link "recording a phone call?" that opens the Samsung instructions in a sheet. The name field moves to after you stop.

#### a talk

Job: read what was said and what was decided.

```
┌──────────────────────────────────────┐
│ ←                             ⇪   ⋯  │  share, more (sheet)
│ Q3 roadmap sync                      │  body.contentTitle 22/28
│ Sat 31 Oct · 42 min · English        │  caption
│                                      │
│ (summary)  to-dos 3   transcript     │  ChoicePills
│                                      │
│ The Q3 roadmap sync covered offline  │  Prose, reading 17/26,
│ mode shipping, the no-cloud promise, │  no box
│ budget, and next steps for hiring.   │
│                                      │
│ decided                              │  hand.title
│ ✓ The launch budget is agreed. 19:00 │  body + caption (tappable time)
│                                      │
│ key points                           │
│ → Offline mode ships in November,    │
│   at the same price as today.   5:00 │
│                                      │
│ who was there                        │
│ ● Sam (you)   ● Priya   ● Marco      │  tags with series dots
│ ● Speaker 4 · name them              │
└──────────────────────────────────────┘
```

- **to-dos** view: checkbox rows in `body`, owner and due date as meta.
- **transcript** view: per turn, the speaker in `rowTitle` with their series dot, the time as a caption on the right, the words in `reading`. A search field at the top. Tapping a time plays from there.
- "more" sheet: rename, language, delete, and the line "The audio is deleted after 30 days. The notes stay."
- Cut: the outlined summary box, the language pill and the audio note from the page, the speaker timeline strip (keep it only in the transcript view on wide screens).

#### ask

Job: get an answer about your talks, and see where it came from.

```
┌──────────────────────────────────────┐
│ ask Burrow                    ⚙  🔒 │
│                                      │
│              ╭─────────────────────╮ │
│              │ What did Priya      │ │  your question, smudge, body
│              │ promise?            │ │
│              ╰─────────────────────╯ │
│ Priya promised to book the launch    │  Prose, reading
│ venue next week.                     │
│                                      │
│ from                                 │  caption
│ Q3 roadmap sync · 37:40            → │  ItemRow
│   "Then we book the launch venue…"   │
│ Priya Shah                         → │
│                                      │
│ 3 steps, all on this phone           │  HandLink, opens the trace
│ ┌────────────────────────────────┐   │
│ │ ask about your talks…        ➜ │   │  field, sticky
│ └────────────────────────────────┘   │
│  today     talks    (ask)   people   │
└──────────────────────────────────────┘
```

- The answer comes first. The tool trace ("what Burrow did") is one link under the sources; opened, it shows each step as a row with the call in `mono` 13 ink.
- Empty state: one sentence, then three suggestion pills. "what it can do" is a link, not a numbered list.
- A change (rename, start recording) asks in a `confirmSheet`, not an inline box.
- The intro paragraph shows only in the empty state, not above every answer.
- No model yet: one sentence, the size with the marker ("2.6 GB"), one ink pill "download", the progress line. The memory warning is an ink sentence with a red `!`.
- The send control is a 48 circle in the field, in ink when there is text and `graphite` when empty. There is no full-width disabled pill.

#### people and a person

- **people**: `ItemRow` per person (initial circle, name in `rowTitle`, "2 talks · today" as meta). "add someone" is a link in the top row. "voices to name" is a section at the top only when there are any, with the marker on the count; each is a row with the quote in `body` and a "name them" link.
- **a person**: name in `contentTitle`, stats as a caption. Two pills at most ("call", "message"), the rest under "more". Order: talks together, calls, chats, what you talk about (tags), their voice (one meta line and a "record a sample" pill) last.

#### mask

Keep the three numbered stages; show one open at a time (the others are collapsed `StepHead`s). Pasted and masked text are `reading` in wells. Placeholders are `mono` 600 on a `smudge` chip, not four marker swipes; the marker goes on "4 secrets found". One ink pill: "copy masked text".

#### photos, sweep, vault, share check

Reached from today → tools → photos. The photos page is three doors (tidy up, private sweep, the vault) and a permission step the first time. Share check keeps its layout: the numbered circles become ink, each finding is a `SwitchRow` whose title says what the switch does ("crop the card out"), and the red-pen colour is used only for the `!` on findings.

#### setup

Three short pages instead of one long one: welcome → "nothing leaves this phone" (never-go-online switch) → "one download" (the size with the marker, one ink pill, "later" as a link). Microphone permission is asked when you first press record, photos when you first open photos, notifications when the first long job starts. The model list and Indian languages live on the models page.

#### models, privacy, settings

As the shared pages in 2.5. Model names with capitals ("Voz", "Ear", "Who"). Settings drops the formal-to-handwritten slider; the three rows are the control.

### 3.2 PhoneDots

**Navigation.** Three words: `chat · saved · you`. Skills and models are things you set up, not places you visit daily; they move under "you". This also ends the shrunken five-word bar.

#### chat, empty

Job: start asking.

```
┌──────────────────────────────────────┐
│ phonedots.                    🕘  ✎  │  past chats, new chat
│                                      │
│ good evening                         │  hand.headline
│ Ask anything. It runs on this phone. │  body, ink
│                                      │
│ ╭ record a meeting ╮ ╭ ask about a ╮ │  PillButtons, wrap
│ ╰──────────────────╯ ╰ photo ──────╯ │
│ ╭ mask before you share ╮            │
│ ╭ search my files ╮                  │
│                                      │
│ what else can it do?                 │  HandLink → skills
│                                      │
│ Gemma 4 E2B · on this phone       ▾  │  caption, opens the model picker
│ ┌────────────────────────────────┐   │
│ │ 📎 ask anything…             🎙 │   │  mic when empty, ➜ when typing
│ └────────────────────────────────┘   │
│  (chat)        saved         you     │
└──────────────────────────────────────┘
```

Cut: the "demo" link, the mic and the copy icon from the top row (mic is in the composer; "copy this chat" is in the past-chats sheet); the six doors with sub-lines (four pills; the rest are in skills); the permanent two-line preview banner (shown once as a `DoneNote` the first time, then the model line under the composer says "Demo engine").

#### chat, in a conversation

```
┌──────────────────────────────────────┐
│ phonedots.                    🕘  ✎  │
│        ╭───────────────────────────╮ │
│        │ Summarise the planning    │ │  body 16/24 on smudge
│        │ call and what I owe.      │ │
│        ╰───────────────────────────╯ │
│ Planning call, 34 minutes            │  rowTitle (markdown heading)
│ The team agreed to move the launch   │  Prose, reading 17/26
│ to 12 December so the Android build  │
│ can catch up.                        │
│ • You owe Priya the pricing table    │
│   by Wednesday.                      │
│                                      │
│ What you owe                         │  rowTitle (card title)
│ ☐ Send Priya the pricing table       │  body
│ ☐ Reply to Tom about test devices    │
│                                      │
│ ✓ 2 steps · 1.7 s      ⧉   ↻   ⇪    │  caption link; copy, retry, share
│ ┌────────────────────────────────┐   │
│ │ 📎 ask anything…             🎙 │   │
│ └────────────────────────────────┘   │
└──────────────────────────────────────┘
```

- The answer is first and has no bubble. Steps and thinking collapse to one caption line **under** the answer; tapping it opens the trace sheet. While it is working, that line is live ("transcribing…") above the growing answer.
- Card titles ("transcript", "what you owe") are `rowTitle`, not Caveat, so an answer has one level of heading. Transcript turns: speaker in `tag`, time as caption, words in `body`.
- The footer "Gemma 4 E2B · 14 tok/s" is a caption in pencil (was graphite). The three actions are 48 targets.
- The nav words hide while the keyboard is open.

#### saved

- List: `ItemRow` per item. Title in `rowTitle`, two lines max; the summary as meta, two lines; "tech · Android Developers · 3h ago" as a caption. The platform doodle leads. Filter pills scroll sideways on one line. The intro is one sentence.
- Detail: source line as a caption, title in `contentTitle`, then **the summary first** in `Prose`, key points as a list, tags, "open the original" pill. "What we read" (the raw text, 1,530 characters today shown first) is a link at the bottom that opens it in a sheet.

#### you

```
┌──────────────────────────────────────┐
│ phonedots.                           │
│ you                                  │
│ What it knows, what it can do, and   │
│ how it behaves. All of it stays here.│
│                                      │
│ what it knows                        │  hand.title
│ memory                            (→)│  Door + meta "4 things"
│ my files                          (→)│
│ what it can do                       │
│ skills                            (→)│  "41 on"
│ models                            (→)│  "2.9 GB on this phone"
│ the app                              │
│ settings                          (→)│
│ privacy                           (→)│
│ under the hood                    (→)│  diagnostics + lab
│  chat          saved        (you)    │
└──────────────────────────────────────┘
```

- **memory**: each fact is an `ItemRow` in `body` ink (they are the user's words) with the date as a caption and a pencil trash doodle in a 48 target (not a red cross). "remember something" is the ink pill.
- **my files**: `ItemRow`s with the file name in `rowTitle`.
- **skills**: groups are collapsed section heads with a count ("voice & audio · 7"); inside, `SwitchRow`s. Search stays at the top. The "skills / recipes / community" pills stay.
- **models**: the shared models page from 2.5. Section heads are short ("the brain", "helpers"), names keep capitals, the role tag ("brain", "router") is a plain `HandTag`, not marker-filled.
- **privacy**: the counts row uses `rowTitle` numbers with caption labels. "forget" is a list of rows ("all chats", "saved posts", …) each with a red `HandLink` "forget" and a `confirmSheet`; no column of red pills.
- **under the hood**: two doors, diagnostics and lab. Log lines are `mono` 13 ink. Lab field labels are sentence case in `body`.
- **settings**: three handwriting rows; "about" and the licences are the last section of settings, not a separate door.

Onboarding and the voice screen keep their layout; the model id list on the setup page ("gemma 4 e2b · functiongemma 270m · …") is cut, the size stays with the marker.

---

## 4. Design brief: Burrow on baseApp (iPhone and Mac)

A Flutter rebuild of Burrow's talks side, built only from `base_design` and `base_core` (`apps/burrow`). No photos features. Everything in section 2 applies; nothing here needs a component that is not listed there.

**What it is for.** Record or import a talk, get a transcript with speakers, get a summary with decisions and to-dos, and ask about any of it. All on the device.

### Navigation

- Tabs (`BaseAppConfig.tabs`): `today · talks · ask · people`.
- Mask is a page opened from today ("tools"), from a talk's share sheet ("mask before sharing") and from the rail on Mac.
- Shared pages: settings (gear) with models and logs inside it; privacy (padlock).
- iPhone: `HandNav` along the bottom, the ink pill above it.
- Mac and any window ≥ 1000 wide: `HandNav.rail` on the left.

### Screens

| Screen | Job | Content, top to bottom | Main action |
| --- | --- | --- | --- |
| onboarding | Say what it does and what it downloads | `base_core` onboarding: welcome (marker on "this device") → never go online → models (suggested: Voz required for transcripts; Who, Gist, Redact and Gemma 4 E2B optional, each with its size) | "let's start", then "start" |
| today | What needs you | Greeting, date caption; count with the marker; to-dos due (checkbox rows); new notes (`ItemRow`s); talks still being written (row with progress); voices to name; tools: mask | Ink pill "record" |
| talks | Find or start a talk | One sentence; search; `ItemRow` list, newest first; "import" link (file picker; on Mac also drag a file onto the list) | Ink pill "record" |
| record | Capture | Timer in `display`; one sentence; pause and stop. On stop: name it (optional), then it appears in talks with progress | Red round record/stop |
| talk | Read it | `contentTitle`, caption; `summary · to-dos · transcript` pills; `Prose` summary, decided, key points, who was there; "more" sheet (rename, language, share, mask before sharing, delete) | None sticky; "share" in the top row |
| name a voice | Tell it who spoke | Sheet: the quote, "who is this?", people as choice pills, a field for a new name | "that's them" |
| ask | Answer from your talks | Thread: question bubble, `Prose` answer, "from" source rows that open the talk at that time, "N steps" link to the tool trace; suggestions when empty; download step when Gemma is missing | Send in the field |
| people | Who you talk with | `ItemRow` list; voices to name on top | "add someone" link |
| person | What you and they said | `contentTitle` name, caption; talks together; to-dos they own; what you talk about (tags); their voice | "more" for forget |
| mask | Make text safe to paste elsewhere | Three stages, one open at a time: paste, copy the safe version, bring the reply back | Ink pill "copy masked text" |
| settings, models, privacy, logs | Shared | As 2.5 | |

States every list and page must draw: empty (`HandEmpty` with what will appear and how), working (progress line plus a caption that says the stage: "Writing down what was said, part 2 of 3"), failed (`DoneNote` saying what to do), model missing (one sentence and a download pill, never a dead button).

Ask's tools (search talks, find a person, list follow-ups, summarise a talk; rename only after a `confirmSheet`) are shown as a trace on request, never before the answer.

### Wide screens and the Mac

```
┌────────────┬────────────────────────┬──────────────────────────────────────┐
│ burrow.    │ talks          import  │ Q3 roadmap sync               ⇪  ⋯  │
│            │ ┌────────────────────┐ │ Sat 31 Oct · 42 min · English        │
│ today      │ │ 🔍 search          │ │                                      │
│ (talks)    │ └────────────────────┘ │ (summary)  to-dos 3   transcript     │
│ ask        │ Design crit          → │                                      │
│ people     │   Fri 30 Oct · 31 min  │ The Q3 roadmap sync covered offline  │
│            │ ~~~~~~~~~~~~~~~~~~~~~~ │ mode shipping, the no-cloud promise, │
│            │▌Q3 roadmap sync      → │ budget, and next steps for hiring.   │
│ mask       │   Fri 30 Oct · 42 min  │                                      │
│            │ ~~~~~~~~~~~~~~~~~~~~~~ │ decided                              │
│            │ Call with Mum        → │ ✓ The launch budget is agreed. 19:00 │
│ ⚙  🔒     │ ╭───── record 🎙 ────╮ │                                      │
└────────────┴────────────────────────┴──────────────────────────────────────┘
  rail 200     list 360                 detail, text capped at 600
```

- **Breakpoints.** Under 840: one column, bottom nav. 840–999: bottom nav, `TwoPane` (list 360, detail the rest). 1000 and up: rail 200, list 360, detail.
- **Line length.** Text in the detail pane is capped at `readingColumn` 600 (about 71 characters) and left-aligned with 40 padding. It never stretches with the window. Extra width stays empty paper on the right.
- **Two-pane pages.** talks ↔ talk, people ↔ person. With nothing selected the detail pane shows `HandEmpty` ("pick a talk"). The selected row has a `smudge` background and a 3dp ink bar on its left.
- **One-pane pages.** today, mask, settings, privacy, models, logs: one column of `maxColumn` 560, left-aligned after the rail. ask: one column of 600 with the field pinned to the bottom of that column.
- **The ink pill** on wide screens sits at the bottom of the list pane (talks, today), 320 wide at most, not across the window.
- **Transcript on wide.** Speaker and time in a 120 left margin, words in the remaining measure. The speaker timeline strip sits above it.
- **Mac behaviour.** Minimum window 720×560. The rail starts 28 below the top so the traffic lights sit on paper; no title text. Rows show a `smudge` hover and a pointer cursor; focus draws a 2dp ink ring. Summary, transcript and answers are selectable. Shortcuts: ⌘N record, ⌘F search, ⌘1–⌘4 the four tabs, ⌘, settings, Esc closes a sheet. Sheets are centred dialogs 480 wide, not bottom sheets. Drop an audio file on talks to import it.
- **iPhone behaviour.** Safe areas honoured by `HandPage`. The sticky pill sits above the home indicator. Share sheet import from Voice Memos and Files. Recording continues in the background with the system indicator; the app says so in one caption line.

### Copy

Headings and buttons are lowercase and short ("talks", "record", "name them"). Everything else is sentence case with real numbers ("42 min", "3 to-dos", "2.6 GB, once"). Names keep capitals.

---

## 5. Implementation checklist

Each list is one pass. Do baseApp first; the other two copy its values.

### baseApp

Tokens and generator

1. `design/tokens.json`: apply 2.2 in full; version `2.0.0`.
2. `tools/base_tool/lib/gen.dart`: emit `seriesDark`, `font.mono` (family, fallback), and the `size` group for Dart, CSS, Kotlin and Swift. Run `./base gen`.
3. `packages/base_design/pubspec.yaml` and `fonts/`: remove Patrick Hand.

Theme (`packages/base_design/lib/src/theme.dart`)

4. `BaseType`: add `contentTitle`, `reading`, `rowTitle`, `caption`, `tag`; remove `small`, `bodyLarge`, `body16`; `mono` with the fallback list, 13/20, ink.
5. Material `TextTheme` mapping as in 2.5. No style under 13sp.
6. `seriesColor` reads `seriesDark` in dark.
7. Clamp text scaling at 1.3 for hand styles.

Components (`components.dart`), per the table in 2.5

8. `Meta`, `Body`, `PageIntro` (ink purpose, no title marker), `SectionHead` (note below).
9. `InkButton`, `PillButton`, `ChoicePill`, `HandLink`: sizes, 48 targets, graphite disabled states; delete the `AlphaTokens.disabled*` uses.
10. `Door`, `SwitchRow`, `HandField`, `HandTag`, `OnDeviceStamp`, `Steps`, `StepHead`, `DoneNote`, `HandEmpty`, sheets.
11. New `ItemRow` and `Prose`.
12. `HandNav`: 24sp, no separators, four words max, plus `HandNav.rail`. `HandPage` and `TwoPane`: wide layout with the new breakpoints.
13. Remove every remaining `copyWith(fontSize:` in `components.dart` (currently eight).

Shared pages and shell (`packages/base_core`)

14. `BaseSettings.load`: the `typeVersion: 2` voice migration; map `loose` and `handwritten` to `neat`.
15. `BaseShell`: rail from `railBreakpoint`.
16. `ModelsPage`, `PrivacyPage`, `LogsPage`, `SettingsPage`, `OnboardingPage` as in 2.5.

Starter and docs

17. `apps/starter`: ask answer in `Prose`; design tab shows the new type roles, `ItemRow`, `Prose`, the disabled button and the rail note; today uses `ItemRow` where it shows data.
18. `apps/burrow`: build to section 4.
19. `design/THEME.md`: replace the tokens table, the type line, the voices table and the principles with 2.1–2.4; add `ItemRow` and `Prose` to the component table.
20. `./base check`: add rules that fail on `fontSize:` in app code and on `colors.graphite` used with `Text` outside placeholders and disabled states.
21. `packages/base_design/test/design_test.dart`: add a contrast test (every text colour on `paper` and `smudge` ≥ 4.5:1 in both themes) and a test that no `BaseType` style is under 13sp or, for hand styles, under 24sp.
22. Run the checks in `CLAUDE.md`. Re-render with `tests/baseapp_zz_shots_test.dart` and compare with `baseapp/`.

### Burrow (Android-Showcase, Kotlin)

1. Sync generated Kotlin tokens (`sync-downstream`), or copy 2.2 into `ui/theme/Theme.kt`: colours, `Hand` (display 52/58, headline 38/42, title 30/34, door 24/28, label 24/28; delete `small`), body roles, `seriesDark`.
2. `Theme.kt`: `Voice` keeps `FORMAL`, `FRIENDLY`, `NEAT`; `DEFAULT = FRIENDLY`; scales 1.0; settings migration as 2.3. Material typography mapping as 2.5 (no 11 or 12sp). Remove Patrick Hand from `res/font`.
3. `ui/hand/HandUi.kt`: apply the component table; add `ItemRow` and `Prose`; `HandNav` at 24sp without the "·"; disabled `InkButton` in smudge and graphite.
4. Replace every `fontSize = ….sp` and `bodyStyle(n, m)` outside `Theme.kt` and `HandUi.kt` with a named style (20 sizes today). Replace `c.graphite` on informative text with `pencil`.
5. Navigation: `HandTab` becomes today, talks, ask, people. Photos and mask open from today's tools section.
6. today, talks, record: as 3.1 (sticky "record" pill on today and talks; import sheet; no floating record button; no ask field on today).
7. talk notes: `contentTitle`; summary, to-dos, transcript pills; summary in `Prose` with no border; options in a sheet.
8. ask: answer first, sources, trace behind a link, confirm in a sheet, send control in the field; remove the outlined answer box and the red paragraph.
9. people, person, mask, photos group, setup (three pages, permissions asked on first use), models (capitalised names, `ItemRow`, one "download all") as 3.1.
10. Settings: remove the formal-to-handwritten slider.
11. Re-take the screenshots in `design/burrow-a/theme/shots` and update `design/burrow-a/theme/THEME.md` and `tokens.json` there.

### PhoneDots (Flutter)

1. `lib/theme/theme.dart` and `base_tokens.g.dart`: values from 2.2 (`sync-downstream`); `Voice` keeps `formal`, `friendly`, `neat`; default `friendly`; migration in `lib/core/settings.dart`; `Hand` styles as above, delete `Hand.small`; text theme mapping as 2.5. Remove Patrick Hand from `pubspec.yaml` and `assets/fonts`.
2. `lib/widgets/hand.dart`: apply the component table; add `ItemRow`; `HandNav` at 24sp, three words.
3. `lib/widgets/rich_text.dart`: becomes the base for `Prose` (reading 17/26, headings as `rowTitle`); once `base_design` has `Prose`, use that.
4. Replace the hard-coded `fontSize:` values (19 sizes) in `lib/features` and `lib/widgets` with named styles. Replace `graphite` on `models_screen.dart:177` and `message_view.dart:195` with `pencil`.
5. `shell.dart`: tabs chat, saved, you. Skills and models open from you.
6. Chat: two top-row doodles; suggestions as pills; model line and mic in the composer; preview banner once; answer first with steps collapsed underneath; card titles in `rowTitle`; 48 targets on copy, retry, share.
7. Saved: `ItemRow` list, one-line filter row; detail with summary first and raw text behind a link.
8. You: three sections; memory facts as `ItemRow` in ink with a pencil trash target; privacy "forget" rows with red links; diagnostics and lab under "under the hood"; about inside settings.
9. Models: adopt the shared layout (button under the text, capitals, plain role tags).
10. Re-render with `tests/phonedots_zz_shots_test.dart` and compare with `phonedots/`. Update the contrast thresholds in `test/qa_ui_sweep_test.dart` if they encode the old greys.
