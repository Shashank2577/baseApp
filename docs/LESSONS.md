# Lessons carried over from the three apps

These are things the existing apps learned the hard way. The base platform already does the ones marked **built in**; the rest are rules for app code and releases.

## From Burrow (Android-Showcase)

- **Built in.** The design system: tokens, the five handwriting voices, the seeded wobble, 35 doodles, every component. Docs and code had drifted (display 56 vs 52, "hand" 20 vs 21, motion tokens never used); the base takes the values the Kotlin code actually ships, and the tokens file is the only source now.
- **Built in.** "Never go online" enforced where downloads happen, not in the UI.
- **Built in.** Downloads are verified. Burrow's speech packs had no checksums; every file in the catalog now has its SHA-256 and size (`./base checksums`).
- Status-bar icons follow the app's light/dark choice, not the phone's (`BaseShell` does this).
- Private screens are excluded from screenshots and the recent-apps preview (Burrow: `FLAG_SECURE`). Not in the base yet: add it per screen when an app shows private content.

## From PhoneDots

- **Built in.** The model hub: resumable `.part` downloads, SHA-256 verification, RAM-fit (`ModelSpec.fits`), Hugging Face tokens for gated models (Gemma: accept the licence, then add a token).
- **Built in.** Demo engines that always say they are a demo, so web, desktop and tests run the whole app without a model.
- **Built in.** Native code never discovers model files; Dart passes absolute paths from the store.
- PhoneDots' Android signing key is committed with a public password, so sideloaded builds update in place. Fine for a preview, never for a store release: the base requires a real shared key from CI secrets (and the shared-model permission depends on it).
- Both LiteRT-LM and Desert Ant ship `libLiteRt.so`; the APK keeps one copy. Check on a device that Gemma and the specialists both load (still unverified in PhoneDots).
- Desert Ant on Android reports download progress only as 0 then 1; the UI must not promise a percentage for SDK models.

## From Spreix (notetaker apps)

- **Fail loudly on configuration.** A release build with a dev setting, an http URL or a missing value must refuse to build, not ship broken. (The base has no backend; apps that add one copy Spreix's `ApiConfigError` and production-env guard.)
- **Make unsigned builds obvious.** Unsigned or debug artifacts get `-UNSIGNED` / `-DEBUG` in the file name and make the GitHub release a pre-release automatically (the release workflow does this).
- **Publish `SHA256SUMS`** with every release (the release workflow does this).
- **macOS permissions follow the code signature.** Even unsigned builds need an ad-hoc signature with a stable identifier, and the hardened runtime needs the JIT entitlements.
- **Native helpers live outside the app archive**, and packaging fails if a platform's helper is missing.
- **Never fall back from the keychain to plaintext.** If secure storage is unavailable, refuse.
- **Contract-first for any backend:** an OpenAPI spec, a mock validated against it that answers 501 for anything unmocked, and integration tests of the real client against the mock.
- **Crash-safe recording:** write fragmented or `.part` files, recover on start, never delete a file you cannot read.
- **Android backgrounding:** foreground services must declare their type on Android 14+; WebViews stop JavaScript about a minute after the screen goes off (not an issue for Flutter, which is one reason the base is Flutter).
- **Refresh tokens:** single-flight refresh; save the new token before using it; network errors, 5xx and 429 are never a sign-out.
- CI must actually run. Spreix's workflows were only linted locally (billing); a workflow that has never run is not a pipeline.
