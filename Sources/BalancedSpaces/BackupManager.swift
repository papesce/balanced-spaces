import AppKit
import Foundation
import UniformTypeIdentifiers

extension UTType {
    static var balancedSpacesBackup: UTType {
        UTType(filenameExtension: "balancedspaces") ?? .folder
    }
}

struct BackupManifest: Codable {
    static let currentVersion = 1

    struct Entry: Codable, Identifiable {
        let id: UInt64
        var name: String
        var notes: String
        var symbolName: String?
    }

    let formatVersion: Int
    let exportedAt: Date
    let appVersion: String
    let entries: [Entry]
}

enum ImportMode {
    case merge
    case replace
}

struct BackupImport: Identifiable {
    let id = UUID()
    let manifest: BackupManifest
    let sourceURL: URL
    var assignments: [UInt64: UInt64] = [:] // backup ID -> current Space ID

    var unmatched: [BackupManifest.Entry] {
        manifest.entries.filter { assignments[$0.id] == nil }
    }
}

@MainActor
final class BackupManager {
    private let fileManager = FileManager.default
    private var snapshotWorkItem: DispatchWorkItem?

    func export(entries: [SpaceConfig.SpaceEntry], to url: URL) throws {
        let manifest = BackupManifest(
            formatVersion: BackupManifest.currentVersion,
            exportedAt: Date(),
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0",
            entries: entries.map { .init(id: $0.id, name: $0.name, notes: $0.notes, symbolName: $0.symbolName) }
        )
        let json = try JSONEncoder.pretty.encode(manifest)
        let markdown = markdownExport(entries: entries)

        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        try json.write(to: url.appendingPathComponent("manifest.json"), options: .atomic)
        try markdown.data(using: .utf8)!.write(to: url.appendingPathComponent("spaces.md"), options: .atomic)
    }

    func readImport(from url: URL) throws -> BackupImport {
        let manifestURL = url.hasDirectoryPath ? url.appendingPathComponent("manifest.json") : url
        let data = try Data(contentsOf: manifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(BackupManifest.self, from: data)
        guard manifest.formatVersion == BackupManifest.currentVersion else {
            throw BackupError.unsupportedVersion(manifest.formatVersion)
        }
        return BackupImport(manifest: manifest, sourceURL: url)
    }

    func apply(_ backup: BackupImport, to config: SpaceConfig, mode: ImportMode) {
        var imported: [UInt64: SpaceConfig.SpaceEntry] = [:]
        for entry in backup.manifest.entries {
            let targetID = backup.assignments[entry.id] ?? entry.id
            imported[targetID] = .init(id: targetID, name: entry.name, notes: entry.notes, symbolName: entry.symbolName)
        }
        switch mode {
        case .replace:
            config.replace(with: Array(imported.values))
        case .merge:
            var merged = Dictionary(uniqueKeysWithValues: config.allEntries().map { ($0.id, $0) })
            for (id, entry) in imported { merged[id] = entry }
            config.replace(with: Array(merged.values))
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
            let url = folder.appendingPathComponent("snapshot-\(stamp).balancedspaces", isDirectory: true)
            try export(entries: entries, to: url)
            let snapshots = try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey])
                .filter { $0.pathExtension == "balancedspaces" }
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

    private func markdownExport(entries: [SpaceConfig.SpaceEntry]) -> String {
        entries.map {
            let title = $0.name.isEmpty ? "Untitled Space" : $0.name
            let icon = $0.symbolName.map { "\n\nIcon: `\($0)`" } ?? ""
            return "# \(title)\n\nSpace ID: `\($0.id)`\(icon)\n\n\($0.notes)"
        }.joined(separator: "\n\n---\n\n") + "\n"
    }
}

enum BackupError: LocalizedError {
    case unsupportedVersion(Int)
    var errorDescription: String? {
        if case let .unsupportedVersion(version) = self { return "This backup uses unsupported format version \(version)." }
        return "The backup could not be read."
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
