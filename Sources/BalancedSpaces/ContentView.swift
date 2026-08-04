import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var store: SpaceStore
    private let backupManager = BackupManager()
    @State private var backupError: String?
    @State private var savedToast = false
    @State private var pendingImport: BackupImport?
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "didShowOnboarding")
    @State private var editingEntryID: UInt64?
    @State private var hoveredEntryID: UInt64?
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            spacesSection
            Divider()
            footer
        }
        .frame(width: 340, height: 480)
        .background {
            Button("") { toggleEditing(for: store.currentSpaceID) }
                .keyboardShortcut("e", modifiers: .command)
                .hidden()
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView {
                UserDefaults.standard.set(true, forKey: "didShowOnboarding")
                showOnboarding = false
            }
        }
        .sheet(item: $pendingImport) { backup in
            ImportReviewView(
                backup: backup,
                existingEntries: store.config.allEntries(),
                onCancel: { pendingImport = nil },
                onConfirm: { backup, mode in
                    backupManager.apply(backup, to: store.config, mode: mode)
                    pendingImport = nil
                    backupError = nil
                }
            )
        }
    }

    private func toggleEditing(for id: UInt64?) {
        guard let id, id != 0 else { return }
        editingEntryID = editingEntryID == id ? nil : id
    }

    private func showSavedToast() {
        withAnimation { savedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation { savedToast = false }
        }
    }

    private var spacesSection: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(store.config.sortedEntries) { entry in
                    spaceRow(entry)
                }
            }
            .padding(12)
        }
    }

    private func spaceRow(_ entry: SpaceConfig.SpaceEntry) -> some View {
        let isCurrent = entry.id == store.currentSpaceID
        let isHovered = hoveredEntryID == entry.id
        let isEditing = editingEntryID == entry.id
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                if isEditing {
                    IconPickerView(symbolName: symbolBinding(for: entry))
                    TextField("Name", text: nameBinding(for: entry))
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                } else {
                    if let symbolName = entry.symbolName {
                        Image(systemName: symbolName)
                            .foregroundStyle(.secondary)
                    }
                    Text(entry.name.isEmpty ? "Untitled Space" : entry.name)
                        .font(isCurrent ? .headline : .body)
                        .foregroundStyle(entry.name.isEmpty ? .secondary : .primary)
                }
                Spacer()
                if isCurrent && savedToast {
                    Text("Saved")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
                if isEditing {
                    Button {
                        store.config.delete(id: entry.id)
                        editingEntryID = nil
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Delete this space")
                }
                Button {
                    toggleEditing(for: entry.id)
                } label: {
                    Image(systemName: isEditing ? "checkmark.circle" : "pencil")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .opacity(isHovered || isEditing ? 1 : 0)
                .help(isEditing ? "Done editing" : "Edit this space")
            }
            if isEditing {
                MarkdownNotesEditor(text: notesBinding(for: entry), placeholder: "Notes…", minHeight: 40, maxHeight: 80)
            } else if !entry.notes.isEmpty {
                Text(renderedPreview(entry.notes))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(3)
            }
        }
        .padding(8)
        .background(
            isCurrent ? Color.accentColor.opacity(0.08) : (isHovered ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03)),
            in: RoundedRectangle(cornerRadius: 6)
        )
        .animation(.easeInOut(duration: 0.1), value: isHovered)
        .onHover { hovering in
            hoveredEntryID = hovering ? entry.id : (hoveredEntryID == entry.id ? nil : hoveredEntryID)
        }
    }

    private func renderedPreview(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let backupError {
                Text(backupError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Menu {
                    Button("Edit Current Space") { toggleEditing(for: store.currentSpaceID) }
                    Divider()
                    Button("Import…", action: importBackup)
                    Button("Export…", action: exportBackup)
                    Button("Settings…") { openSettings() }
                    Divider()
                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                    .keyboardShortcut("q", modifiers: .command)
                } label: {
                    Image(systemName: "gearshape")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .padding(10)
    }

    private func exportBackup() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.balancedSpacesBackup]
        panel.nameFieldStringValue = "Spaces Backup.balancedspaces"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try backupManager.export(entries: store.config.allEntries(), to: url)
            backupError = nil
        } catch {
            backupError = "Export failed: \(error.localizedDescription)"
        }
    }

    private func importBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.balancedSpacesBackup]
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            pendingImport = try backupManager.readImport(from: url)
            backupError = nil
        } catch {
            backupError = "Import failed: \(error.localizedDescription)"
        }
    }

    private func nameBinding(for entry: SpaceConfig.SpaceEntry) -> Binding<String> {
        Binding(
            get: { store.config.entry(for: entry.id)?.name ?? entry.name },
            set: { newValue in
                store.config.updateName(newValue, for: entry.id)
                showSavedToast()
            }
        )
    }

    private func notesBinding(for entry: SpaceConfig.SpaceEntry) -> Binding<String> {
        Binding(
            get: { store.config.entry(for: entry.id)?.notes ?? entry.notes },
            set: { newValue in
                store.config.updateNotes(newValue, for: entry.id)
                showSavedToast()
            }
        )
    }

    private func symbolBinding(for entry: SpaceConfig.SpaceEntry) -> Binding<String?> {
        Binding(
            get: { store.config.entry(for: entry.id)?.symbolName ?? entry.symbolName },
            set: { newValue in
                store.config.updateSymbol(newValue, for: entry.id)
                showSavedToast()
            }
        )
    }
}
