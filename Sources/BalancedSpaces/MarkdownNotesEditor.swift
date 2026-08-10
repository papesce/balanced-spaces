import SwiftUI
import AppKit

struct MarkdownNotesEditor: View {
    @Binding var text: String
    var placeholder: String = "Notes…"
    var minHeight: CGFloat = 56
    var maxHeight: CGFloat = 96

    var body: some View {
        HighlightingTextView(text: $text)
            .frame(minHeight: minHeight, maxHeight: maxHeight)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.1)))
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 6)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
            }
    }
}

private struct HighlightingTextView: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.isAutomaticLinkDetectionEnabled = false
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
        applyHighlighting(to: textView)

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        // Skip while the user is typing — setting .string clears NSTextView's undo stack
        guard !context.coordinator.isEditing else { return }
        if textView.string != text {
            textView.string = text
            applyHighlighting(to: textView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func applyHighlighting(to textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        let selectedRanges = textView.selectedRanges
        applyNotesHighlighting(to: storage)
        textView.selectedRanges = selectedRanges
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let parent: HighlightingTextView
        var isEditing = false
        init(_ parent: HighlightingTextView) { self.parent = parent }

        func textDidBeginEditing(_ notification: Notification) {
            isEditing = true
        }

        func textDidEndEditing(_ notification: Notification) {
            isEditing = false
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.applyHighlighting(to: textView)
        }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            guard let url = link as? URL, let path = TerminalLink.path(from: url) else { return false }
            TerminalLink.open(at: path)
            return true
        }
    }
}
