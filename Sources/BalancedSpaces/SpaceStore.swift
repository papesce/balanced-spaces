import Foundation
import Observation

@MainActor
@Observable
final class SpaceStore {
    let config: SpaceConfig
    private let watcher: SpaceWatcher
    private(set) var currentSpaceID: UInt64?
    private(set) var liveSpaceIDs: Set<UInt64>?

    init(config: SpaceConfig = SpaceConfig()) {
        self.config = config
        self.watcher = SpaceWatcher()
        watcher.start { [weak self] in
            self?.spaceDidChange()
        }
        spaceDidChange()
        refreshSpaceStatus()
    }

    var currentSpaceName: String {
        guard let entry = currentEntry else { return "?" }
        return entry.name.isEmpty ? "?" : entry.name
    }

    /// The entry bound to the current macOS Space, if any. nil means the Space
    /// has no entry assigned yet.
    var currentEntry: SpaceConfig.SpaceEntry? {
        guard let id = currentSpaceID, id != 0 else { return nil }
        return config.entry(forSpaceID: id)
    }

    func spaceDidChange() {
        currentSpaceID = SpaceWatcher.currentSpaceID()
        refreshSpaceStatus()
    }

    func refreshSpaceStatus() {
        liveSpaceIDs = SpaceWatcher.currentSpaceIDs()
    }

    /// True when the entry is bound to a Space that isn't currently live.
    func isStale(_ entry: SpaceConfig.SpaceEntry) -> Bool {
        guard let assigned = entry.assignedSpaceID, let liveSpaceIDs else { return false }
        return !liveSpaceIDs.contains(assigned)
    }
}
