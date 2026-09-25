import AppKit
import CoreGraphics

@MainActor
final class TextInsertionService {
    private let accessibility = AccessibilityService()
    private let pasteboard = NSPasteboard.general

    func insert(_ text: String) throws {
        if let element = accessibility.focusedElement(),
           accessibility.setSelectedText(text, on: element) {
            return
        }
        try pasteFallback(text)
    }

    func selectedText() -> String? {
        guard let element = accessibility.focusedElement() else { return nil }
        return accessibility.selectedText(of: element)
    }

    private func pasteFallback(_ text: String) throws {
        let previousChangeCount = pasteboard.changeCount
        let previousItems = snapshotPasteboard()

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        pasteboard.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))

        guard postPaste() else {
            restorePasteboard(previousItems)
            throw DictationErrorBridge.insertionFailed
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            if self.pasteboard.changeCount == previousChangeCount + 1 {
                self.restorePasteboard(previousItems)
            }
        }
    }

    private func postPaste() -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyCode = CGKeyCode(9) // V
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else {
            return false
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }

    private func snapshotPasteboard() -> [NSPasteboardItem] {
        (pasteboard.pasteboardItems ?? []).compactMap { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }
    }

    private func restorePasteboard(_ items: [NSPasteboardItem]) {
        pasteboard.clearContents()
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }
}

enum DictationErrorBridge {
    static let insertionFailed = NSError(
        domain: "CohereVoice",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "insertion failed"]
    )
}
