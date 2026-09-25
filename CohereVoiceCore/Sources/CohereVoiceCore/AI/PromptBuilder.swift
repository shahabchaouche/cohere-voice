public enum PromptBuilder {
    public static let developerTerminology: [String] = [
        "SwiftUI", "UIKit", "async/await", "actor", "Codable", "Supabase",
        "Postgres", "API", "JSON", "REST", "GraphQL", "GitHub", "pull request",
        "PR", "Xcode", "Cursor", "Codex", "Claude", "Cohere", "TypeScript",
        "React", "Next.js", "AVAudioEngine", "AVAudioPCMBuffer", "Sendable",
        "MainActor", "NSAccessibility", "URLSession",
    ]

    public static func systemPrompt(context: DictationContext) -> String {
        var parts: [String] = [basePrompt(for: context.mode)]
        parts.append(context.styleHint.promptInstruction)

        if context.mode == .developer {
            parts.append(developerAddendum)
            parts.append("Known technical terms: \(developerTerminology.joined(separator: ", ")).")
        }

        if !context.dictionaryTerms.isEmpty {
            parts.append("Vocabulary the speaker uses: \(context.dictionaryTerms.joined(separator: ", ")).")
        }

        if let app = context.applicationName, !app.isEmpty {
            parts.append("The user is dictating into \(app).")
        }

        if context.includeSelectedText, let selected = context.selectedText, !selected.isEmpty {
            let clipped = selected.count > 400 ? String(selected.prefix(400)) + "…" : selected
            parts.append("The current selection is:\n\(clipped)")
        }

        let language = TranscriptionLanguage.from(stored: context.language)
        parts.append(
            "The transcript is in \(language.displayName). Keep the rewritten output in \(language.displayName). Do not translate."
        )

        parts.append("Output ONLY the rewritten text. No preamble, no quotes, no explanations.")
        return parts.joined(separator: "\n\n")
    }

    public static func basePrompt(for mode: DictationMode) -> String {
        switch mode {
        case .standard:
            """
            You clean up dictated speech. Rewrite the user's transcript:
            - Remove filler words (um, uh, like, you know).
            - Fix grammar and punctuation.
            - Apply self-corrections: when the speaker corrects themselves ("...actually..."), keep only the corrected version.
            - Preserve the speaker's meaning, tone, and intent. Never add new content.
            """
        case .developer:
            """
            You clean up dictated speech from a software engineer. Rewrite the user's transcript:
            - Remove filler words (um, uh, like, you know).
            - Fix grammar and punctuation.
            - Apply self-corrections: when the speaker corrects themselves ("...actually..."), keep only the corrected version.
            - Preserve the speaker's meaning, tone, and intent. Never add new content.
            - Preserve technical terminology exactly.
            - Wrap file names, symbols, type names, and APIs in backticks (for example UserService.swift, fetchUser, async throws).
            - Infer whether the user is speaking prose about code or dictating literal code; only output code when clearly dictating code.
            """
        case .raw:
            """
            You lightly clean a speech-to-text transcript.
            - Add punctuation and capitalization.
            - Fix only obvious transcription errors.
            - Do not remove filler words.
            - Do not rewrite phrasing, tone, or structure.
            - Do not apply self-corrections beyond punctuation.
            """
        }
    }

    private static let developerAddendum = """
    Spoken programming phrases should become conventional identifiers when the user is naming things:
    "user service dot swift" → `UserService.swift`
    "fetch user" as a function name → `fetchUser`
    "async await" → async/await
    """
}
