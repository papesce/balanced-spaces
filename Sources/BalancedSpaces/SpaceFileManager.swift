import AppKit
import Foundation
import UniformTypeIdentifiers

extension UTType {
    static var balancedSpace: UTType {
        UTType(filenameExtension: "balancedspace") ?? .json
    }
}

struct SpaceFile: Codable {
    static let currentVersion = 1

    let formatVersion: Int
    let savedAt: Date
    let name: String
    let description: String
    let notes: String
    let symbolName: String?

    private enum CodingKeys: String, CodingKey {
        case formatVersion, savedAt, name, description, notes, symbolName
    }

    init(formatVersion: Int, savedAt: Date, name: String, description: String, notes: String, symbolName: String?) {
        self.formatVersion = formatVersion
        self.savedAt = savedAt
        self.name = name
        self.description = description
        self.notes = notes
        self.symbolName = symbolName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try container.decode(Int.self, forKey: .formatVersion)
        savedAt = try container.decode(Date.self, forKey: .savedAt)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        symbolName = try container.decodeIfPresent(String.self, forKey: .symbolName)
    }
}

@MainActor
final class SpaceFileManager {
    private let fileManager = FileManager.default
    private var snapshotWorkItem: DispatchWorkItem?

    private func saveSnapshotEntry(_ entry: SpaceConfig.SpaceEntry, to url: URL) throws {
        let file = SpaceFile(
            formatVersion: SpaceFile.currentVersion,
            savedAt: Date(),
            name: entry.name,
            description: entry.description,
            notes: entry.notes,
            symbolName: entry.symbolName
        )
        let data = try JSONEncoder.pretty.encode(file)
        try data.write(to: url, options: .atomic)
    }

    private func saveSnapshot(entries: [SpaceConfig.SpaceEntry], to folder: URL) throws {
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        var usedNames: Set<String> = []
        for entry in entries {
            let base = entry.name.isEmpty ? "Space \(entry.id)" : entry.name
            let sanitized = sanitize(base)
            var candidate = sanitized
            var suffix = 2
            while usedNames.contains(candidate) {
                candidate = "\(sanitized) \(suffix)"
                suffix += 1
            }
            usedNames.insert(candidate)
            let url = folder.appendingPathComponent(candidate).appendingPathExtension("balancedspace")
            try saveSnapshotEntry(entry, to: url)
        }
    }

    func scheduleSnapshot(entries: [SpaceConfig.SpaceEntry]) {
        snapshotWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.createSnapshot(entries: entries)
            }
        }
        snapshotWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    func createSnapshot(entries: [SpaceConfig.SpaceEntry]) {
        do {
            let folder = try backupFolder()
            let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let snapshotFolder = folder.appendingPathComponent(stamp, isDirectory: true)
            try saveSnapshot(entries: entries, to: snapshotFolder)
            let snapshots = try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey])
                .filter { $0.hasDirectoryPath }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
            for old in snapshots.dropFirst(10) {
                try? fileManager.removeItem(at: old)
            }
        } catch {
            NSLog("BalancedSpaces: failed to create snapshot: \(error)")
        }
    }

    func backupsFolderURL() throws -> URL { try backupFolder() }

    private func backupFolder() throws -> URL {
        let base = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let folder = base.appendingPathComponent("Balanced Spaces/Backups", isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func sanitize(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\")
        let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Space" : cleaned
    }
}

enum SpaceFileError: LocalizedError {
    case unsupportedVersion(Int)
    var errorDescription: String? {
        if case let .unsupportedVersion(version) = self { return "This file uses unsupported format version \(version)." }
        return "The file could not be read."
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
