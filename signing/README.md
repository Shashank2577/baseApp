# Signing

Every app of the vendor must be signed with the **same key**. The shared model store's Android permission is signature-level, so apps signed with different keys can't hand models to each other (docs/MODEL_STORE.md), and a build signed with another key can't install over an existing one.

## The test key (`showcase-test.jks`)

Public and committed, so any build of any app (debug, CI, release) is signed alike and sideloaded builds update in place and share models. It is not secret: never publish to a store with it.

| | |
| --- | --- |
| file | `signing/showcase-test.jks` (synced into each app by `./base sync`) |
| store password | `phonedots-test` |
| alias | `phonedots-test` |
| key password | `phonedots-test` |
| SHA-256 | `E6:B2:6D:A2:2D:F2:CF:35:66:75:B2:31:09:38:B6:5D:22:0F:72:FB:C5:40:0A:97:63:0B:85:2E:99:4A:AB:AA` |

(It started as PhoneDots' test key, so PhoneDots installs keep updating in place.)

## Your own release key

No developer account is needed to make one; the Play Console ($25) is only for publishing on Google Play.

1. Install a JDK 17+ (or use the one inside Android Studio: `<Android Studio>/jbr/bin/keytool`).
2. `keytool -genkeypair -v -keystore showcase-release.jks -alias showcase -keyalg RSA -keysize 4096 -validity 10000`
3. Keep the file and the password in a password manager, with a backup. Lose it and no app signed with it can ever be updated.
4. `base64 -w0 showcase-release.jks` (macOS: `base64 -i showcase-release.jks`), and in **every** app repo add the Actions secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`showcase`) and `ANDROID_KEY_PASSWORD`.
5. Never commit it. Builds use it when the secrets exist and the test key otherwise.

Moving from the test key to your key changes the signature: uninstall the test builds once (their data and models go with them).
