import Foundation
import Observation

@MainActor
@Observable
final class SpaceConfig {
    struct SpaceEntry: Codable, Identifiable, Equatable {
        let id: UInt64
        var name: String
        var notes: String
        var symbolName: String?

        init(id: UInt64, name: String = "", notes: String = "", symbolName: String? = nil) {
            self.id = id
            self.name = name
            self.notes = notes
            self.symbolName = symbolName
        }
    }

    static let presetIcons: [(title: String, symbol: String)] = [
        ("Work", "briefcase"),
        ("Life", "figure.walk"),
        ("Health", "heart"),
        ("Finances", "dollarsign.circle"),
    ]

    private static let storageKey = "spaceEntries"

    private struct StoredConfig: Codable {
        let formatVersion: Int
        let entries: [SpaceEntry]
    }

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

    func updateSymbol(_ symbolName: String?, for id: UInt64) {
        guard var entry = entries[id] else { return }
        entry.symbolName = symbolName
        entries[id] = entry
        save()
    }

    /// Writes name+notes+symbolName from a snapshot in one save, e.g. to revert an in-progress edit.
    func restore(_ snapshot: SpaceEntry) {
        entries[snapshot.id] = snapshot
        save()
    }

    func delete(id: UInt64) {
        entries.removeValue(forKey: id)
        save()
    }

    func replace(with imported: [SpaceEntry]) {
        entries = Dictionary(uniqueKeysWithValues: imported.map { ($0.id, $0) })
        save()
    }

    var sortedEntries: [SpaceEntry] {
        entries.values.sorted { $0.id < $1.id }
    }

    func allEntries() -> [SpaceEntry] {
        sortedEntries
    }

    private func save() {
        do {
            let stored = StoredConfig(formatVersion: 1, entries: Array(entries.values))
            let data = try JSONEncoder().encode(stored)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            NSLog("BalancedSpaces: failed to save space config: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return }
        do {
            if let stored = try? JSONDecoder().decode(StoredConfig.self, from: data) {
                entries = Dictionary(uniqueKeysWithValues: stored.entries.map { ($0.id, $0) })
            } else {
                // Migrate the original unversioned array format.
                let legacy = try JSONDecoder().decode([SpaceEntry].self, from: data)
                entries = Dictionary(uniqueKeysWithValues: legacy.map { ($0.id, $0) })
                save()
            }
        } catch {
            NSLog("BalancedSpaces: failed to load space config: \(error)")
        }
    }
}
