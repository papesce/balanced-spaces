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
/// content's actual ideal height whenever that height changes. Needed
/// because `MenuBarExtra(.window)` grows its window to fit taller content
/// but does not shrink it back down once the content gets shorter again
/// while the window stays open (e.g. leaving edit mode) — a known
/// SwiftUI/AppKit limitation with NSHostingView-backed windows.
///
/// Anchors the top edge (the menu bar side) and grows/shrinks the bottom
/// edge, since this is a top-anchored dropdown.
private struct AutosizeMenuBarWindowModifier: ViewModifier {
    @State private var window: NSWindow?
    @State private var measuredHeight: CGFloat = 0
    @State private var appliedHeight: CGFloat?

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            measuredHeight = proxy.size.height
                            resizeIfNeeded()
                        }
                        .onChange(of: proxy.size.height) { _, newHeight in
                            measuredHeight = newHeight
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
        guard let window, measuredHeight > 0 else { return }
        if let appliedHeight, abs(appliedHeight - measuredHeight) < 0.5 { return }

        let currentFrame = window.frame
        let isInitialFit = appliedHeight == nil
        appliedHeight = measuredHeight

        guard abs(currentFrame.height - measuredHeight) > 0.5 else { return }

        // Keep the top edge fixed; grow/shrink from the bottom.
        // `setContentSize` preserves the window's origin (bottom-left
        // corner) instead, which would move the wrong edge here.
        let newFrame = NSRect(
            x: currentFrame.origin.x,
            y: currentFrame.maxY - measuredHeight,
            width: currentFrame.width,
            height: measuredHeight
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
