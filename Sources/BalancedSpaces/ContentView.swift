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
    @State private var draftDescription = ""
    @State private var draftNotes = ""
    @State private var draftSymbolName: String?
    @State private var isRowHovered = false
    @AppStorage("popoverWidth") private var popoverWidth: Double = 400
    @State private var isResizeHandleHovered = false
    @State private var dragStartWidth: Double?

    private let popoverWidthRange: ClosedRange<Double> = 340...600
    @State private var allSpacesContentHeight: CGFloat = 0
    @State private var unavailableSpacesContentHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            spacesSection
            allSpacesSection
            unavailableSpacesSection
            Divider()
            footer
        }
        .frame(width: popoverWidth)
        .overlay {
            if showIconPicker {
                IconPickerDismissScrim(isExpanded: $showIconPicker)
                IconPickerPanel(symbolName: $draftSymbolName, isExpanded: $showIconPicker)
                    .offset(x: 12, y: 40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            resizeHandle
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView {
                UserDefaults.standard.set(true, forKey: "didShowOnboarding")
                showOnboarding = false
            }
        }
        .autosizeMenuBarWindow()
    }

    /// Drags horizontally only — height stays automatic (see
    /// `WindowAutosize.swift`) — to resize the popover, persisting the
    /// chosen width across launches.
    private var resizeHandle: some View {
        Image(systemName: "arrow.left.and.right")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 18, height: 18)
            .contentShape(Rectangle())
            .opacity(isResizeHandleHovered ? 1 : 0.35)
            .padding(4)
            .onHover { hovering in
                isResizeHandleHovered = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let startWidth = dragStartWidth ?? popoverWidth
                        dragStartWidth = startWidth
                        let proposed = startWidth + value.translation.width
                        popoverWidth = min(max(proposed, popoverWidthRange.lowerBound), popoverWidthRange.upperBound)
                    }
                    .onEnded { _ in
                        dragStartWidth = nil
                    }
            )
    }

    private func confirmClearCurrentSpace() {
        guard store.currentEntry != nil else { return }
        let alert = NSAlert()
        alert.messageText = "Clear this Space?"
        alert.informativeText = "This removes the name, description, notes, and icon for the current Space. This can't be undone."
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
        store.config.updateDescription("", for: id)
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
            !$0.name.isEmpty || !$0.description.isEmpty || !$0.notes.isEmpty || $0.symbolName != nil
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
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.size.height
                        } action: { newHeight in
                            allSpacesContentHeight = newHeight
                        }
                    }
                    .frame(height: min(allSpacesContentHeight > 0 ? ceil(allSpacesContentHeight) : CGFloat(liveSpaceEntries.count * 34), 400))
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
        }
    }

    private var unavailableSpacesSection: some View {
        Group {
            if !unavailableSpaceEntries.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unavailable Spaces (\(unavailableSpaceEntries.count))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(unavailableSpaceEntries) { entry in
                                UnavailableSpaceRow(
                                    entry: entry,
                                    canAssign: store.currentEntry != nil,
                                    onSaveAndClear: { saveAndClear(entry) },
                                    onCopyToCurrent: { reassign(entry) }
                                )
                            }
                        }
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.size.height
                        } action: { newHeight in
                            unavailableSpacesContentHeight = newHeight
                        }
                    }
                    .frame(height: min(unavailableSpacesContentHeight > 0 ? ceil(unavailableSpacesContentHeight) : CGFloat(unavailableSpaceEntries.count * 24), 144))
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
    }

    private func allSpacesRow(_ entry: SpaceConfig.SpaceEntry) -> some View {
        let isCurrent = entry.id == store.currentSpaceID
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: entry.symbolName ?? "circle")
                .font(.system(size: 12))
                .frame(width: 16)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name.isEmpty ? "Untitled Space" : entry.name)
                    .font(.callout)
                    .fontWeight(isCurrent ? .semibold : .regular)
                    .foregroundStyle(entry.name.isEmpty ? .tertiary : .primary)
                if !entry.description.isEmpty {
                    Text(entry.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
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
                            .font(.title3)
                    } else {
                        Text(entry.name.isEmpty ? "Untitled Space" : entry.name)
                            .font(.title3)
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
                    } else {
                        Menu {
                            Button("Edit…", action: { beginEditing(with: entry) })
                            Button("Save…", action: { _ = backup(entry) })
                            Button("Load…", action: loadSpace)
                            Button("Save and Clear…", action: saveAndClearCurrentSpace)
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 14))
                                .frame(width: 22, height: 22)
                                .contentShape(Rectangle())
                                .foregroundStyle(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .opacity(isRowHovered ? 1 : 0)
                    }
                }
                if isEditingRow {
                    TextField("Description…", text: $draftDescription)
                        .textFieldStyle(.plain)
                        .font(.callout)
                    MarkdownNotesEditor(text: $draftNotes, placeholder: "Notes…", minHeight: 100, maxHeight: 220)
                } else {
                    DescriptionPlainTextView(text: entry.description)
                    NotesPlainTextView(text: entry.notes)
                }
            }
        }
        .onContinuousHover { phase in
            if case .active = phase { isRowHovered = true } else { isRowHovered = false }
        }
        .onExitCommand { cancelEdit() }
    }

    private func beginEditing(with entry: SpaceConfig.SpaceEntry) {
        draftName = entry.name
        draftDescription = entry.description
        draftNotes = entry.notes
        draftSymbolName = entry.symbolName
        isEditingRow = true
    }

    private func commitEdit(for entry: SpaceConfig.SpaceEntry) {
        store.config.restore(
            SpaceConfig.SpaceEntry(id: entry.id, name: draftName, description: draftDescription, notes: draftNotes, symbolName: draftSymbolName)
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
                Text("v\(AppInfo.version)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Menu {
                    Button("Refresh Spaces") {
                        store.refreshSpaceStatus()
                    }
                    Divider()
                    Button("Save All Spaces…", action: saveAllSpaces)
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
        .padding(.leading, 12)
        .padding(.trailing, 34)
        .padding(.vertical, 8)
    }

    private func saveAndClearCurrentSpace() {
        guard let entry = store.currentEntry else { return }
        if backup(entry) {
            confirmClearCurrentSpace()
        }
    }

    private func backup(_ entry: SpaceConfig.SpaceEntry) -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.balancedSpace]
        let baseName = (entry.name.isEmpty ? "Untitled Space" : entry.name)
            .replacingOccurrences(of: " ", with: "-")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        let stamp = formatter.string(from: Date())
        panel.nameFieldStringValue = "\(baseName) \(stamp).balancedspace"
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        do {
            try fileManager.save(entry: entry, to: url)
            saveLoadError = nil
            return true
        } catch {
            saveLoadError = "Save failed: \(error.localizedDescription)"
            return false
        }
    }

    private func saveAndClear(_ entry: SpaceConfig.SpaceEntry) {
        if backup(entry) {
            store.config.delete(id: entry.id)
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

        if !current.name.isEmpty || !current.description.isEmpty || !current.notes.isEmpty || current.symbolName != nil {
            let alert = NSAlert()
            alert.messageText = "Replace Current Space?"
            alert.informativeText = "This will replace the current Space’s name, description, notes, and icon with the saved settings from “\(source.name.isEmpty ? "Untitled Space" : source.name)”."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Replace")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        store.config.copy(source, to: currentID)
        scheduleSavedIndicator()
    }

}

private struct UnavailableSpaceRow: View {
    let entry: SpaceConfig.SpaceEntry
    let canAssign: Bool
    let onSaveAndClear: () -> Void
    let onCopyToCurrent: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: entry.symbolName ?? "circle")
                .font(.system(size: 12))
                .frame(width: 16)
                .foregroundStyle(.secondary)
            Text(entry.name.isEmpty ? "Untitled Space" : entry.name)
                .font(.callout)
                .foregroundStyle(entry.name.isEmpty ? .tertiary : .primary)
            Spacer()
            // Keep the control in the layout even when it is hidden. This
            // prevents the row's hover area from moving when the control appears,
            // so it can be reached from the label without losing the hover state.
            Menu {
                Button("Save and Clear…", action: onSaveAndClear)
                Button("Copy to Current", action: onCopyToCurrent)
                    .disabled(!canAssign)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .opacity(isHovered ? 1 : 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}
