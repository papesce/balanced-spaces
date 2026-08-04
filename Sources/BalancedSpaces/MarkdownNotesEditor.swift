import SwiftUI
import AppKit

/// A TextEditor with a highlight toggle and a read-only rendered preview.
/// Notes are plain text with `==highlight==` spans and auto-linked URLs —
/// not Markdown. Selection-aware wrapping is done via an NSTextView bridge
/// since SwiftUI's TextEditor doesn't expose the current selection.
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
            Button { wrap(with: "==") } label: {
                Image(systemName: "highlighter")
            }
            .help("Highlight")
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
        renderNotes(text)
    }

    private func wrap(with marker: String) {
        guard let range = Range(selectedRange, in: text), !range.isEmpty else {
            text += marker + marker
            return
        }
        let selected = text[range]
        text.replaceSubrange(range, with: "\(marker)\(selected)\(marker)")
    }

}

private struct SelectionTrackingTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.isAutomaticLinkDetectionEnabled = true
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.string = text
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
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
