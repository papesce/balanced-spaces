import Foundation
import AppKit
import SwiftUI

/// Applies lightweight notes affordances directly onto a live `NSTextStorage`:
/// `==highlighted==` spans get a highlight background, and detected URLs
/// become clickable links. Not Markdown — just enough for notes. Safe to call
/// on every keystroke since it preserves selection and the base font.
func applyNotesHighlighting(to storage: NSTextStorage) {
    let fullRange = NSRange(location: 0, length: storage.length)
    let baseFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
    storage.beginEditing()
    storage.removeAttribute(.backgroundColor, range: fullRange)
    storage.removeAttribute(.link, range: fullRange)
    storage.addAttribute(.font, value: baseFont, range: fullRange)

    let nsText = storage.string as NSString
    var cursor = 0
    while cursor < nsText.length {
        let openRange = nsText.range(of: "==", options: [], range: NSRange(location: cursor, length: nsText.length - cursor))
        guard openRange.location != NSNotFound else { break }
        let closeSearchStart = openRange.location + openRange.length
        let closeRange = nsText.range(of: "==", options: [], range: NSRange(location: closeSearchStart, length: nsText.length - closeSearchStart))
        guard closeRange.location != NSNotFound, closeRange.location > closeSearchStart else { break }

        let highlightRange = NSRange(location: closeSearchStart, length: closeRange.location - closeSearchStart)
        storage.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.35), range: highlightRange)

        cursor = closeRange.location + closeRange.length
    }

    if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
        let matches = detector.matches(in: storage.string, options: [], range: fullRange)
        for match in matches {
            guard let url = match.url else { continue }
            storage.addAttribute(.link, value: url, range: match.range)
        }
    }
    storage.endEditing()
}

/// Static, non-editable notes display for the read-only row state: same
/// highlighting/link affordances as the editor, but no input chrome.
struct NotesPlainTextView: View {
    let text: String

    var body: some View {
        if text.isEmpty {
            Text("Notes…")
                .font(.callout)
                .foregroundStyle(.tertiary)
        } else {
            Text(attributedText)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var attributedText: AttributedString {
        let storage = NSTextStorage(string: text)
        applyNotesHighlighting(to: storage)
        return AttributedString(storage)
    }
}
