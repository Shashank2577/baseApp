# baseApp

The platform every app is built on: a Flutter pub workspace (`packages/`, `apps/`, `tools/`) that builds each app for Android, iOS, macOS, Windows, Linux and web, with one shared on-device model store, one design system and one shell. Read `README.md`, then the doc for the area you touch (`docs/`, `design/THEME.md`).

## Rules

- **A change that a second app could want never lives in an app.** It goes in a package, in `design/`, in `catalog/models.json` or in `platform.yaml`. Use the `propagate-change` skill for any change made in, or noticed in, one app.
- **Never edit generated files** (`*/generated/*`, `generated/`). Edit the source and run `./base gen`.
- **Models only through the shared store** (`BaseScope.of(context).ensureModel` / `models.pathOf`); never download or store a model anywhere else. Apps outside this repo follow the same standard (protocol v1 in `docs/MODEL_STORE.md`): Flutter through `base_models`, Kotlin through the synced `:basemodels` module. Skill: `shared-models`.
- **UI only from `base_design`**: `context.colors`, `context.type`, `DoodleIcon`, the components. No hex colours, font names, Material icons or Material buttons in app code. Skill: `design-system`.
- **Every app keeps all six platform folders**, the App Group entitlements (iOS, macOS) and the Android shared-model placeholders.
- `platform.yaml → sharedModels` must not change after the first release (it moves every user's models).
- Keep copy truthful and plain (lowercase hand-lettered headings, one sentence per page purpose, real numbers).

## Before you finish any change

```bash
./base gen            # if you touched design/, catalog/ or platform.yaml
flutter analyze       # at the root: all packages and apps
flutter test packages/base_design packages/base_models packages/base_core apps/*
(cd packages/base_models && flutter test --platform chrome test/web_store_test.dart)   # needs Chrome
(cd tools/base_tool && dart test)
./base check          # 0 errors
```

Widget tests that build `BaseServices` must create them inside `tester.runAsync` (they do real file IO) and pass them in with `Future.value(...)`; don't `pumpAndSettle` on a page with an indeterminate `HandProgress`.

## Review

Pull requests are reviewed with [Cairn](https://github.com/Shashank2577/cairn), not Codex. Set it up once per clone: `uv tool install --python 3.12 cairn-brain`, then run `cairn` in the repo root (it adds the `cairn` MCP server, the `cairn-reviewer` sub-agent and git hooks; `cairn uninstall` removes them). Before merging, run the `cairn-reviewer` sub-agent on the branch, or `cairn review-context --files "$(git diff --name-only origin/main... | paste -sd, -)"` for the context pack, and fix what it flags. Record durable lessons with `cairn remember`.

## Skills

`new-app`, `propagate-change`, `design-system`, `shared-models`, `on-device-ai`, `sync-downstream`, `release`, `platform-audit` (in `.claude/skills/`).

## Related repos (checked out next to this one)

- `Android-Showcase` (Burrow, Kotlin/Compose): origin of the design system. Gets generated Kotlin tokens.
- `PhoneDots` (Flutter): origin of the model hub and engines. Candidate to migrate onto the packages.
- `spreix-notetaker-apps` (React/Capacitor/Electron): origin of the release practice. Gets generated CSS tokens.
