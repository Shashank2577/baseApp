---
name: propagate-change
description: Make a change once so every app on the platform gets it. Use whenever a change is made (or requested) in any one app, package, design token or model entry and it could matter to other apps - fixes, components, design tweaks, model hub behaviour, onboarding, settings, privacy - or when the user says "apply this to all apps" / "keep the apps in sync".
---

# Propagate a change to every app

Read `docs/PROPAGATION.md` once. The short version: there are three channels (shared packages, generated sources, enforced rules), and a change belongs in the strongest one that fits.

## 1. Decide where the change belongs

Ask: *would a second app want this?* If yes, it does not belong in an app.

| The change is… | It goes in… |
| --- | --- |
| a colour, size, spacing, stroke, motion, font, handwriting voice | `design/tokens.json` |
| an icon | `design/doodles.json` (SVG path on a 24×24 grid, slightly off-true) |
| a reusable widget, or a fix to one | `packages/base_design/lib/src/components.dart` (or `hand.dart` for strokes) |
| a model, its URL, checksum, size or platforms | `catalog/models.json` (`shared-models` skill) |
| downloading, sharing or deleting models | `packages/base_models` |
| onboarding, settings, models or privacy pages, the shell, storage, the ledger | `packages/base_core` |
| AI engine behaviour | `packages/base_ai` (Dart) / `packages/base_ai_native` (Kotlin, Swift) |
| vendor ids, App Group, Android permission, downstream repos | `platform.yaml` |
| truly app-specific behaviour or copy | that app's `lib/` only |

If the change was already made inside an app: move it (don't copy it) into the package, make the app use the package version, and delete the app's copy.

Keep packages generic: no app names, no app-specific strings. Take what varies as a parameter or put it in `BaseAppConfig`.

## 2. Make it, then regenerate

```bash
./base gen                 # only if you touched design/, catalog/ or platform.yaml
flutter pub get            # if a pubspec changed
```

## 3. Prove every app still works

```bash
flutter analyze            # at the root: every package and app
flutter test               # at the root runs every package's and app's tests
cd tools/base_tool && dart test && cd -
./base check               # must be 0 errors
```

For anything visual, also look at the starter's **design** tab in light and dark with the "all handwritten" voice (the widest), at 360 wide. Add the case to `packages/base_design/test/design_test.dart` (the catalogue test fails on overflow).

A change to a package's public API: update every app in `apps/` in the same change. `flutter analyze` at the root lists every call site.

## 4. Carry it beyond this repo

If `design/` or `catalog/` changed: `./base sync`, then follow the `sync-downstream` skill for Burrow (Kotlin), PhoneDots (Flutter) and Spreix (React).

## 5. Record it

- Bump `version` in `design/tokens.json` for any visual change (it shows on every app's settings page).
- One commit with the source, the regenerated files, the package change and the app updates, and a message that says what every app now does differently.
- If the change affects how the platform behaves (sharing, privacy, a rule in `./base check`), update the matching doc in `docs/` or `design/THEME.md`.
