import SwiftUI

struct IconPickerView: View {
    @Binding var symbolName: String?
    @State private var isPresented = false
    @State private var showAllSymbols = false
    @State private var searchText = ""

    private let curated = ["briefcase", "house", "heart", "book", "graduationcap", "dollarsign.circle", "figure.walk", "fork.knife", "music.note", "gamecontroller"]

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: symbolName ?? "square.dashed")
                .font(.system(size: 15))
                .foregroundStyle(symbolName == nil ? .tertiary : .primary)
                .frame(width: 28, height: 28)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("Choose an icon")
        .accessibilityLabel("Choose an icon")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose an icon")
                    .font(.headline)
                Text("A small visual cue is enough. You can also leave this empty.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    iconButton(nil)
                    ForEach(curated, id: \.self) { iconButton($0) }
                }
                Divider()
                Button(showAllSymbols ? "Hide all SF Symbols" : "More icons…") {
                    withAnimation { showAllSymbols.toggle() }
                }
                if showAllSymbols {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Search SF Symbols", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(6)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 30, maximum: 30), spacing: 6)], spacing: 6) {
                            ForEach(filteredSymbols, id: \.self) { iconButton($0) }
                        }
                    }
                    .frame(maxHeight: 210)
                }
            }
            .padding(14)
            .frame(width: showAllSymbols ? 330 : 310)
        }
    }

    private func iconButton(_ name: String?) -> some View {
        Button {
            symbolName = name
            isPresented = false
        } label: {
            Image(systemName: name ?? "nosign")
                .font(.system(size: 15))
                .frame(width: 28, height: 28)
                .background(name == symbolName ? Color.accentColor.opacity(0.22) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(name ?? "No icon")
        .accessibilityLabel(name ?? "No icon")
    }

    private var filteredSymbols: [String] {
        guard !searchText.isEmpty else { return Self.allSymbolNames }
        return Self.allSymbolNames.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private static let allSymbolNames: [String] = {
        guard let bundle = Bundle(url: URL(fileURLWithPath: "/System/Library/CoreServices/CoreGlyphs.bundle")),
              let url = bundle.url(forResource: "name_availability", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any],
              let symbols = dict["symbols"] as? [String: Any] else { return [] }
        return symbols.keys.sorted()
    }()
}
