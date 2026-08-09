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
    @State private var draftName = ""
    @State private var draftNotes = ""
    @State private var draftSymbolName: String?
    @State private var isRowHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            spacesSection
            allSpacesSection
            Divider()
            footer
        }
        .frame(width: 340)
        .overlay {
            if showIconPicker {
                IconPickerDismissScrim(isExpanded: $showIconPicker)
                IconPickerPanel(symbolName: $draftSymbolName, isExpanded: $showIconPicker)
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

    private var liveSpaceEntries: [SpaceConfig.SpaceEntry] {
        if let liveSpaceIDs = store.liveSpaceIDs {
            return store.config.sortedEntries.filter { liveSpaceIDs.contains($0.id) }
        }
        guard let currentSpaceID = store.currentSpaceID else { return [] }
        return store.config.sortedEntries.filter { $0.id == currentSpaceID }
    }

    private var unavailableSpaceEntries: [SpaceConfig.SpaceEntry] {
        guard store.liveSpaceIDs != nil else { return [] }
        return store.config.sortedEntries.filter {
            !$0.name.isEmpty || !$0.notes.isEmpty || $0.symbolName != nil
        }.filter { store.isStale($0) }
    }

    private var allSpacesSection: some View {
        Group {
            if !liveSpaceEntries.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("All Spaces (\(liveSpaceEntries.count))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(liveSpaceEntries) { entry in
                                allSpacesRow(entry)
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
    }

    private func allSpacesRow(_ entry: SpaceConfig.SpaceEntry) -> some View {
        let isCurrent = entry.id == store.currentSpaceID
        return HStack(spacing: 6) {
            Image(systemName: entry.symbolName ?? "circle")
                .font(.system(size: 12))
                .frame(width: 16)
                .foregroundStyle(.secondary)
            Text(entry.name.isEmpty ? "Untitled Space" : entry.name)
                .font(.callout)
                .fontWeight(isCurrent ? .semibold : .regular)
                .foregroundStyle(entry.name.isEmpty ? .tertiary : .primary)
            Spacer()
            if isCurrent {
                Image(systemName: "checkmark")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func spaceRow(_ entry: SpaceConfig.SpaceEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if isEditingRow {
                IconPickerView(symbolName: $draftSymbolName, isExpanded: $showIconPicker)
            } else if let symbolName = entry.symbolName {
                Image(systemName: symbolName)
                    .font(.system(size: 15))
                    .frame(width: 28, height: 28)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if isEditingRow {
                        TextField("Untitled Space", text: $draftName)
                            .textFieldStyle(.plain)
                            .font(.headline)
                    } else {
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
                        Button("Cancel") { cancelEdit() }
                            .font(.caption)
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        Button("Done") { commitEdit(for: entry) }
                            .font(.caption)
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                    } else if isRowHovered {
                        Button { beginEditing(with: entry) } label: {
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
                    MarkdownNotesEditor(text: $draftNotes, placeholder: "Notes…", minHeight: 100, maxHeight: 220)
                } else {
                    NotesPlainTextView(text: entry.notes)
                }
            }
        }
        .padding(8)
        .onHover { isRowHovered = $0 }
        .onExitCommand { cancelEdit() }
    }

    private func beginEditing(with entry: SpaceConfig.SpaceEntry) {
        draftName = entry.name
        draftNotes = entry.notes
        draftSymbolName = entry.symbolName
        isEditingRow = true
    }

    private func commitEdit(for entry: SpaceConfig.SpaceEntry) {
        store.config.restore(
            SpaceConfig.SpaceEntry(id: entry.id, name: draftName, notes: draftNotes, symbolName: draftSymbolName)
        )
        scheduleSavedIndicator()
        isEditingRow = false
    }

    private func cancelEdit() {
        isEditingRow = false
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
                    Button("Refresh Spaces") {
                        store.refreshSpaceStatus()
                    }
                    Divider()
                    if !unavailableSpaceEntries.isEmpty {
                        ForEach(unavailableSpaceEntries) { entry in
                            let name = entry.name.isEmpty ? "Untitled Space" : entry.name
                            Menu(name) {
                                Button("Forget") {
                                    confirmRemove(entry)
                                }
                                Button("Backup…") {
                                    backup(entry)
                                }
                                Button("Assign to Current") {
                                    reassign(entry)
                                }
                                .disabled(store.currentEntry == nil)
                            }
                        }
                        Divider()
                    }
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
        backup(entry)
    }

    private func backup(_ entry: SpaceConfig.SpaceEntry) {
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

    private func reassign(_ source: SpaceConfig.SpaceEntry) {
        guard let currentID = store.currentSpaceID,
              let current = store.currentEntry else { return }

        if !current.name.isEmpty || !current.notes.isEmpty || current.symbolName != nil {
            let alert = NSAlert()
            alert.messageText = "Replace Current Space?"
            alert.informativeText = "This will replace the current Space’s name, notes, and icon with the saved settings from “\(source.name.isEmpty ? "Untitled Space" : source.name)”."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Replace")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        store.config.copy(source, to: currentID)
        scheduleSavedIndicator()
    }

    private func confirmRemove(_ entry: SpaceConfig.SpaceEntry) {
        let name = entry.name.isEmpty ? "Untitled Space" : entry.name
        let alert = NSAlert()
        alert.messageText = "Remove Saved Space?"
        alert.informativeText = "The saved name, notes, and icon for “\(name)” will be permanently deleted. This will not affect macOS Spaces."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        store.config.delete(id: entry.id)
    }

}
