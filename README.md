# Cohere Voice

Hold a shortcut, speak, release. Speech is transcribed with Cohere Transcribe, cleaned with Cohere Command, and inserted at the cursor of the frontmost app.

An unofficial macOS and iOS client for Cohere's models. Not affiliated with Cohere.

## Features

- Hold-to-talk global shortcut (⌥ Space default; ⌃ Space, ⌘ ⇧ Space; Fn optional) via Carbon `RegisterEventHotKey` — claims one chord instead of a system-wide tap
- `AVAudioEngine` capture with a native-format tap, RMS metering, energy-based voice activity detection, silence trim, and 16 kHz mono WAV encoding
- Cohere Transcribe (`cohere-transcribe-03-2026`) and Command (`command-a-plus-05-2026`)
- 14 Cohere Transcribe languages; the rewrite stays in the spoken language
- Standard, Developer, and Raw rewrite modes
- Active-app formatting hints (Slack, Mail, Xcode, Cursor, browsers)
- Accessibility insertion, with a clipboard fallback for Electron apps
- Local history, a personal dictionary, and a Keychain-stored API key
- A per-stage latency panel (T0–T7)

## How it's built

The Mac app is Swift 6 and SwiftUI. Shared logic lives in `CohereVoiceCore`, a Swift package with no AppKit dependency, so the same transcription path runs on iOS.

There are no third-party code or build-tool dependencies. Multipart uploads, WAV encoding, Keychain access, and voice activity detection are implemented in the repo. The checked-in Xcode project is the source of truth for the app targets; `CohereVoiceCore` is a local Swift package.

The iPhone app records in-app and lets you copy or share the text. A global shortcut and inserting into other apps are Mac-only.

## Architecture

```text
                         ┌─────────────────────┐
                         │   Global Shortcut   │
                         └──────────┬──────────┘
                                    │
                                    ▼
                         ┌─────────────────────┐
                         │    AVAudioEngine    │
                         └──────────┬──────────┘
                                    │ PCM
                                    ▼
                         ┌─────────────────────┐
                         │   Audio Pipeline    │
                         │ VAD / Metering      │
                         │ Resampling          │
                         └──────────┬──────────┘
                                    │
                                    ▼
                         ┌─────────────────────┐
                         │ Cohere Transcribe   │
                         └──────────┬──────────┘
                                    │
                               Raw Transcript
                                    │
                                    ▼
                         ┌─────────────────────┐
                         │   Cohere Command    │
                         │ Context / Cleanup   │
                         └──────────┬──────────┘
                                    │
                                    ▼
                         ┌─────────────────────┐
                         │ Accessibility API   │
                         └──────────┬──────────┘
                                    │
                                    ▼
                              Active App
```

## Build and run

Open `CohereVoice.xcodeproj` in Xcode. Choose the **CohereVoice** scheme for macOS or **CohereVoiceiOS** for iOS Simulator. To run a signed app, select your own Apple development team in Signing & Capabilities. A physical iOS device also needs a bundle identifier available to your team; keep that change local.

To build and test from Terminal without signing:

```bash
swift test --package-path CohereVoiceCore
xcodebuild -project CohereVoice.xcodeproj -scheme CohereVoice \
  -configuration Debug -destination 'platform=macOS' -derivedDataPath build \
  test CODE_SIGNING_ALLOWED=NO
xcodebuild -project CohereVoice.xcodeproj -scheme CohereVoiceiOS \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build build CODE_SIGNING_ALLOWED=NO
```

For a signed macOS app installed at a stable path, use the optional script with your team ID:

```bash
DEVELOPMENT_TEAM=YOUR_TEAM_ID ./Scripts/run.sh
```

It installs to `/Applications/CohereVoice.app` by default; set `INSTALL_DIR=~/Applications` to use a different stable location. It asks before replacing an existing installation. macOS recognizes protected-resource access using the app's signing requirement and identity; keeping the same signing team, bundle identifier, and install location helps privacy grants persist across development builds.

Open **Settings → API** and paste a Cohere API key (stored in Keychain). Grant Microphone when prompted, then add Cohere Voice under System Settings → Privacy & Security → Accessibility.

### Troubleshooting

- `xcode-select: error: tool 'xcodebuild' requires Xcode` → `sudo xcode-select -s /Applications/Xcode.app` or `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
- ⌥ Space already taken (Alfred and others) → pick another chord in the main window
- App missing from the Accessibility list → launch the signed app, then add that app in System Settings. Check its signing identity and install path if an earlier grant does not carry over.

## Implementation notes

- The input tap uses the hardware format. Work on the realtime thread is limited to copying samples and yielding an `AsyncStream`.
- `AVAudioPCMBuffer` is not `Sendable`. Owned `Data` / `[Float]` crosses actors.
- `AVAudioConverter` resamples to 16 kHz mono Int16. WAV headers are written in the repo and unit-tested.
- Carbon `RegisterEventHotKey` claims one chord and consumes it. A 50 ms modifier-flag poll covers Carbon occasionally dropping the key-up. An earlier active `CGEvent` tap was removed after it stalled the keyboard (see [docs/decisions.md](docs/decisions.md)).
- Insertion tries Accessibility `kAXSelectedTextAttribute` first. Slack and Cursor fall back to a transient clipboard paste, then the previous clipboard is restored.
- The pipeline, networking, and metrics are actors. UI state is one `@Observable` `@MainActor` model.
- Route changes finish the current take instead of leaving the recorder stuck.
- If transcription succeeds but rewriting fails, the raw transcript is used for insertion. Insertion can still fail separately.

## Demo phrases

See [Benchmarks/phrases.md](Benchmarks/phrases.md) and try Slack, a self-correction, Cursor, Mail, and English/French code-switching.

## Privacy

Microphone audio is sent to Cohere for transcription. When **Clean up transcript** is on, the transcript is sent to Cohere again for rewriting, along with the active app name and any saved personal dictionary terms. On macOS, **Include selected text in rewrites** can additionally send up to 400 characters selected in the active app. This setting is off by default, including for existing installs.

On macOS, local text history is on by default and is stored as JSON at `~/Library/Application Support/CohereVoice/history.json`; turn it off in Settings to stop new entries, or use **Clear history** to delete existing entries. WAV saving is off by default and, when enabled, writes to `~/Library/Application Support/CohereVoice/recordings/`. API keys are stored in the system Keychain. The iOS app keeps the current transcript in memory for copying or sharing and does not use the macOS history store.

## Design decisions

See [docs/decisions.md](docs/decisions.md) for the hotkey, the Applications install path, and the other constraints.

## License

The source code, documentation, and original app artwork are licensed under MIT. See [LICENSE](LICENSE). The app icon and launch artwork were created for this project using Paper MCP.
