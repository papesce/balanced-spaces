import Foundation
import AppKit
import SwiftUI

/// Applies lightweight notes affordances directly onto a live `NSTextStorage`:
/// `==highlighted==` spans get a highlight background, detected URLs and
/// `[label](destination)` links become clickable, and backticked folder paths
/// open Terminal. Not Markdown — just enough for notes. Safe to call on every
/// keystroke since it preserves selection and the base font.
func applyNotesHighlighting(to storage: NSTextStorage) {
    let fullRange = NSRange(location: 0, length: storage.length)
    let baseFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
    storage.beginEditing()
    storage.removeAttribute(.backgroundColor, range: fullRange)
    storage.removeAttribute(.link, range: fullRange)
    storage.removeAttribute(.underlineStyle, range: fullRange)
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

    if let backtickRegex = try? NSRegularExpression(pattern: "`([^`\\n]*)`") {
        let matches = backtickRegex.matches(in: storage.string, options: [], range: fullRange)
        for match in matches {
            let pathRange = match.range(at: 1)
            let path = (storage.string as NSString).substring(with: pathRange)
            guard !path.isEmpty, let url = TerminalLink.makeURL(for: path) else { continue }
            storage.addAttribute(.link, value: url, range: match.range)
            storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
        }
    }

    for match in NoteLink.regex.matches(in: storage.string, options: [], range: fullRange) {
        let destination = nsText.substring(with: match.range(at: 2))
        guard let url = NoteLink.makeURL(for: destination) else { continue }
        storage.addAttribute(.link, value: url, range: match.range)
        storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
    }
    storage.endEditing()
}

/// Builds the read-only notes display: `[label](destination)` links collapse to
/// just `label` (clickable), while everything else keeps the usual highlights,
/// backticks, and auto-detected URLs.
func renderedNotesDisplay(_ text: String) -> AttributedString {
    let nsText = text as NSString
    let output = NSMutableAttributedString()
    var cursor = 0
    let matches = NoteLink.regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

    for match in matches {
        if match.range.location > cursor {
            appendHighlightedSegment(nsText.substring(with: NSRange(location: cursor, length: match.range.location - cursor)), to: output)
        }
        let label = nsText.substring(with: match.range(at: 1))
        let destination = nsText.substring(with: match.range(at: 2))
        if !label.isEmpty, let url = NoteLink.makeURL(for: destination) {
            output.append(NSAttributedString(string: label, attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                .link: url,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
            ]))
        } else {
            appendHighlightedSegment(nsText.substring(with: match.range), to: output)
        }
        cursor = match.range.location + match.range.length
    }

    if cursor < nsText.length {
        appendHighlightedSegment(nsText.substring(with: NSRange(location: cursor, length: nsText.length - cursor)), to: output)
    }

    return AttributedString(output)
}

private func appendHighlightedSegment(_ segment: String, to output: NSMutableAttributedString) {
    let storage = NSTextStorage(string: segment)
    applyNotesHighlighting(to: storage)
    output.append(storage)
}

/// A clickable `[label](destination)` link. The `destination` is either a URL
/// (opens in the default browser) or a folder path (opens Terminal.app in that
/// folder, validated at click time). Only the label is shown in the display.
enum NoteLink {
    static let regex = try! NSRegularExpression(pattern: "\\[([^\\[\\]\\n]*)\\]\\(([^()\\n]+)\\)")

    static func makeURL(for destination: String) -> URL? {
        let trimmed = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if isWebDestination(trimmed) {
            return webURL(from: trimmed)
        }
        return TerminalLink.makeURL(for: trimmed)
    }

    private static func isWebDestination(_ destination: String) -> Bool {
        destination.contains("://") || destination.hasPrefix("www.")
    }

    private static func webURL(from destination: String) -> URL? {
        if destination.hasPrefix("www.") {
            return URL(string: "https://" + destination)
        }
        return URL(string: destination)
    }
}

/// A clickable folder shortcut: a backticked path in notes (e.g. `` `~/dev/project` ``)
/// opens Terminal.app with that folder as the working directory. Paths are carried
/// through a custom URL scheme so normal web links keep their default behavior.
enum TerminalLink {
    static let scheme = "balanced-spaces-open-terminal"

    static func makeURL(for path: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "path", value: path)]
        return components.url
    }

    static func isTerminalURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == scheme
    }

    static func path(from url: URL) -> String? {
        guard isTerminalURL(url),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let item = components.queryItems?.first(where: { $0.name == "path" }) else { return nil }
        return item.value
    }

    /// Resolves the path and opens Terminal.app there. The path is validated at
    /// click time (not per keystroke) to keep typing cheap.
    @MainActor
    static func open(at path: String) {
        let expanded = (path as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        let fileManager = FileManager.default
        guard expanded.hasPrefix("/"),
              fileManager.fileExists(atPath: expanded, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            presentError("“\(path)” isn’t a folder.")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", expanded]
        process.terminationHandler = { process in
            if process.terminationStatus != 0 {
                Task { @MainActor in presentError("Terminal couldn’t open “\(expanded)”.") }
            }
        }
        do {
            try process.run()
        } catch {
            presentError("Couldn’t open Terminal: \(error.localizedDescription)")
        }
    }

    @MainActor
    private static func presentError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Can’t open Terminal here"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
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
                .environment(\.openURL, OpenURLAction { url in
                    if let path = TerminalLink.path(from: url) {
                        TerminalLink.open(at: path)
                        return .handled
                    }
                    return .systemAction
                })
        }
    }

    private var attributedText: AttributedString {
        renderedNotesDisplay(text)
    }
}

/// Static, non-editable description display for the read-only row state.
struct DescriptionPlainTextView: View {
    let text: String

    var body: some View {
        if !text.isEmpty {
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
