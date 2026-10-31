---
name: release
description: Build and release an app on the base platform for Android, iOS, macOS, Windows, Linux and web - signing, version numbers, CI workflows, checksums and store readiness. Use when the user wants builds, installers, a release, or to set up signing for a new app.
---

# Release an app

One codebase, six targets. Builds run in GitHub Actions (`.github/workflows/release.yml`) because macOS and iOS need macOS runners and Windows needs a Windows runner. Locally you can only build what the host OS supports.

## Versions

`apps/<app>/pubspec.yaml → version: 1.4.0+12` (name + build number). CI passes `--build-name` from the tag and `--build-number` from the run number. Tag format: `<app>-v1.4.0` (one repo, many apps).

## Signing (once per vendor, shared by every app)

Until the secrets below exist, every Android build (debug and release, local and CI) is signed with the public vendor **test key**, `signing/showcase-test.jks`, which `./base sync` also puts into Burrow and PhoneDots. So sideloaded builds of every app update in place and share models from day one; release files built with it are named `-TESTKEY`. How to make your real key without a Play account: `signing/README.md`. `./base check` fails an app that doesn't sign with the vendor key.

| Platform | What | Secrets |
| --- | --- | --- |
| Android | one release keystore for **every** app (the shared-model permission is signature-level) | `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` |
| iOS / macOS | Apple team, the App Group `group.com.showcase.shared` registered and enabled for each bundle id, provisioning profiles | `APPLE_CERTIFICATE_P12_BASE64`, `APPLE_CERTIFICATE_PASSWORD`, `APPLE_TEAM_ID`, `APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD` |
| Windows | code-signing certificate (optional but SmartScreen warns without) | `WIN_CSC_LINK`, `WIN_CSC_KEY_PASSWORD` |

Never commit your real key. The test key is public: fine for sideloaded test builds, never for a store release.

## Commands per target (from `apps/<app>`)

```bash
flutter build apk --release --target-platform android-arm64     # sideload
flutter build appbundle --release                                # Play
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist   # macOS host
flutter build macos --release                                    # then sign + notarize (CI)
flutter build windows --release                                  # Windows host; MSIX via msix package or Inno Setup
flutter build linux --release                                    # Linux host; tarball/AppImage/Flatpak
flutter build web --release --base-href /<app>/                  # serve every app from one origin to share models
```

Web: host every app under one origin (`apps.example.com/notes/`, `apps.example.com/talks/`) so they share the browser's model cache.

## The workflow

`release.yml` runs on a tag `<app>-v*` or by hand (`app`, `version`):

1. `check`: `./base gen --check`, `./base check`, analyze, tests.
2. One job per platform (ubuntu: android, linux, web; macos: ios, macos; windows: windows).
3. Unsigned or debug artifacts get `-UNSIGNED` in the file name; Android artifacts signed with the test key get `-TESTKEY`.
4. `publish`: `SHA256SUMS.txt` over every artifact, a GitHub release; any `UNSIGNED` artifact makes it a pre-release with a warning.

## Before the first public release of an app

- [ ] drop the starter's `design` tab; real icon on every platform
- [ ] `./base check` with 0 warnings (every model file has a checksum)
- [ ] signed with the shared Android key; App Group enabled for the bundle id (iOS, macOS)
- [ ] the widget test covers onboarding and every tab at phone width
- [ ] a run on a real phone: onboarding downloads the model, a second app reuses it (models page shows "shared with 1 other app")
- [ ] privacy copy is true for this app (ledger sentences, what it fetches)
- [ ] store listings: privacy labels say "no data collected" only if that is true
