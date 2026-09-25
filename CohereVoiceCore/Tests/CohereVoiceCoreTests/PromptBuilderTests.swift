import Testing
@testable import CohereVoiceCore

struct PromptBuilderTests {
    @Test func standardIncludesCleanupRules() {
        let prompt = PromptBuilder.systemPrompt(context: DictationContext(mode: .standard))
        #expect(prompt.contains("Remove filler words"))
        #expect(prompt.contains("Output ONLY the rewritten text"))
        #expect(!prompt.contains("UserService.swift"))
    }

    @Test func developerIncludesTerminology() {
        let prompt = PromptBuilder.systemPrompt(context: DictationContext(mode: .developer))
        #expect(prompt.contains("backticks"))
        #expect(prompt.contains("SwiftUI"))
        #expect(prompt.contains("only output code when clearly dictating code"))
    }

    @Test func rawDoesNotRemoveFillers() {
        let prompt = PromptBuilder.systemPrompt(context: DictationContext(mode: .raw))
        #expect(prompt.contains("Do not remove filler words"))
    }

    @Test func mailHintAndDictionaryInjected() {
        let context = DictationContext(
            bundleIdentifier: "com.apple.mail",
            applicationName: "Mail",
            mode: .standard,
            dictionaryTerms: ["Alex", "Northwind"]
        )
        let prompt = PromptBuilder.systemPrompt(context: context)
        #expect(context.styleHint == .email)
        #expect(prompt.contains("short email"))
        #expect(prompt.contains("Alex"))
        #expect(prompt.contains("Northwind"))
        #expect(prompt.contains("Mail"))
    }

    @Test func slackIsConversational() {
        let context = DictationContext(bundleIdentifier: "com.tinyspeck.slackmacgap", applicationName: "Slack")
        #expect(context.styleHint == .conversational)
    }

    @Test func cursorIsTechnical() {
        let context = DictationContext(bundleIdentifier: "com.todesktop.230313mzl4w4u92", applicationName: "Cursor")
        #expect(context.styleHint == .technical)
    }

    @Test func keepsRewriteInSpokenLanguage() {
        let context = DictationContext(mode: .standard, language: "fr")
        let prompt = PromptBuilder.systemPrompt(context: context)
        #expect(prompt.contains("French"))
        #expect(prompt.contains("Do not translate"))
    }

    @Test func unknownLanguageCodeFallsBackToEnglish() {
        #expect(TranscriptionLanguage.from(stored: "xx") == .english)
        #expect(TranscriptionLanguage.allCases.count == 14)
    }

    @Test func selectedTextIsLimitedTo400Characters() {
        let prompt = PromptBuilder.systemPrompt(
            context: DictationContext(selectedText: String(repeating: "x", count: 450), includeSelectedText: true)
        )
        #expect(prompt.contains(String(repeating: "x", count: 400) + "…"))
        #expect(!prompt.contains(String(repeating: "x", count: 401)))
    }

    @Test func selectedTextIsExcludedWithoutExplicitPermission() {
        let context = DictationContext(selectedText: "private selection")
        #expect(!PromptBuilder.systemPrompt(context: context).contains("private selection"))
    }
}
