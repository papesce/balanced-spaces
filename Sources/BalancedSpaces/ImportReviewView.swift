import SwiftUI

struct ImportReviewView: View {
    @State var backup: BackupImport
    let existingEntries: [SpaceConfig.SpaceEntry]
    let onCancel: () -> Void
    let onConfirm: (BackupImport, ImportMode) -> Void

    @State private var mode: ImportMode = .merge

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Review Import")
                .font(.headline)
            Text("\(backup.manifest.entries.count) space(s) in this backup, exported \(backup.manifest.exportedAt.formatted(date: .abbreviated, time: .shortened)).")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Mode", selection: $mode) {
                Text("Merge with current spaces").tag(ImportMode.merge)
                Text("Replace all current spaces").tag(ImportMode.replace)
            }
            .pickerStyle(.radioGroup)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(backup.manifest.entries) { entry in
                        row(for: entry)
                    }
                }
            }
            .frame(maxHeight: 220)

            Divider()

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Import") { onConfirm(backup, mode) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .frame(width: 340)
    }

    private func row(for entry: BackupManifest.Entry) -> some View {
        HStack {
            if let symbol = entry.symbolName, !symbol.isEmpty {
                Image(systemName: symbol)
                    .frame(width: 18)
            }
            VStack(alignment: .leading) {
                Text(entry.name.isEmpty ? "Untitled Space" : entry.name)
                    .font(.body)
                Text("Backup ID \(entry.id)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("", selection: assignmentBinding(for: entry)) {
                Text("Keep ID \(entry.id)").tag(entry.id as UInt64)
                ForEach(existingEntries) { existing in
                    Text(existing.name.isEmpty ? "Space \(existing.id)" : existing.name).tag(existing.id)
                }
            }
            .labelsHidden()
            .frame(width: 130)
        }
    }

    private func assignmentBinding(for entry: BackupManifest.Entry) -> Binding<UInt64> {
        Binding(
            get: { backup.assignments[entry.id] ?? entry.id },
            set: { newValue in
                if newValue == entry.id {
                    backup.assignments.removeValue(forKey: entry.id)
                } else {
                    backup.assignments[entry.id] = newValue
                }
            }
        )
    }
}
