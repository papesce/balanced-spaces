import AppKit
import SwiftUI

/// Captures the `NSWindow` hosting this SwiftUI content, as soon as the
/// underlying view is inserted into a window. `MenuBarExtra(.window)` owns
/// this window; this only observes it, never creates or retains it beyond
/// the callback.
private struct MenuBarWindowAccessor: NSViewRepresentable {
    let onWindowChange: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = TrackingView()
        view.onWindowChange = onWindowChange
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    final class TrackingView: NSView {
        var onWindowChange: ((NSWindow?) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindowChange?(window)
        }
    }
}

/// Forces the menu bar extra's hosting window to re-fit to the SwiftUI
/// content's actual ideal size whenever that size changes. Needed because
/// `MenuBarExtra(.window)` grows its window to fit larger content but does
/// not shrink it back down once the content gets smaller again while the
/// window stays open (e.g. leaving edit mode, or a user-driven width
/// change) — a known SwiftUI/AppKit limitation with NSHostingView-backed
/// windows.
///
/// Anchors the top-left corner (the menu bar side) and grows/shrinks the
/// bottom-right, since this is a top-left-anchored dropdown.
private struct AutosizeMenuBarWindowModifier: ViewModifier {
    @State private var window: NSWindow?
    @State private var measuredSize: CGSize = .zero
    @State private var appliedSize: CGSize?

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            measuredSize = proxy.size
                            resizeIfNeeded()
                        }
                        .onChange(of: proxy.size) { _, newSize in
                            measuredSize = newSize
                            resizeIfNeeded()
                        }
                }
            )
            .background(MenuBarWindowAccessor { newWindow in
                window = newWindow
                resizeIfNeeded()
            })
    }

    private func resizeIfNeeded() {
        guard let window, measuredSize.height > 0, measuredSize.width > 0 else { return }
        if let appliedSize,
           abs(appliedSize.width - measuredSize.width) < 0.5,
           abs(appliedSize.height - measuredSize.height) < 0.5 { return }

        let currentFrame = window.frame
        let isInitialFit = appliedSize == nil
        appliedSize = measuredSize

        guard abs(currentFrame.width - measuredSize.width) > 0.5
            || abs(currentFrame.height - measuredSize.height) > 0.5 else { return }

        // Keep the top-left corner fixed; grow/shrink from the bottom-right.
        // `setContentSize` preserves the window's origin (bottom-left
        // corner) instead, which would move the wrong edge here.
        let newFrame = NSRect(
            x: currentFrame.origin.x,
            y: currentFrame.maxY - measuredSize.height,
            width: measuredSize.width,
            height: measuredSize.height
        )
        window.setFrame(newFrame, display: true, animate: !isInitialFit)
    }
}

extension View {
    /// Keeps this menu bar extra's hosting window sized to this view's true
    /// ideal height, including shrinking back down when content gets
    /// shorter — which `MenuBarExtra(.window)` does not do on its own for a
    /// window that's already open.
    func autosizeMenuBarWindow() -> some View {
        modifier(AutosizeMenuBarWindowModifier())
    }
}
