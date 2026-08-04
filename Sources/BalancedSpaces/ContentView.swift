import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var store: SpaceStore
    private let fileManager = SpaceFileManager()
    @State private var saveLoadError: String?
    @State private var showSavedIndicator = false
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "didShowOnboarding")
    @State private var showIconPicker = false
    @State private var saveIndicatorTask: Task<Void, Never>?
    @State private var isEditingRow = false
    @State private var editSnapshot: SpaceConfig.SpaceEntry?
    @State private var isRowHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            spacesSection
            Divider()
            footer
        }
        .frame(width: 340)
        .overlay {
            if showIconPicker, let entry = store.currentEntry {
                IconPickerDismissScrim(isExpanded: $showIconPicker)
                IconPickerPanel(symbolName: symbolBinding(for: entry), isExpanded: $showIconPicker)
                    .offset(x: 20, y: 46)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView {
                UserDefaults.standard.set(true, forKey: "didShowOnboarding")
                showOnboarding = false
            }
        }
    }

    private func confirmClearCurrentSpace() {
        guard store.currentEntry != nil else { return }
        let alert = NSAlert()
        alert.messageText = "Clear this Space?"
        alert.informativeText = "This removes the name, notes, and icon for the current Space. This can't be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            clearCurrentSpace()
        }
    }

    private func clearCurrentSpace() {
        guard let id = store.currentSpaceID else { return }
        store.config.updateName("", for: id)
        store.config.updateNotes("", for: id)
        store.config.updateSymbol(nil, for: id)
        scheduleSavedIndicator()
    }

    /// Debounced: waits for edits to settle before showing "Saved", since the
    /// underlying store already persists on every keystroke.
    private func scheduleSavedIndicator() {
        saveIndicatorTask?.cancel()
        saveIndicatorTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            withAnimation { showSavedIndicator = true }
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            withAnimation { showSavedIndicator = false }
        }
    }

    private var spacesSection: some View {
        Group {
            if let entry = store.currentEntry {
                spaceRow(entry)
                    .padding(12)
            } else {
                Text("No Space detected")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(12)
            }
        }
    }

    private func spaceRow(_ entry: SpaceConfig.SpaceEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if isEditingRow {
                    IconPickerView(symbolName: symbolBinding(for: entry), isExpanded: $showIconPicker)
                    TextField("Untitled Space", text: nameBinding(for: entry))
                        .textFieldStyle(.plain)
                        .font(.headline)
                } else {
                    if let symbolName = entry.symbolName {
                        Image(systemName: symbolName)
                            .font(.system(size: 15))
                            .frame(width: 28, height: 28)
                    }
                    Text(entry.name.isEmpty ? "Untitled Space" : entry.name)
                        .font(.headline)
                        .foregroundStyle(entry.name.isEmpty ? .tertiary : .primary)
                }
                Spacer()
                if showSavedIndicator {
                    Text("Saved")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
                if isEditingRow {
                    if editSnapshot != nil, editSnapshot != store.config.entry(for: entry.id) {
                        Button("Revert", action: revertEdit)
                            .font(.caption)
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                    }
                    Button("Done", action: endEditing)
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                } else if isRowHovered {
                    Button(action: beginEditing) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Edit this Space")
                    .accessibilityLabel("Edit this Space")
                }
            }
            if isEditingRow {
                MarkdownNotesEditor(text: notesBinding(for: entry), placeholder: "Notes…", minHeight: 100, maxHeight: 220)
            } else {
                NotesPlainTextView(text: entry.notes)
                    .padding(.leading, entry.symbolName == nil ? 0 : 36)
            }
        }
        .padding(8)
        .onHover { isRowHovered = $0 }
    }

    private func beginEditing() {
        editSnapshot = store.currentEntry
        isEditingRow = true
    }

    private func endEditing() {
        isEditingRow = false
        editSnapshot = nil
    }

    private func revertEdit() {
        guard let snapshot = editSnapshot else { return }
        store.config.restore(snapshot)
        scheduleSavedIndicator()
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let saveLoadError {
                Text(saveLoadError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Menu {
                    Button("Save Current Space…", action: saveCurrentSpace)
                        .disabled(store.currentEntry == nil)
                    Button("Save All Spaces…", action: saveAllSpaces)
                    Divider()
                    Button("Load Space…", action: loadSpace)
                        .disabled(store.currentEntry == nil)
                    Divider()
                    Menu("Danger Zone") {
                        Button("Clear Current Space…", action: confirmClearCurrentSpace)
                            .disabled(store.currentEntry == nil)
                    }
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

    private func saveCurrentSpace() {
        guard let entry = store.currentEntry else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.balancedSpace]
        let baseName = entry.name.isEmpty ? "Untitled Space" : entry.name
        panel.nameFieldStringValue = "\(baseName).balancedspace"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try fileManager.save(entry: entry, to: url)
            saveLoadError = nil
        } catch {
            saveLoadError = "Save failed: \(error.localizedDescription)"
        }
    }

    private func saveAllSpaces() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try fileManager.saveAll(entries: store.config.allEntries(), to: url)
            saveLoadError = nil
        } catch {
            saveLoadError = "Save failed: \(error.localizedDescription)"
        }
    }

    private func loadSpace() {
        guard let spaceID = store.currentSpaceID, store.currentEntry != nil else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.balancedSpace]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let file = try fileManager.load(from: url)
            fileManager.apply(file, toSpaceID: spaceID, config: store.config)
            saveLoadError = nil
        } catch {
            saveLoadError = "Load failed: \(error.localizedDescription)"
        }
    }

    private func nameBinding(for entry: SpaceConfig.SpaceEntry) -> Binding<String> {
        Binding(
            get: { store.config.entry(for: entry.id)?.name ?? entry.name },
            set: { newValue in
                store.config.updateName(newValue, for: entry.id)
                scheduleSavedIndicator()
            }
        )
    }

    private func notesBinding(for entry: SpaceConfig.SpaceEntry) -> Binding<String> {
        Binding(
            get: { store.config.entry(for: entry.id)?.notes ?? entry.notes },
            set: { newValue in
                store.config.updateNotes(newValue, for: entry.id)
                scheduleSavedIndicator()
            }
        )
    }

    private func symbolBinding(for entry: SpaceConfig.SpaceEntry) -> Binding<String?> {
        Binding(
            get: { store.config.entry(for: entry.id)?.symbolName ?? entry.symbolName },
            set: { newValue in
                store.config.updateSymbol(newValue, for: entry.id)
                scheduleSavedIndicator()
            }
        )
    }
}
