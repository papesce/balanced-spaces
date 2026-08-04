import AppKit
import ScreenCaptureKit
import SwiftUI

/// Best-effort small preview of what's currently on screen. Only ever
/// reflects the active Space (there's no public API to capture a
/// background Space's windows), so it's cached per-space-id and only
/// refreshed while that space is frontmost. Requires Screen Recording
/// permission; silently produces no thumbnail if denied.
@MainActor
final class SpaceThumbnailCache {
    static let shared = SpaceThumbnailCache()
    private var images: [UInt64: NSImage] = [:]
    private var didRequestAccess = false

    func image(for id: UInt64) -> NSImage? {
        images[id]
    }

    /// Screen Recording (not Accessibility) permission gates this. Only ask
    /// once per launch — re-requesting on every Space switch is what causes
    /// the prompt to reappear repeatedly even after it's been granted.
    func captureCurrentSpace(id: UInt64) {
        guard id != 0 else { return }
        guard CGPreflightScreenCaptureAccess() else {
            if !didRequestAccess {
                didRequestAccess = true
                CGRequestScreenCaptureAccess()
            }
            return
        }
        Task {
            guard let image = try? await Self.captureMainDisplay() else { return }
            images[id] = image
        }
    }

    private static func captureMainDisplay() async throws -> NSImage {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else {
            throw CocoaError(.featureUnsupported)
        }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = display.width / 4
        configuration.height = display.height / 4
        let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}

struct SpaceThumbnailView: View {
    let id: UInt64

    var body: some View {
        Group {
            if let image = SpaceThumbnailCache.shared.image(for: id) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.primary.opacity(0.06)
            }
        }
        .frame(width: 44, height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.primary.opacity(0.1)))
    }
}
