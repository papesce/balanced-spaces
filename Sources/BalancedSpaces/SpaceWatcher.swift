import AppKit
import Foundation

private let spaceDidChangeDistributedNotification = Notification.Name("com.apple.spaces.spaceDidChange")

@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> UInt32

@_silgen_name("CGSGetActiveSpace")
private func CGSGetActiveSpace(_ cid: UInt32) -> UInt64

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
}
