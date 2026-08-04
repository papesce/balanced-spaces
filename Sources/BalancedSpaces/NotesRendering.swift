import Foundation
import AppKit

/// Renders plain-text notes with two lightweight affordances:
/// `==highlighted==` spans get a highlight background, and detected URLs
/// become clickable links. Not Markdown — just enough for notes.
func renderNotes(_ text: String) -> AttributedString {
    var result = AttributedString()
    let lines = text.components(separatedBy: "\n")
    for (index, line) in lines.enumerated() {
        result += renderLine(line)
        if index < lines.count - 1 {
            result += AttributedString("\n")
        }
    }
    return result
}

private func renderLine(_ line: String) -> AttributedString {
    var result = AttributedString()
    let nsLine = line as NSString
    var cursor = 0

    while cursor < nsLine.length {
        let openRange = nsLine.range(of: "==", options: [], range: NSRange(location: cursor, length: nsLine.length - cursor))
        guard openRange.location != NSNotFound else {
            result += linkify(nsLine.substring(from: cursor))
            break
        }
        let closeSearchStart = openRange.location + openRange.length
        let closeRange = nsLine.range(of: "==", options: [], range: NSRange(location: closeSearchStart, length: nsLine.length - closeSearchStart))
        guard closeRange.location != NSNotFound, closeRange.location > closeSearchStart else {
            result += linkify(nsLine.substring(from: cursor))
            break
        }

        if openRange.location > cursor {
            result += linkify(nsLine.substring(with: NSRange(location: cursor, length: openRange.location - cursor)))
        }

        let highlighted = nsLine.substring(with: NSRange(location: closeSearchStart, length: closeRange.location - closeSearchStart))
        var highlightedAttr = linkify(highlighted)
        highlightedAttr.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.35)
        result += highlightedAttr

        cursor = closeRange.location + closeRange.length
    }

    return result
}

private func linkify(_ text: String) -> AttributedString {
    guard !text.isEmpty else { return AttributedString() }
    var attributed = AttributedString(text)
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
        return attributed
    }
    let nsText = text as NSString
    let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
    for match in matches {
        guard let url = match.url, let range = Range(match.range, in: text) else { continue }
        if let attrRange = Range(range, in: attributed) {
            attributed[attrRange].link = url
        }
    }
    return attributed
}
