import SwiftUI
import AppKit

/// A TextEditor with a lightweight Markdown formatting toolbar and a
/// read-only rendered preview toggle. Selection-aware wrapping (bold,
/// italic) is done via an NSTextView bridge since SwiftUI's TextEditor
/// doesn't expose the current selection.
struct MarkdownNotesEditor: View {
    @Binding var text: String
    var placeholder: String = "Notes…"
    var minHeight: CGFloat = 56
    var maxHeight: CGFloat = 96

    @State private var showPreview = false
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            toolbar
            if showPreview {
                ScrollView {
                    Text(renderedMarkdown)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                }
                .frame(minHeight: minHeight, maxHeight: maxHeight)
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
            } else {
                SelectionTrackingTextView(text: $text, selectedRange: $selectedRange)
                    .frame(minHeight: minHeight, maxHeight: maxHeight)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text(placeholder)
                                .font(.callout)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button { wrap(with: "**") } label: {
                Image(systemName: "bold")
            }
            .help("Bold")
            Button { wrap(with: "*") } label: {
                Image(systemName: "italic")
            }
            .help("Italic")
            Button { prefixLine(with: "# ") } label: {
                Image(systemName: "number")
            }
            .help("Heading")
            Button { prefixLine(with: "- [ ] ") } label: {
                Image(systemName: "checklist")
            }
            .help("Checklist item")
            Spacer()
            Button(showPreview ? "Edit" : "Preview") {
                showPreview.toggle()
            }
            .font(.caption)
        }
        .buttonStyle(.borderless)
        .font(.callout)
    }

    private var renderedMarkdown: AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }

    private func wrap(with marker: String) {
        guard let range = Range(selectedRange, in: text), !range.isEmpty else {
            text += marker + marker
            return
        }
        let selected = text[range]
        text.replaceSubrange(range, with: "\(marker)\(selected)\(marker)")
    }

    private func prefixLine(with marker: String) {
        guard let range = Range(selectedRange, in: text) else {
            text = marker + text
            return
        }
        let lineRange = text.lineRange(for: range)
        text.insert(contentsOf: marker, at: lineRange.lowerBound)
    }
}

private struct SelectionTrackingTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.string = text

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let parent: SelectionTrackingTextView
        init(_ parent: SelectionTrackingTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.selectedRange = textView.selectedRange()
        }
    }
}
