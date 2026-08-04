import Foundation
import Observation

@MainActor
@Observable
final class SpaceConfig {
    struct SpaceEntry: Codable, Identifiable, Equatable {
        let id: UInt64
        var name: String
        var notes: String

        init(id: UInt64, name: String = "", notes: String = "") {
            self.id = id
            self.name = name
            self.notes = notes
        }
    }

    private static let storageKey = "spaceEntries"

    private(set) var entries: [UInt64: SpaceEntry] = [:]

    init() {
        load()
    }

    func entry(for id: UInt64) -> SpaceEntry? {
        entries[id]
    }

    @discardableResult
    func ensureEntry(for id: UInt64) -> SpaceEntry {
        if let existing = entries[id] {
            return existing
        }
        let entry = SpaceEntry(id: id)
        entries[id] = entry
        save()
        return entry
    }

    func updateName(_ name: String, for id: UInt64) {
        guard var entry = entries[id] else { return }
        entry.name = name
        entries[id] = entry
        save()
    }

    func updateNotes(_ notes: String, for id: UInt64) {
        guard var entry = entries[id] else { return }
        entry.notes = notes
        entries[id] = entry
        save()
    }

    func delete(id: UInt64) {
        entries.removeValue(forKey: id)
        save()
    }

    var sortedEntries: [SpaceEntry] {
        entries.values.sorted { $0.id < $1.id }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(Array(entries.values))
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            NSLog("BalancedSpaces: failed to save space config: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return }
        do {
            let stored = try JSONDecoder().decode([SpaceEntry].self, from: data)
            entries = Dictionary(uniqueKeysWithValues: stored.map { ($0.id, $0) })
        } catch {
            NSLog("BalancedSpaces: failed to load space config: \(error)")
        }
    }
}
