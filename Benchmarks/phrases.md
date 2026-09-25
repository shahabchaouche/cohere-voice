# Benchmark phrases

Use the same spoken samples between builds. Track transcription accuracy, rewrite quality, and post-release latency.

## Normal conversation

- hey mike yeah that looks good to me i'll review the pr tonight
- um hey Sarah could you maybe send me those numbers from yesterday before lunch
- hey yeah looks good i'll merge it after lunch

## Self-corrections

- Schedule it Friday afternoon... actually Monday morning works better.
- Send the meeting invite Friday morning... actually make that Monday at 10.
- The variable should be user name... actually call it display name.

## Technical speech

- tell codex to open user service dot swift and change fetch user to async await
- In UserService dot swift make fetch user async throws and return a user.
- open authentication service dot swift and change sign in to async throws
- create an async function called fetch users that returns an array of user

## Names

- Can you ping Alex and the design team on Slack?
- Ask the mobile team to review the Cohere integration.

## Numbers and URLs

- The meeting is at 10 30 on March 14.
- Open docs dot cohere dot com slash reference slash create audio transcription

## Programming terminology

- AVAudioEngine AVAudioPCMBuffer Sendable MainActor URLSession
- wrap the call in a Task group and mark the type Codable

## English / French code-switching

- On va deployer vendredi but make sure the database migration runs Thursday night.

## Email

- hi sarah thanks for the update i'll take a look tomorrow morning and get back to you
- hi john thanks for sending this i'll review it this afternoon and get back to you

## Background noise

- Repeat a short sentence with a fan or cafe noise in the room. Note WER and whether VAD still trims correctly.

## Demo acceptance

1. Slack — conversational cleanup
2. Self-correction — keep only the corrected version
3. Cursor — developer backticks
4. Mail — greeting + paragraph
5. Code-switching — preserve both languages
