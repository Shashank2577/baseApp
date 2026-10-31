---
name: new-app
description: Create a new app on the base platform (Android, iOS, macOS, Windows, Linux and web from one codebase). Use when the user wants to start a new app, prototype an app idea, or "spin up app #N" from the base.
---

# Create a new app

Every app starts as a copy of `apps/starter`, renamed on all six platforms by the tool, then shaped by editing one file (`lib/app_config.dart`) and adding pages.

## 1. Agree the basics (ask only what you can't infer)

- **slug**: lowercase, `a-z0-9_`, starts with a letter (`field_notes`). It becomes the Dart package and the end of the bundle id (`com.showcase.fieldnotes`, from `platform.yaml`).
- **name** people say ("Field Notes"), a **tagline** (one sentence) and the one word in it that gets the marker.
- **two to four tab words** (lowercase nouns: `today · notes · people`). More than four means the app does too much.
- **models**: what it must have (`requiredModels`) and what it can use if present (`optionalModels`). Pick from `catalog/models.json`; if one is missing, use the `shared-models` skill first.

## 2. Scaffold

```bash
./base new field_notes "Field Notes"
flutter pub get            # at the repo root (the workspace)
```

This copies the starter (skipping build output), renames the package, Android `applicationId`/namespace and Kotlin folder, iOS/macOS bundle ids, Windows/Linux binary names and application id, the web manifest and title, and adds the app to the workspace in the root `pubspec.yaml`.

## 3. Shape it

1. Edit `apps/<slug>/lib/app_config.dart`: `appId` (already set), `name`, `wordmark` (`'notes.'`), `tagline`, `welcomeMark`, `welcomeDoodle`, `tabs`, `requiredModels`, `optionalModels`, `ledgerEntries` (the sentences this app adds to the privacy page, e.g. "answered %d questions").
2. Replace the starter's pages in `lib/pages/`. Keep `today` as the first tab if the app has a home; drop the `design` tab before release.
3. Every page follows `design/THEME.md`: `HandPage` + `PageIntro`, one `InkButton`, one marker, `Door` rows, `ShellActions()` top-right on home pages. Read `BaseScope.of(context)` for models, AI, settings, ledger and storage.
4. Real inference on phones: follow the `on-device-ai` skill (adds `base_ai_native`, sets `nativeAi: true`).
5. App icon: replace the launcher icons per platform (Android `mipmap-*`, iOS/macOS `AppIcon.appiconset`, Windows `app_icon.ico`, web `icons/`). Keep the hand-drawn style: ink strokes on marker yellow.

## 4. Prove it works

```bash
./base check                              # conformance: must be 0 errors
flutter analyze apps/<slug>
flutter test apps/<slug>                  # copy apps/starter/test/app_test.dart and adapt it
cd apps/<slug> && flutter build web && flutter build apk --debug   # plus linux/macos/windows/ios where available
```

Add a widget test like the starter's: onboarding → each tab → settings → models, at a 390-wide phone, with `MemoryJsonStore`, a temp models folder and `AiRuntime.demo()`. It catches layout overflows on narrow screens, which are the most common bug.

## 5. Ship

Use the `release` skill. Before the first store build, make sure the app is signed with the vendor's shared Android key and joins the App Group, or it will not share models with the other apps.

## Rules

- Anything you write that a second app could use goes in a package, not in the app (`propagate-change`).
- No hex colours, font names, Material buttons, network calls or storage paths in app code; `./base check` enforces it.
