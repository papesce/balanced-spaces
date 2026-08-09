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
        guard let id = currentSpaceID, id != 0 else { return "?" }
        guard let entry = config.entry(for: id) else { return "?" }
        return entry.name.isEmpty ? "?" : entry.name
    }

    var currentEntry: SpaceConfig.SpaceEntry? {
        guard let id = currentSpaceID, id != 0 else { return nil }
        return config.entry(for: id)
    }

    func spaceDidChange() {
        let id = SpaceWatcher.currentSpaceID()
        currentSpaceID = id
        refreshSpaceStatus()
        guard id != 0 else { return }
        config.ensureEntry(for: id)
    }

    func refreshSpaceStatus() {
        liveSpaceIDs = SpaceWatcher.currentSpaceIDs()
    }

    func isStale(_ entry: SpaceConfig.SpaceEntry) -> Bool {
        guard let liveSpaceIDs else { return false }
        return !liveSpaceIDs.contains(entry.id)
    }
}
