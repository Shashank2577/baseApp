# Burrow (on baseApp)

Burrow's talks side, rebuilt in Flutter on the base platform so it runs on iPhone and Mac (and builds for Android, Windows, Linux and web like every baseApp app). Record or import a talk, get a transcript with speakers, a summary with decisions and to-dos, the people in it, ask about any of it, and mask text before it goes to an AI. Everything runs on the device.

The original is the Kotlin/Compose Android app in `Android-Showcase` (`com.showcase.desertant`). This one is `com.showcase.burrow`, so both can be installed side by side.

## Screens

Tabs: **today · talks · ask · people** (`lib/app_config.dart`). The gear opens settings (models, logs, handwriting, light/dark), the padlock opens privacy (the ledger, never go online, wipe everything). Mask opens from today and from a talk's "more" sheet.

| Page | What it does | Code |
| --- | --- | --- |
| today | Greeting; how many to-dos are due this week (the marker); due to-dos you can tick; new notes since yesterday; talks still being written; voices to name; mask. The ink pill records. | `pages/today_page.dart` |
| talks | Every talk, newest first, with search once there are more than three; "import a recording" (file picker). On wide screens the open talk sits beside the list. | `pages/talks_page.dart` |
| record | Timer, level, pause, "stop and write the notes". 16 kHz mono WAV, which the speech models read best. | `pages/record_page.dart` |
| a talk | Title (in the reading face: it is data), date, length, language. `summary · to-dos · transcript`: the gist, decided, key points, who was there (tap a voice to name it); tickable to-dos with who and when; the transcript with speaker colours and times. "more": rename, summarise again, mask before sharing, delete. | `pages/talk_page.dart` |
| ask | "ask Burrow": Gemma 4 E2B with Burrow's tools over your talks; the answer first, then the talks it came from, then "N steps" to see the tool trace. Renaming asks first. | `pages/ask_page.dart`, `logic/ask_agent.dart`, `logic/burrow_tools.dart` |
| people, a person | Voices still to name, everyone named, "add someone"; a person's to-dos and talks together; forget. | `pages/people_page.dart`, `pages/person_page.dart` |
| mask | Three steps: paste, copy the safe version, bring the reply back. Redact swaps names, numbers and addresses for `[NAME_1]`-style placeholders; the reply gets the real details back. Kept in memory for 30 minutes at most. | `pages/mask_page.dart` |
| models, privacy, logs, settings, onboarding | base_core's shared pages. | `packages/base_core` |

## How a talk is processed

`logic/processor.dart`, in order, with the app kept awake (`KeepAwake.during(..., ai: true)`) and each step shown on the talk:

1. the speech models from the shared store (`ensureModel`: Ear, Voz, Who);
2. **Ear**: the spoken language;
3. **Voz**: the transcript with word times;
4. **Who**: who spoke when; words are grouped into lines on speaker changes and pauses (Burrow's `MeetingText.kt`);
5. **Gist**: topics, which also name the talk;
6. the **summary**: Gemma 4 E2B with Burrow's `TalkSummarizer` prompts unchanged (`logic/summarizer.dart`): JSON with gist, points, decisions and to-dos; long talks in parts then merged; one retry when the JSON can't be read; times outside the talk dropped; repeats dropped; **due dates worked out in code** from the words the talk used (`logic/due_dates.dart`, Burrow's `DueDates.kt`).

Without Gemma on the device, or on the demo engines, the notes are picked from the transcript by rules (`ruleNotes`: the opening as the gist, decisions and commitments by phrasing, the same date code) and the talk says so. "summarise again" rewrites them later.

Data: talks, people and to-dos are JSON in the app's `JsonStore` (`data/burrow_data.dart`); audio is under the store's files folder (`talks/<id>.wav`), so **wipe everything** deletes it too (tested).

## Engines per platform

| | Speech (Ear, Voz, Who, Gist), Redact | Summaries and ask (Gemma 4 E2B) |
| --- | --- | --- |
| iPhone (iOS 18+) | Desert Ant 4.2.1 through `base_ai_native` (Swift package) | LiteRT-LM 0.18.1; tools described in the prompt and parsed from text (`ToolCallParser` in base_ai) |
| Mac (macOS 14+, Apple silicon) | same as iPhone, same Swift source | same as iPhone |
| Android | Desert Ant through `base_ai_native` (Kotlin) | LiteRT-LM with constrained tool calling |
| Windows, Linux, web, tests | demo engines: a sample transcript and pattern-based masking, labelled "demo engine" everywhere they show | demo: ask runs Burrow's tools by keyword and says it is not a model |

Models (shared store, `catalog/models.json`): required on iPhone, Mac and Android: `desertant.ear`, `desertant.voz`, `desertant.who`, `desertant.gist`, `desertant.redact` (about 660 MB, offered in onboarding); optional: `gemma-4-e2b` (2.6 GB, wants about 6 GB of RAM). On web, Windows and Linux nothing is required, because the demo engines need no files.

## Decisions (made while the owner was away)

- **New bundle id** `com.showcase.burrow`, not the Android app's `com.showcase.desertant`, so the two never fight over updates or data.
- **Mac is Apple silicon only.** desert-ant-core uses `Float16`, which Intel Macs lack (as in PhoneDots).
- **base_ai_native became one `darwin/` source for iOS and macOS** (`sharedDarwinSource`), mirroring PhoneDots' plugin; `AiRuntime.forPlatform` now uses native engines on macOS too, and Desert Ant weights are per app on macOS as on iOS (the SDK picks its own folder there).
- **Recording format**: 16 kHz mono WAV through the `record` plugin; about 115 MB an hour. Imports are copied into Burrow's folder; the original stays where it was.
- **Tools for ask**: `search_talks`, `talk_details`, `follow_ups`, `find_person`, and `rename_talk` behind a yes/no sheet. Rounds capped at 5. Burrow chooses the citations itself (small models cite unreliably), as in `AskAgent.kt`.
- **Tool calls on Apple** are read from text with PhoneDots' parser, now `ToolCallParser` in base_ai so every app can use it.
- **Required models depend on the platform** (`AiRuntime.nativeEnginesHere`), so a web or desktop build doesn't ask for downloads it cannot use.
- **Speaker naming** is manual: name a voice in a talk and it lands on that person's page. To-dos belong to a person when the summary names them.
- **Design**: tabs, mask's place, the talk's three parts, answer-first ask and the wide layout follow `design/REVIEW.md` section 4. Built on the readable system (tokens 2.0.0): talks and people are `ItemRow`s, their titles in `contentTitle`, summaries and answers in `Prose`; the shell gives the Mac the word rail from 1000 wide and `TwoPane` puts a talk beside the list from 840.
- **Mac window**: opens at 1100×760 at least, never smaller than 720×560.
- **Copy**: Burrow's own sentences where they still fit ("Record a meeting, a lecture or a call…", "mask a message", "ask Burrow"); photos and chats are gone from them.

## Left out, and why

| From Burrow (Android) | Why not here |
| --- | --- |
| Photos: tidy, private sweep, trash, share check | Android gallery and MediaStore features; the brief is the talks side. |
| The vault (AES-GCM with a biometric Keystore key) | Android Keystore and BiometricPrompt; nothing to keep in it without photos. |
| Call recordings found in Android folders, voice-memo discovery | Android storage conventions; on iPhone and Mac, import the file instead. |
| WhatsApp chat import and `search_messages` | Share-sheet intake isn't in base_ai_native yet; not cheap to do well. |
| IndicConformer and Omnilingual speech packs (ONNX) | No ONNX runtime in base_ai yet; Voz covers its 25 European languages. Other languages get a weaker transcript. |
| Voice matching across talks (MFCC signature) | Burrow computes it from Android PCM in Kotlin; here you name each voice once per talk. |
| Clear (noise clean-up), Uhm, highlights scored by embeddings | Clear and Uhm fetch weights outside the shared store on Apple; highlights would need EmbeddingGemma. Key points come from the summary instead. |
| Summary language picker (25 languages) | Summaries are written in English for now; the prompt already takes a language, so this is a settings row away. |
| A player with a speaker timeline, tap-to-play lines | No audio player plugin was added; the transcript shows times. |
| `start_recording` tool, the brief's "you" on your own to-dos | Small; left for a later pass. |
| ⌘ shortcuts, drag-and-drop import, centred sheets on the Mac | Belong in base_core/base_design (design/REVIEW.md); Burrow gets them when the shell does. |

## Tests

`flutter test apps/burrow` (demo engines, recorder and file picker stood in):

- `test/app_test.dart`: import → processing → summary → tick a to-do → name a voice → people → today's brief; record; ask with steps and a cited talk; mask, copy, restore; wipe deletes talks and audio; settings and the models page. At a 390-wide phone.
- `test/logic_test.dart`: due dates; the summariser's JSON reading, retry and parts; lines and rule notes; the ask loop with tools parsed from text, a declined rename, the round cap; follow-ups and people.

## Build

```bash
flutter pub get                      # at the repo root
cd apps/burrow && flutter run -d macos     # or an iPhone, chrome, linux, windows, an Android phone
```

Apple builds need Xcode 26 and Swift Package Manager (`flutter config --enable-swift-package-manager`). CI: `.github/workflows/apple-build.yml` (unsigned `.ipa` and Mac zip) and `release.yml` (every platform, checksums, a GitHub release).
