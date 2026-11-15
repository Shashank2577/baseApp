# How a change reaches every app

The rule: **anything two apps need lives in one place, and every app gets it from there.** There are three channels, from strongest to weakest.

## 1. Shared packages (all Flutter apps, automatic)

Every app in `apps/` is a member of the pub workspace (root `pubspec.yaml`) and depends on `base_core`, `base_design`, `base_models` (and `base_ai`) by path. Change a package, and the next build of every app has it. There is no version to bump and no copy to update.

So when a change is made inside one app and it is not specific to that app (a component, a fix in the shell, a better download, a new ledger rule), it moves into the package and the app uses it from there. The `propagate-change` skill walks through deciding and doing that.

## 2. Generated sources (all apps, any stack)

Design tokens, doodles, the model catalog and the shared-store settings are data, not code:

| Source | Generated into |
| --- | --- |
| `design/tokens.json` | `base_design` (Dart), `generated/css/base-tokens.css`, `generated/kotlin/BaseTokens.kt`, `generated/swift/BaseTokens.swift` |
| `design/doodles.json` | `base_design` (Dart), `generated/svg/doodles/*.svg` |
| `catalog/models.json` | `base_models` (Dart), `generated/catalog/models.json` |
| `platform.yaml` | `base_models` (`PlatformConfig`) |

`./base gen` regenerates them; `./base gen --check` (in CI) fails if someone edited a source without regenerating. `./base sync` copies the generated files into the downstream repos listed in `platform.yaml` (Burrow, PhoneDots, Spreix), where each repo's `base-platform` skill explains how they are wired in.

## 3. Rules (all apps, enforced)

`./base check` runs in CI on every app and fails the build when an app drifts:

- generated files out of date;
- an app not in the workspace, or not depending on the base packages;
- a missing platform folder (all six are required);
- no `lib/app_config.dart`;
- hard-coded colours, Material colours or font families in app code;
- network calls or model downloads in app code (they belong in `base_models`);
- own storage paths (they belong in `JsonStore` / the model store);
- Material widgets outside the system (`ElevatedButton`, `FloatingActionButton`, `Card`);
- missing App Group entitlements (iOS, macOS) or Android shared-model placeholders;
- catalog problems (duplicate ids, non-https URLs, files without a checksum → warning).

A line can opt out with a `// base-check: ignore` comment and a reason, for the rare real exception.

## The loop, in practice

1. Make the change where it belongs (package or source file), not in the app that noticed it.
2. `./base gen` if you touched a source.
3. `flutter analyze`, `flutter test` at the root (every package and app), `./base check`.
4. Look at the starter's design tab if it is visual.
5. `./base sync` if tokens or the catalog changed, and follow each downstream repo's skill.
6. Commit the source, the generated files and the package change together.
