import Foundation
import Observation

@MainActor
@Observable
final class SpaceConfig {
    struct SpaceEntry: Codable, Identifiable, Equatable {
        /// Stable identity, independent of any macOS Space.
        let id: UUID
        /// The macOS Space this entry is bound to, or nil when it lives in the
        /// library unassigned (what used to be a "profile").
        var assignedSpaceID: UInt64?
        var name: String
        var description: String
        var notes: String
        var symbolName: String?

        init(id: UUID = UUID(), assignedSpaceID: UInt64? = nil, name: String = "", description: String = "", notes: String = "", symbolName: String? = nil) {
            self.id = id
            self.assignedSpaceID = assignedSpaceID
            self.name = name
            self.description = description
            self.notes = notes
            self.symbolName = symbolName
        }

        private enum CodingKeys: String, CodingKey {
            case id, assignedSpaceID, name, notes, symbolName, description
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
            assignedSpaceID = try container.decodeIfPresent(UInt64.self, forKey: .assignedSpaceID)
            name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
            description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
            notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
            symbolName = try container.decodeIfPresent(String.self, forKey: .symbolName)
        }

        var isEmpty: Bool {
            name.isEmpty && description.isEmpty && notes.isEmpty && symbolName == nil
        }
    }

    static let presetIcons: [(title: String, symbol: String)] = [
        ("Work", "briefcase"),
        ("Life", "figure.walk"),
        ("Health", "heart"),
        ("Finances", "dollarsign.circle"),
    ]

    private static let storageKey = "spaceEntries"
    private static let legacyProfilesKey = "savedSpaceProfiles"
    private static let currentVersion = 2

    private struct StoredConfig: Codable {
        let formatVersion: Int
        let entries: [SpaceEntry]
    }

    /// Legacy v1 entry shape: `id` was the macOS Space id.
    private struct LegacyEntry: Codable {
        let id: UInt64
        var name: String = ""
        var description: String = ""
        var notes: String = ""
        var symbolName: String?
        private enum CodingKeys: String, CodingKey { case id, name, description, notes, symbolName }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(UInt64.self, forKey: .id)
            name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
            description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
            notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
            symbolName = try c.decodeIfPresent(String.self, forKey: .symbolName)
        }
    }
    private struct LegacyStored: Codable { let formatVersion: Int; let entries: [LegacyEntry] }
    private struct LegacyProfile: Codable { var name = ""; var description = ""; var notes = ""; var symbolName: String? }

    private(set) var entries: [UUID: SpaceEntry] = [:]

    init() {
        load()
    }

    // MARK: - Lookup

    func entry(id: UUID) -> SpaceEntry? { entries[id] }

    func entry(forSpaceID spaceID: UInt64) -> SpaceEntry? {
        entries.values.first { $0.assignedSpaceID == spaceID }
    }

    var sortedEntries: [SpaceEntry] {
        entries.values.sorted {
            switch ($0.assignedSpaceID, $1.assignedSpaceID) {
            case let (l?, r?): return l < r
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }

    /// Entries not bound to any macOS Space (the "library").
    var unassignedEntries: [SpaceEntry] {
        sortedEntries.filter { $0.assignedSpaceID == nil }
    }

    // MARK: - Mutation

    /// Creates a fresh entry, optionally bound to a macOS Space, and returns it.
    @discardableResult
    func createEntry(boundTo spaceID: UInt64? = nil) -> SpaceEntry {
        let entry = SpaceEntry(assignedSpaceID: spaceID)
        entries[entry.id] = entry
        save()
        return entry
    }

    /// Binds an entry to a macOS Space, first detaching any other entry that
    /// currently holds that Space so the mapping stays one-to-one.
    func assign(_ id: UUID, toSpaceID spaceID: UInt64) {
        guard entries[id] != nil else { return }
        for (key, value) in entries where value.assignedSpaceID == spaceID && key != id {
            entries[key]?.assignedSpaceID = nil
        }
        entries[id]?.assignedSpaceID = spaceID
        save()
    }

    /// Detaches an entry from its macOS Space, returning it to the library.
    func unassign(_ id: UUID) {
        guard entries[id] != nil else { return }
        entries[id]?.assignedSpaceID = nil
        save()
    }

    func updateName(_ name: String, for id: UUID) { mutate(id) { $0.name = name } }
    func updateNotes(_ notes: String, for id: UUID) { mutate(id) { $0.notes = notes } }
    func updateDescription(_ description: String, for id: UUID) { mutate(id) { $0.description = description } }
    func updateSymbol(_ symbolName: String?, for id: UUID) { mutate(id) { $0.symbolName = symbolName } }

    private func mutate(_ id: UUID, _ change: (inout SpaceEntry) -> Void) {
        guard var entry = entries[id] else { return }
        change(&entry)
        entries[id] = entry
        save()
    }

    /// Overwrites content fields for an existing entry, keeping id + assignment.
    func restore(_ snapshot: SpaceEntry) {
        guard var entry = entries[snapshot.id] else { entries[snapshot.id] = snapshot; save(); return }
        entry.name = snapshot.name
        entry.description = snapshot.description
        entry.notes = snapshot.notes
        entry.symbolName = snapshot.symbolName
        entries[snapshot.id] = entry
        save()
    }

    func delete(id: UUID) {
        entries.removeValue(forKey: id)
        save()
    }

    func replace(with imported: [SpaceEntry]) {
        entries = Dictionary(uniqueKeysWithValues: imported.map { ($0.id, $0) })
        save()
    }

    func allEntries() -> [SpaceEntry] { sortedEntries }

    // MARK: - Export / Import

    func exportData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(StoredConfig(formatVersion: Self.currentVersion, entries: sortedEntries))
    }

    /// Imports entries. When `replace` is false, incoming entries are added as
    /// unassigned library entries (their bindings are dropped to avoid clashing
    /// with this machine's Spaces); when true, they replace everything verbatim.
    func importData(_ data: Data, replace: Bool) throws {
        let decoder = JSONDecoder()
        guard let stored = try? decoder.decode(StoredConfig.self, from: data) else {
            throw SpaceConfigError.unreadable
        }
        if replace {
            entries = Dictionary(uniqueKeysWithValues: stored.entries.map { ($0.id, $0) })
        } else {
            for var incoming in stored.entries {
                incoming.assignedSpaceID = nil
                entries[incoming.id] = incoming
            }
        }
        save()
    }

    // MARK: - Persistence

    private func save() {
        do {
            let stored = StoredConfig(formatVersion: Self.currentVersion, entries: Array(entries.values))
            let data = try JSONEncoder().encode(stored)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            NSLog("BalancedSpaces: failed to save space config: \(error)")
        }
    }

    private func load() {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: Self.storageKey) else {
            migrateLegacyProfilesOnly()
            return
        }
        // Current (v2) format.
        if let stored = try? JSONDecoder().decode(StoredConfig.self, from: data), stored.formatVersion >= 2 {
            entries = Dictionary(uniqueKeysWithValues: stored.entries.map { ($0.id, $0) })
            return
        }
        // Migrate v1: entries keyed by macOS Space id, plus separate profiles list.
        var migrated: [SpaceEntry] = []
        if let legacy = try? JSONDecoder().decode(LegacyStored.self, from: data) {
            migrated = legacy.entries.map(Self.entry(fromLegacy:))
        } else if let legacyArray = try? JSONDecoder().decode([LegacyEntry].self, from: data) {
            migrated = legacyArray.map(Self.entry(fromLegacy:))
        }
        migrated.append(contentsOf: loadLegacyProfiles())
        entries = Dictionary(uniqueKeysWithValues: migrated.map { ($0.id, $0) })
        defaults.removeObject(forKey: Self.legacyProfilesKey)
        save()
    }

    /// No saved spaces yet, but a prior build may have stored profiles.
    private func migrateLegacyProfilesOnly() {
        let profiles = loadLegacyProfiles()
        guard !profiles.isEmpty else { return }
        entries = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        UserDefaults.standard.removeObject(forKey: Self.legacyProfilesKey)
        save()
    }

    private func loadLegacyProfiles() -> [SpaceEntry] {
        guard let data = UserDefaults.standard.data(forKey: Self.legacyProfilesKey),
              let profiles = try? JSONDecoder().decode([LegacyProfile].self, from: data) else { return [] }
        return profiles.map {
            SpaceEntry(assignedSpaceID: nil, name: $0.name, description: $0.description, notes: $0.notes, symbolName: $0.symbolName)
        }
    }

    private static func entry(fromLegacy legacy: LegacyEntry) -> SpaceEntry {
        SpaceEntry(assignedSpaceID: legacy.id, name: legacy.name, description: legacy.description, notes: legacy.notes, symbolName: legacy.symbolName)
    }
}

enum SpaceConfigError: LocalizedError {
    case unreadable
    var errorDescription: String? { "The file could not be read." }
}
