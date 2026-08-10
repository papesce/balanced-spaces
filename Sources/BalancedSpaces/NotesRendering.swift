import Foundation
import AppKit
import SwiftUI

/// Applies lightweight notes affordances directly onto a live `NSTextStorage`:
/// `==highlighted==` spans get a highlight background and detected URLs become
/// clickable. `[label](destination)` links are deliberately left plain while
/// editing — they only become clickable in the read-only display. Not Markdown —
/// just enough for notes. Safe to call on every keystroke since it preserves
/// selection and the base font.
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

    // `[label](destination)` links stay plain while editing so clicks position
    // the cursor. This also strips any link the auto-detector found inside the
    // destination (e.g. the URL in `[Docs](https://example.com)`).
    for match in NoteLink.regex.matches(in: storage.string, options: [], range: fullRange) {
        storage.removeAttribute(.link, range: match.range)
        storage.removeAttribute(.underlineStyle, range: match.range)
    }
    storage.endEditing()
}

/// Builds the read-only notes display: `[label](destination)` links collapse to
/// just `label` (clickable, with a tooltip showing the target), while everything
/// else keeps the usual highlights and auto-detected URLs.
func renderedNotesDisplay(_ text: String) -> NSMutableAttributedString {
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
                .toolTip: destination,
            ]))
        } else {
            appendHighlightedSegment(nsText.substring(with: match.range), to: output)
        }
        cursor = match.range.location + match.range.length
    }

    if cursor < nsText.length {
        appendHighlightedSegment(nsText.substring(with: NSRange(location: cursor, length: nsText.length - cursor)), to: output)
    }

    return output
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

/// A clickable folder shortcut: a folder path in a `[label](~/dev/project)` link
/// opens Terminal.app with that folder as the working directory. Paths are
/// carried through a custom URL scheme so normal web links keep their default
/// behavior.
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

/// Read-only notes display backed by `NSTextView`, so links get native macOS
/// hover feedback: a pointing-hand cursor and a tooltip with the destination.
/// Clicking routes terminal links to `TerminalLink` and lets everything else
/// fall through to the default browser behavior.
struct NotesDisplayTextView: NSViewRepresentable {
    let text: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NotesTextView {
        let textView = NotesTextView()
        textView.delegate = context.coordinator
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 0, height: 1)
        textView.allowsUndo = false
        textView.textStorage?.setAttributedString(renderedNotesDisplay(text))
        textView.refit()
        return textView
    }

    func updateNSView(_ textView: NotesTextView, context: Context) {
        if textView.string != text {
            textView.textStorage?.setAttributedString(renderedNotesDisplay(text))
            textView.refit()
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            guard let url = link as? URL, let path = TerminalLink.path(from: url) else { return false }
            TerminalLink.open(at: path)
            return true
        }
    }
}

/// `NSTextView` subclass that sizes itself to its laid-out text so SwiftUI can
/// place it in the popover without a fixed height.
final class NotesTextView: NSTextView {
    private var isRefitting = false

    override var intrinsicContentSize: NSSize {
        guard let layoutManager, let textContainer else { return super.intrinsicContentSize }
        layoutManager.ensureLayout(for: textContainer)
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        let textRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        let height = ceil(textRect.height) + textContainerInset.height * 2
        return NSSize(width: NSView.noIntrinsicMetric, height: height)
    }

    func refit() {
        guard !isRefitting else { return }
        isRefitting = true
        defer { isRefitting = false }
        if let layoutManager, let textContainer {
            layoutManager.ensureLayout(for: textContainer)
        }
        invalidateIntrinsicContentSize()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        invalidateIntrinsicContentSize()
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
            NotesDisplayTextView(text: text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
