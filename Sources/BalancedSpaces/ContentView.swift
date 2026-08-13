import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var store: SpaceStore
    @AppStorage("libraryExpanded") private var libraryExpanded = true
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
    @State private var libraryContentHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            spacesSection
            allSpacesSection
            unavailableSpacesSection
            librarySection
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
            } else if store.currentSpaceID != nil, store.currentSpaceID != 0 {
                unassignedSpaceBanner
                    .padding(12)
            } else {
                Text("No Space detected")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(12)
            }
        }
    }

    private var unassignedSpaceBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No entry for this Space")
                .font(.title3)
            Text("Create a new entry, or assign one from your Library below.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Create New") { createAndEdit() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var liveSpaceEntries: [SpaceConfig.SpaceEntry] {
        if let liveSpaceIDs = store.liveSpaceIDs {
            return store.config.sortedEntries.filter { entry in
                guard let assigned = entry.assignedSpaceID else { return false }
                return liveSpaceIDs.contains(assigned)
            }
        }
        guard let currentSpaceID = store.currentSpaceID else { return [] }
        return store.config.sortedEntries.filter { $0.assignedSpaceID == currentSpaceID }
    }

    private var unavailableSpaceEntries: [SpaceConfig.SpaceEntry] {
        guard store.liveSpaceIDs != nil else { return [] }
        return store.config.sortedEntries.filter { store.isStale($0) }
    }

    private var unassignedEntries: [SpaceConfig.SpaceEntry] {
        store.config.unassignedEntries
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
                    .frame(height: min(allSpacesContentHeight > 0 ? ceil(allSpacesContentHeight) : CGFloat(liveSpaceEntries.count * 34), 240))
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
                                LibraryEntryRow(
                                    entry: entry,
                                    onUnassign: { store.config.unassign(entry.id) }
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

    private var librarySection: some View {
        Group {
            if !unassignedEntries.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { libraryExpanded.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .rotationEffect(.degrees(libraryExpanded ? 90 : 0))
                            Text("Library (\(unassignedEntries.count))")
                                .font(.callout)
                        }
                        .foregroundStyle(.secondary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if libraryExpanded {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(unassignedEntries) { entry in
                                    LibraryEntryRow(
                                        entry: entry,
                                        onAssignToCurrent: store.currentSpaceID != nil && store.currentSpaceID != 0
                                            ? { store.config.assign(entry.id, toSpaceID: store.currentSpaceID!) }
                                            : nil,
                                        onDelete: { store.config.delete(id: entry.id) }
                                    )
                                }
                            }
                            .onGeometryChange(for: CGFloat.self) { proxy in
                                proxy.size.height
                            } action: { newHeight in
                                libraryContentHeight = newHeight
                            }
                        }
                        .frame(height: min(libraryContentHeight > 0 ? ceil(libraryContentHeight) : CGFloat(unassignedEntries.count * 24), 120))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
    }

    private func createAndEdit() {
        guard let id = store.currentSpaceID, id != 0 else { return }
        let entry = store.config.createEntry(boundTo: id)
        beginEditing(with: entry)
    }

    private func allSpacesRow(_ entry: SpaceConfig.SpaceEntry) -> some View {
        let isCurrent = entry.assignedSpaceID != nil && entry.assignedSpaceID == store.currentSpaceID
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
                            Button("Unassign") { store.config.unassign(entry.id) }
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
                    Button("Back Up to File…", action: exportEntries)
                    Button("Restore from File…", action: importEntries)
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

    private func exportEntries() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Balanced Spaces.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try store.config.exportData().write(to: url, options: .atomic) }
        catch { saveLoadError = "Export failed: \(error.localizedDescription)" }
    }

    private func importEntries() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) else { return }
        let alert = NSAlert()
        alert.messageText = "Import Entries"
        alert.informativeText = "Add imported entries to your library, or replace everything?"
        alert.addButton(withTitle: "Add to Library")
        alert.addButton(withTitle: "Replace All")
        alert.addButton(withTitle: "Cancel")
        let result = alert.runModal()
        guard result != .alertThirdButtonReturn else { return }
        if result == .alertSecondButtonReturn {
            let confirm = NSAlert()
            confirm.messageText = "Replace All Entries?"
            confirm.informativeText = "This overwrites every entry, including current Space assignments."
            confirm.addButton(withTitle: "Replace All")
            confirm.addButton(withTitle: "Cancel")
            guard confirm.runModal() == .alertFirstButtonReturn else { return }
        }
        do { try store.config.importData(data, replace: result == .alertSecondButtonReturn) }
        catch { saveLoadError = "Import failed: \(error.localizedDescription)" }
    }
}

/// A compact row for an entry not shown in the primary editor: either bound to
/// an offline Space (Unavailable) or unbound (Library).
private struct LibraryEntryRow: View {
    let entry: SpaceConfig.SpaceEntry
    var onAssignToCurrent: (() -> Void)?
    var onUnassign: (() -> Void)?
    var onDelete: (() -> Void)?
    @State private var isHovered = false

    init(entry: SpaceConfig.SpaceEntry, onAssignToCurrent: (() -> Void)? = nil, onUnassign: (() -> Void)? = nil, onDelete: (() -> Void)? = nil) {
        self.entry = entry
        self.onAssignToCurrent = onAssignToCurrent
        self.onUnassign = onUnassign
        self.onDelete = onDelete
    }

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
            // Keep the control in the layout even when it is hidden so the row's
            // hover area doesn't shift when the control appears.
            Menu {
                if let onAssignToCurrent { Button("Assign to Current Space", action: onAssignToCurrent) }
                if let onUnassign { Button("Unassign", action: onUnassign) }
                if let onDelete { Button("Delete", role: .destructive, action: onDelete) }
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
