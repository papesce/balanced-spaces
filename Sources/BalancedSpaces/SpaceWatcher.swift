import AppKit
import Foundation

private let spaceDidChangeDistributedNotification = Notification.Name("com.apple.spaces.spaceDidChange")

@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> UInt32

@_silgen_name("CGSGetActiveSpace")
private func CGSGetActiveSpace(_ cid: UInt32) -> UInt64

@_silgen_name("CGSCopySpaces")
private func CGSCopySpaces(_ cid: UInt32, _ mask: Int32) -> Unmanaged<CFArray>?

@MainActor
final class SpaceWatcher {
    private var observers: [NSObjectProtocol] = []

    func start(onChange: @escaping @MainActor () -> Void) {
        let workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                onChange()
            }
        }

        let distributedObserver = DistributedNotificationCenter.default().addObserver(
            forName: spaceDidChangeDistributedNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                onChange()
            }
        }

        observers = [workspaceObserver, distributedObserver]
    }

    func stop() {
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        observers = []
    }

    static func currentSpaceID() -> UInt64 {
        let cid = CGSMainConnectionID()
        guard cid != 0 else { return 0 }
        let spaceID = CGSGetActiveSpace(cid)
        return spaceID == 0 ? 0 : spaceID
    }

    /// Returns all Spaces known to the current macOS session. This uses the
    /// same private CoreGraphics Spaces API family as currentSpaceID().
    /// A nil result means enumeration is unavailable on this OS build.
    static func currentSpaceIDs() -> Set<UInt64>? {
        let cid = CGSMainConnectionID()
        guard cid != 0, let unmanagedSpaces = CGSCopySpaces(cid, 7) else { return nil }
        let spaces = unmanagedSpaces.takeRetainedValue() as NSArray
        let ids = spaces.compactMap { ($0 as? NSNumber)?.uint64Value }
        guard !ids.isEmpty else { return nil }
        return Set(ids)
    }
}
