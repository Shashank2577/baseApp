# Native bridge contract

Dart talks to the native engines over four method channels and two event channels. Kotlin (`packages/base_ai_native/android/…/`) and Swift (`packages/base_ai_native/ios/…/`) implement the same contract; both were ported from PhoneDots. The Dart side is `packages/base_ai/lib/src/platform_engines.dart`.

## `base/llm` (Gemma on LiteRT-LM)

| Method | Arguments | Returns |
|---|---|---|
| `load` | `modelId`, `path`, `backend` (`gpu`/`cpu`), `maxTokens`, `vision`, `audio` | `null`. Falls back to CPU if GPU init fails. |
| `unload` | `modelId` | `null` |
| `generate` | `requestId`, `modelId`, `sessionId`, `history[]`, `systemPrompt`, `tools[]`, `thinking`, `sampler{temperature, topK, topP, maxTokens}` | `null` immediately; results arrive as events |
| `cancel` | `requestId` | `null` |
| `resetSession` | `sessionId` | `null` |
| `deviceProfile` | none | `{platform, totalRamMb, model, soc, gpu, npu}` |
| `loadEmbedder` | `modelId`, `path`, `dimensions` | `null` |
| `embed` | `text` | `List<double>`, L2-normalised and truncated to `dimensions` |

A `history` turn is `{role: user|model|tool|system, text, images[], audio[], toolCalls[{id,name,arguments}], toolResponses[{id,name,response}]}`.

**Sessions.** Native code keeps one live conversation per `sessionId`. If the cached conversation has exactly `history.length - 1` turns and the same system prompt and tool list, only the last turn is sent, so prefill stays incremental. Otherwise the conversation is rebuilt with `initialMessages = history[0..n-1]`. After a reply, the synced count is `history.length + 1`.

**Tools.** On Android each tool becomes an `OpenApiTool` with `automaticToolCalling = false` and constrained decoding on. Tool calls come back as a `toolCalls` event, Dart runs the skill, and the response is the next `tool` turn. The Swift API only supports compile-time tools, so on iOS Dart puts the tool list in the system prompt and parses calls from the text (`lib/agent/tool_call_parser.dart`).

### `base/llm/events`

Every event carries the `requestId` it belongs to:

- `{type: token, text}`
- `{type: thinking, text}`: the `thought` channel when `enable_thinking` is on
- `{type: toolCalls, calls[]}`: always sent before `done`
- `{type: done, stats{ttftMs, totalMs, outputTokens, prefillTps?, decodeTps?}}`
- `{type: error, message}`

## `base/specialist` (Desert Ant)

| Method | Arguments | Returns |
|---|---|---|
| `availability` | none | `{modelId: native|unsupported}` |
| `isDownloaded` | `modelId` | `bool` |
| `download` | `modelId` | `null` when ready; progress arrives on `base/specialist/events` as `{modelId, progress}` |
| `run` | `modelId`, `task`, `input` | a result map, or `{error}` |

Inputs and outputs by model:

| Model | Input | Output |
|---|---|---|
| voz | `audioPath` | `text, duration, words[{text,start,end}]` |
| who | `audioPath` | `speakerCount, turns[{speaker,start,end}]` |
| ear | `audioPath` | `language, confidence, isReliable` |
| clear | `audioPath` | `outputPath, measuredLufs` |
| uhm (iOS) | `audioPath` | `fillers[{start,end,confidence,type}]` |
| redact | `text` | `redactedText, items[{label,original,placeholder,confidence}]` |
| tongue | `text` | `language, confidence, isTooCloseToCall` |
| emo | `text`, `limit` | `suggestions[{emoji,confidence}]` |
| gist | `text` | `topics[{slug,name,score}]` |
| eye | `imagePath` | `kind, tags[], aesthetic, keeper, faces` |
| moderator | `imagePath` | `isNSFW, score` |

Android decodes any audio or video soundtrack with `MediaCodec` to mono float PCM (`AudioFiles.kt`).

## `base/device`

`invoke(action, args)` returns a map with `ok`/`message`, the requested data, or `error`. The actions are `timer.set`, `alarm.set`, `calendar.create`, `calendar.list`, `contacts.search`, `phone.dial`, `sms.compose`, `email.compose`, `app.open`, `url.open`, `maps.navigate`, `torch`, `settings.open`, `volume.set`, `battery`, `storage` and `share.text`. Dart itself handles `clipboard.get`, `clipboard.set`, `datetime` and `file.readText` (`dart_device_actions.dart`).

Sending, calling and emailing always open the system composer. The app never sends anything on its own.

## `base/intake`

Dart calls `ready` once it is listening. Native code then calls `shared({text, files[{path,name,mime}]})` for content that arrived through the share sheet. Shared files are first copied into app storage.

## Platform additions

`base/specialist` has two additions so SDK-managed weights live in the shared model store:

| Method | Arguments | Returns |
|---|---|---|
| `setStoreRoot` | `root` (the shared store folder) | `null`. Android creates each Desert Ant model with `<root>/desertant.<key>` as its folder. |
| `download` | `modelId`, optional `dir` | as before; `dir` also sets the store root |

`base/device` and `base/intake` are declared in Dart but have no native implementation in `base_ai_native` yet (PhoneDots' `DeviceBridge` needs an Activity and is app-specific). Port it into an app, or into the plugin with `ActivityAware`, when an app needs OS actions.
