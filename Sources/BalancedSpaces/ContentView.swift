import SwiftUI

struct ContentView: View {
    @Bindable var store: SpaceStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            currentSpaceSection
            Divider()
            spacesSection
            Divider()
            footer
        }
        .frame(width: 340, height: 480)
    }

    private var currentSpaceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(store.currentSpaceName)
                    .font(.headline)
                Spacer()
                Text("Current Space")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            TextEditor(text: currentNotesBinding)
                .font(.callout)
                .frame(minHeight: 56, maxHeight: 96)
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
        HStack {
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(10)
    }

    private var currentNotesBinding: Binding<String> {
        Binding(
            get: { store.currentEntry?.notes ?? "" },
            set: { newValue in
                guard let id = store.currentSpaceID, id != 0 else { return }
                store.config.updateNotes(newValue, for: id)
            }
        )
    }

    private func nameBinding(for entry: SpaceConfig.SpaceEntry) -> Binding<String> {
        Binding(
            get: { store.config.entry(for: entry.id)?.name ?? entry.name },
            set: { store.config.updateName($0, for: entry.id) }
        )
    }

    private func notesBinding(for entry: SpaceConfig.SpaceEntry) -> Binding<String> {
        Binding(
            get: { store.config.entry(for: entry.id)?.notes ?? entry.notes },
            set: { store.config.updateNotes($0, for: entry.id) }
        )
    }
}
