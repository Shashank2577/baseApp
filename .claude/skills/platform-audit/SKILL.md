---
name: platform-audit
description: Audit apps on the base platform (or a change) for drift from the platform - design rules, shared models, privacy, platform coverage, tests, and the lessons from Burrow, PhoneDots and Spreix. Use before a release, when reviewing a PR that touches an app, or when the user asks whether the apps are consistent.
---

# Audit an app against the platform

## 1. Automated checks (must all pass)

```bash
./base gen --check
./base check            # 0 errors; warnings listed
flutter analyze
flutter test
(cd tools/base_tool && dart test)
```

## 2. Read the app against the rules

For each app in `apps/`:

- **Config**: `lib/app_config.dart` is the only place the app's identity, tabs and models are set. Two to four tabs. `requiredModels` is the true minimum.
- **Design** (`design/THEME.md`): every page opens with `PageIntro`; one `InkButton`; at most one marker; `Door` rows; doodles only; no cards; red pen only for private/destructive; `ShellActions` on home pages. Look at each page in light and dark with "all handwritten".
- **Models** (`docs/MODEL_STORE.md`): every model comes from the catalog through `ensureModel`/`pathOf`; nothing downloads elsewhere; `OfflineException` handled with a helpful message; no silent `release`/`deleteEverywhere`.
- **Privacy**: the privacy page's sentences are true; the app adds its own `ledgerEntries`; no analytics, accounts or uploads unless the user agreed and the copy says so.
- **Code that should be shared**: anything in the app that a second app would want (a widget, a helper, a fix to shell behaviour). Move it with `propagate-change`.
- **Platforms**: all six folders present; Android placeholders and iOS/macOS App Group entitlements in place; app icon replaced.
- **Tests**: a widget test through onboarding and every tab at 390 wide.

## 3. Lessons (`docs/LESSONS.md`)

Check the ones relevant to the app: fail loudly on configuration; unsigned builds labelled; SHA256SUMS published; keychain never falls back to plaintext; crash-safe recordings; foreground service types on Android 14+; refresh-token rules for apps with a backend.

## 4. Report

List findings as: what, where (`file:line`), why it matters, the fix, and whether it belongs in the app or in a package. Fix what the user asks you to; propose the rest.
