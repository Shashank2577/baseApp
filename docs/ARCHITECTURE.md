# Architecture

One Flutter codebase per app, six targets from it (Android, iOS, macOS, Windows, Linux, web), and every app built from the same packages in this monorepo.

```
apps/<app>            one folder per app: lib/app_config.dart + its own pages
   │  depends on
packages/base_core     the shell: BaseApp, onboarding, settings / models / privacy pages,
   │                   JsonStore, BaseSettings, Ledger, BaseServices (BaseScope.of(context))
   ├── base_design     tokens → theme, handwriting voices, wobble, doodles, components
   ├── base_models     catalog + the shared on-device model store (+ Android/iOS/macOS native bits)
   └── base_ai         engine interfaces (LLM, embeddings, specialists, device), demo engines,
                       platform-channel clients
packages/base_ai_native  opt-in plugin: LiteRT-LM (Gemma) + Desert Ant bridges for Android/iOS
tools/base_tool         ./base gen | new | check | sync | checksums
design/                 tokens.json, doodles.json, THEME.md       (sources)
catalog/models.json     every model any app may use               (source)
generated/              CSS / Kotlin / Swift / SVG / JSON for non-Flutter apps
platform.yaml           vendor ids, App Group, Android permission, downstream repos
```

## Why Flutter

The three existing apps each solved part of the problem:

| | Burrow (Android-Showcase) | PhoneDots | Spreix notetaker |
| --- | --- | --- | --- |
| Stack | Kotlin + Compose | Flutter | React + Capacitor + Electron |
| Targets | Android | Android, iOS, web preview | Android, (iOS), Mac, Windows, web |
| Best part | the design system | the on-device model hub and engines | the multi-platform release pipeline |

Flutter is the one stack that already runs on-device AI here (PhoneDots' LiteRT-LM and Desert Ant bridges), compiles natively to all six targets from one codebase, and can draw Burrow's hand-drawn system exactly (custom painting, variable fonts). The design system was ported from Compose to Flutter, the model hub and engines from PhoneDots, and the release discipline from Spreix (see `docs/LESSONS.md`).

The non-Flutter apps stay as they are and share what can be shared across stacks, generated from the same sources: design tokens (CSS for Spreix, Kotlin for Burrow) and the model catalog (JSON). See `sync-downstream`.

## How an app is put together

```dart
// apps/notes/lib/main.dart
void main() => runBaseApp(appConfig);

// apps/notes/lib/app_config.dart
const appConfig = BaseAppConfig(
  appId: 'com.showcase.notes',
  name: 'Notes',
  wordmark: 'notes.',
  tagline: 'Write things down. Find them again by what they mean.',
  welcomeMark: 'mean',
  tabs: [BaseTab('today', TodayPage.new), BaseTab('notes', NotesPage.new)],
  requiredModels: ['embeddinggemma-2-text-270m'],
  optionalModels: ['gemma-4-e2b'],
);
```

`BaseApp` boots `BaseServices` (storage, settings, ledger, model store, AI runtime), applies the user's theme and handwriting, runs onboarding once (welcome → the app's models, reusing any already on the device → "never go online"), then shows `BaseShell`: the app's tabs as hand-lettered words, with the gear (settings) and padlock (privacy) on every home page via `ShellActions`.

Inside any page: `BaseScope.of(context)` gives `models`, `ai`, `settings`, `ledger`, `store`, `config`.

## State and storage

- Plain `ChangeNotifier` services and `ListenableBuilder`, no state-management package (as in PhoneDots).
- `JsonStore`: JSON documents in the app's support folder (atomic writes), `shared_preferences` on web, in-memory in tests.
- Model files never go in `JsonStore`; they go in the shared model store.
- Navigation: `pushPage(context, page)` (Material page routes). Lists and details sit side by side from 700 wide (`TwoPane`).

## AI engines

`AiRuntime.forPlatform(nativeBridges: config.nativeAi)`:

- **demo** (default; web, desktop, tests): scripted output, always labelled as a demo. The whole app is explorable without a model.
- **native** (Android/iOS with `base_ai_native`): Gemma through LiteRT-LM, Desert Ant specialists. Paths come from the shared store.

The channel contract is `docs/NATIVE_BRIDGE.md`. Desktop inference (LiteRT-LM has desktop builds; ONNX Runtime for the speech packs) is the next engine to add; the interfaces don't change.

## Privacy

Every app gets the same, checkable privacy story: the only network traffic the platform makes is model downloads (counted in the ledger), there is no account, analytics or upload code, and "never go online" is enforced in the model store. Apps add their own ledger sentences (`ledgerEntries`).
