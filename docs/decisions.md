# Design decisions

Facts behind the current architecture. Not a changelog.

## Carbon hotkey, not CGEvent tap

The previous active tap intercepted the key events it monitored; a stalled callback froze the keyboard including Enter. `RegisterEventHotKey` claims one chord, consumes it, cannot stall unrelated typing, and needs no Input Monitoring. Fn cannot be registered via Carbon, so it uses a listen-only `NSEvent` monitor, which needs permission to observe keys in other apps. Carbon sometimes omits `kEventHotKeyReleased`, hence the 50 ms `CGEventSource.flagsState` poll.

## Stable install and signing identity for TCC

Privacy grants can fail to follow a development build launched from another location or signed with a different identity. macOS also uses the app's code-signing designated requirement to recognize it for protected resources. The optional `Scripts/run.sh` installs and launches a signed app from a stable `/Applications` path, while requiring the developer to supply their own team ID. A different stable install path can work; `/Applications` is not a TCC requirement.

## Lazy `AVAudioEngine`

Microphone input setup can trigger the TCC prompt. The engine and its input node are first accessed on `start()`, after onboarding requests microphone access, rather than at launch.

## Keychain without prompts

A key added via the `security` CLI carried an ACL that produced a password sheet on first read. Routine `loadAPIKey` calls disallow authentication UI and run off the main thread. Settings offers an explicit Repair Access action for an existing key that needs authorization; saving uses an update or add without deleting an existing item first.

## `AVAudioSession` is iOS-only

All session code is behind `#if os(iOS)`; macOS uses `AVAudioEngine` alone.

## Two models, not one

Transcribe requires an explicit language and does no auto-detect; Command rewrites. If transcription succeeds but the rewrite fails, the raw transcript is used for insertion. Transcription and insertion can still fail separately.

## Selected-text context requires opt-in

The macOS app uses the active app name and saved dictionary terms when rewriting. Text selected in another app may be sensitive, so a separate Settings toggle controls whether up to 400 selected characters are read and sent with the rewrite prompt. The toggle defaults off for new and existing users; turning off rewriting also prevents selection capture.

## Zero third-party dependencies

Multipart uploads, WAV encoding, Keychain access, and voice activity detection are implemented in the repo without third-party code. Their core behavior is covered by tests. The checked-in Xcode project and local Swift package are built directly without a third-party project generator.

## Regular window app, not LSUIElement

Menu-bar mode hid onboarding and made Keychain sheets appear off-screen; a Dock app with a window is discoverable.
