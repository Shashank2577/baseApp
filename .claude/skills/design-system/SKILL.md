---
name: design-system
description: Build or change UI in any app on the base platform using the hand-drawn minimal design system (from Burrow / Android-Showcase). Use for any screen, component, colour, font, icon or theme work, for reviewing UI against the system, or when the user asks for something to "look like the Android Showcase app".
---

# Use and extend the design system

Rules: `design/THEME.md`. Code: `packages/base_design`. Live catalogue: the starter app's **design** tab.

## Building a screen

```dart
HandPage(
  actions: const [ShellActions()],                 // home pages: gear + padlock
  bottom: InkButton('record a talk', trailing: Doodle.arrow, onPressed: start),
  children: [
    const PageIntro(title: 'talks', purpose: 'Record a conversation and get notes, on this device.', doodle: Doodle.mic),
    const SectionHead('this week', first: true, note: '4 talks, 2 hours'),
    ItemRow('Q3 roadmap sync', meta: '1 decision · 3 to-dos', caption: 'Fri 30 Oct · 42 min', onTap: openTalk),
    ...
  ],
)
```

Checklist for every screen:

1. `PageIntro` first: the page's name and one plain sentence.
2. Exactly one `InkButton`; secondary actions are `PillButton`, minor ones `HandLink`.
3. At most one marker, on a fact of at most 16 characters (`MarkedText`, `Marker`); never a whole title.
4. No cards, shadows or gradients; separate with space and `HandDivider`.
5. Rows that lead to a place in the app are `Door(onTap: …)`; content rows are `ItemRow`.
6. Icons are `DoodleIcon(Doodle.x)`; never Material `Icons`.
7. Colours from `context.colors`, styles from `context.type` (hand, the app's own short words, never below 24: `display headline title door label`; body face, everything you read: `contentTitle reading rowTitle body meta caption tag mono`). No `fontSize:` in app code. Sentences are ink; `pencil` for meta, `graphite` only for placeholders and disabled. Charts and people: `context.colors.series(i)`.
12. Content rows (talks, people, models, files) are `ItemRow`, never `Door`; long text and model answers are `Prose`. Data and names keep their capitals and are never Caveat.
8. Red pen (`danger: true`, `alert: true`, `color: c.redPen`) only for private or destructive things.
9. Wide screens: `TwoPane(list: …, detail: …)` or check `context.isWide`.
10. Animations: durations from `MotionTokens` through `context.motion(...)`.
11. Text tells the truth: real numbers, real outcomes, say what happens next (`DoneNote`).

`./base check` fails on hex colours, `Colors.*` (except `transparent`), `fontFamily:`, `fontSize:`, graphite text, `ElevatedButton`, `FloatingActionButton` and `Card` in app code.

## Changing a token or an icon

1. Edit `design/tokens.json` or `design/doodles.json`. Doodles are SVG paths (M L H V C Q Z) on a 24×24 grid, deliberately a little off-true, round caps.
2. `./base gen`, then bump `version` in `tokens.json`.
3. Check the design tab in light and dark, with "formal" and "neat hand" (the widest).
4. `./base sync` and the `sync-downstream` skill, so Burrow, PhoneDots and Spreix get it too.

## Adding a component

1. Only if two apps need it (otherwise it stays in the app). Look in `components.dart` first; most needs are a composition of what is there.
2. Build it from tokens and `context.colors` / `context.type`; strokes with `drawHandLine`, `swipePath`, `handCirclePath` (seeded, so they don't jitter); press feedback via the private `_Press` (squish + haptic + semantics).
3. Make it survive narrow screens and big text: `Flexible` / `Expanded` around text in rows, `FittedBox(scaleDown)` for single words.
4. Accessibility: a `Semantics` label for anything drawn, 48dp touch targets, `selected`/`toggled` states.
5. Add it to the starter's design tab, to the catalogue test in `packages/base_design/test/design_test.dart`, and to the table in `design/THEME.md`.
6. If Burrow should get it too, note it for the `sync-downstream` skill (Compose component in `ui/hand/HandUi.kt`).

## Fonts

Caveat (hand), Nunito (the default reading voice), Inter, Shantell Sans (variable, `INFM` axis): bundled in `packages/base_design/fonts` (SIL OFL). Apps never declare fonts; the theme sets `package: 'base_design'`.
