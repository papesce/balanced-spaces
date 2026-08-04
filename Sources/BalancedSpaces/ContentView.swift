import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var store: SpaceStore
    private let backupManager = BackupManager()
    @State private var backupError: String?
    @State private var savedToast = false
    @State private var pendingImport: BackupImport?
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "didShowOnboarding")
    @FocusState private var currentNameFocused: Bool
    @FocusState private var currentNotesFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            currentSpaceSection
            Divider()
            spacesSection
            Divider()
            footer
        }
        .frame(width: 340, height: 480)
        .background {
            Button("") { currentNameFocused = true }
                .keyboardShortcut("e", modifiers: .command)
                .hidden()
            Button("") { currentNotesFocused = true }
                .keyboardShortcut("n", modifiers: .command)
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

    private var currentSpaceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                IconPickerView(symbolName: currentSymbolBinding)
                if let id = store.currentSpaceID, id != 0, (store.currentEntry?.name ?? "").isEmpty {
                    TextField("Click to name this Space", text: currentNameBinding)
                        .textFieldStyle(.roundedBorder)
                        .font(.headline)
                        .focused($currentNameFocused)
                } else {
                    Text(store.currentSpaceName)
                        .font(.headline)
                }
                Spacer()
                if savedToast {
                    Text("Saved")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
                Text("Current Space")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            TextEditor(text: currentNotesBinding)
                .font(.callout)
                .frame(minHeight: 56, maxHeight: 96)
                .focused($currentNotesFocused)
                .overlay(alignment: .topLeading) {
                    if currentNotesBinding.wrappedValue.isEmpty {
                        Text("Notes for this space…")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding(12)
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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                IconPickerView(symbolName: symbolBinding(for: entry))
                TextField("Name", text: nameBinding(for: entry))
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                Button {
                    store.config.delete(id: entry.id)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Delete this space")
            }
            TextEditor(text: notesBinding(for: entry))
                .font(.callout)
                .frame(minHeight: 40, maxHeight: 80)
        }
        .padding(8)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let backupError {
                Text(backupError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack {
                Button("Export…", action: exportBackup)
                Button("Import…", action: importBackup)
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
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

    private var currentNotesBinding: Binding<String> {
        Binding(
            get: { store.currentEntry?.notes ?? "" },
            set: { newValue in
                guard let id = store.currentSpaceID, id != 0 else { return }
                store.config.updateNotes(newValue, for: id)
                showSavedToast()
            }
        )
    }

    private var currentNameBinding: Binding<String> {
        Binding(
            get: { store.currentEntry?.name ?? "" },
            set: { newValue in
                guard let id = store.currentSpaceID, id != 0 else { return }
                store.config.updateName(newValue, for: id)
                showSavedToast()
            }
        )
    }

    private var currentSymbolBinding: Binding<String?> {
        Binding(
            get: { store.currentEntry?.symbolName },
            set: { newValue in
                guard let id = store.currentSpaceID, id != 0 else { return }
                store.config.updateSymbol(newValue, for: id)
                showSavedToast()
            }
        )
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
