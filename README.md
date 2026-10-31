# baseApp: the platform for every app

The starting point for the next 20 apps. One Flutter codebase per app builds for **Android, iOS, macOS, Windows, Linux and web**. Every app shares:

- **one model store per device**: an AI model is downloaded once and used by every app ([docs/MODEL_STORE.md](docs/MODEL_STORE.md));
- **one design system**: Burrow's hand-drawn minimal look, now cross-platform ([design/THEME.md](design/THEME.md));
- **one shell**: onboarding, settings (light/dark, five handwriting voices), models page, privacy page with a ledger and "never go online";
- **one set of rules and skills**, so a change made once reaches every app ([docs/PROPAGATION.md](docs/PROPAGATION.md)).

It is built from the three existing apps: the design system from **Burrow** (Android-Showcase), the model hub and on-device engines from **PhoneDots**, and the release discipline from **Spreix** (spreix-notetaker-apps). What came from where, and why Flutter: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Lessons carried over: [docs/LESSONS.md](docs/LESSONS.md).

## Start a new app

```bash
flutter pub get                       # once, at the root (pub workspace)
./base new field_notes "Field Notes"  # copies apps/starter, renamed on all six platforms
# edit apps/field_notes/lib/app_config.dart, add pages
./base check && flutter test apps/field_notes
cd apps/field_notes && flutter run -d macos    # or chrome, linux, windows, an Android or iOS device
```

```dart
// apps/field_notes/lib/app_config.dart
const appConfig = BaseAppConfig(
  appId: 'com.showcase.fieldnotes',
  name: 'Field Notes',
  wordmark: 'notes.',
  tagline: 'Write things down. Find them again by what they mean.',
  welcomeMark: 'mean',
  tabs: [BaseTab('today', TodayPage.new), BaseTab('notes', NotesPage.new)],
  requiredModels: ['embeddinggemma-2-text-270m'],   // downloaded once per device, shared
  optionalModels: ['gemma-4-e2b'],
);
```

With Claude Code, ask for it in words: the `new-app` skill does the above.

## Layout

```
apps/starter/          the template app: today · ask · design (every component, live)
packages/base_design   tokens, theme, handwriting voices, wobble, doodles, components
packages/base_models   model catalog + shared on-device store (Dart + Kotlin + Swift)
packages/base_ai       engine interfaces, demo engines, platform-channel clients
packages/base_ai_native  opt-in LiteRT-LM (Gemma) and Desert Ant bridges, Android + iOS
packages/base_core     the shell: BaseApp, onboarding, settings/models/privacy pages, storage, ledger
tools/base_tool        the ./base command
design/                tokens.json, doodles.json, THEME.md
catalog/models.json    every model any app may use, with SHA-256 and sizes
generated/             tokens as CSS/Kotlin/Swift, doodles as SVG, the catalog as JSON
platform.yaml          vendor ids, the App Group, the Android permission, downstream repos
.claude/skills/        how to do platform work (below)
docs/                  architecture, model store, propagation, native bridge, lessons
```

## The `./base` command

| Command | What it does |
| --- | --- |
| `./base gen [--check]` | regenerates tokens, doodles, catalog and platform config for every consumer (`--check` fails if stale) |
| `./base new <slug> "<Name>"` | creates `apps/<slug>` from the starter, renamed on every platform, and adds it to the workspace |
| `./base check` | the platform rules for every app (CI runs it) |
| `./base sync [--check] [repo]` | copies generated tokens and the catalog into Burrow, PhoneDots and Spreix |
| `./base checksums` | fills in missing SHA-256s and sizes in the catalog from Hugging Face |

## Skills (`.claude/skills/`)

| Skill | Use it to |
| --- | --- |
| `new-app` | start an app from the base |
| `propagate-change` | make a change once so every app gets it (the main one) |
| `design-system` | build UI the hand-drawn way; add tokens, doodles, components |
| `shared-models` | add or use a model through the shared store |
| `on-device-ai` | switch an app to real inference (Gemma, Desert Ant) |
| `sync-downstream` | carry tokens and the catalog into Burrow, PhoneDots, Spreix |
| `release` | build, sign and publish for all six platforms |
| `platform-audit` | check an app (or a change) against the platform |

Burrow, PhoneDots and Spreix each have a `base-platform` skill for their side of the sync.

## Status

Verified in this repo (Linux host):

- `flutter analyze`: clean, every package and app.
- Tests: design system (wobble bit-identical to Burrow's Kotlin, doodles, voices, the component catalogue at 360 wide in light and dark, nav on narrow screens), model store (two apps sharing one store with no second download, release semantics, "never go online", checksum failure, resume from a partial file), core (settings, ledger, wipe), the starter app end to end (onboarding → tabs → settings → models at 390 wide), and the tool (generator, new-app renaming).
- `./base check`: 0 errors, 0 warnings; every one of the 44 catalog models has verified checksums and sizes.
- Builds of the starter: **web** and **Linux** release builds and an **Android** debug APK succeed; the merged Android manifest has the shared-model provider behind the signature permission.

Not verified here:

- **iOS, macOS and Windows builds.** They need those hosts. CI has the jobs (`.github/workflows/ci.yml`, `release.yml`), but they have not run yet.
- **Real inference.** `base_ai_native` is PhoneDots' bridge code with the store wired in. It has not been built into an app or run on a phone here.
- **Two real apps sharing a model on a real device** (App Group on iOS/macOS, sibling copy on Android). The logic is tested with two stores on one folder; the native parts are untested on devices.
- Signing, notarisation, store submission.
