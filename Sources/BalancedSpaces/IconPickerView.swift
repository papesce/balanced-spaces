import SwiftUI

struct IconPickerView: View {
    @Binding var symbolName: String?
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            isExpanded.toggle()
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
    }
}

/// Full-window scrim that dismisses the icon picker when the user taps anywhere outside it.
/// `.popover` is unreliable inside a `MenuBarExtra` in `.window` style, so we roll our own.
struct IconPickerDismissScrim: View {
    @Binding var isExpanded: Bool

    var body: some View {
        if isExpanded {
            Color.black.opacity(0.0001)
                .contentShape(Rectangle())
                .onTapGesture { isExpanded = false }
                .allowsHitTesting(true)
        }
    }
}

struct IconPickerPanel: View {
    @Binding var symbolName: String?
    @Binding var isExpanded: Bool
    private let curated = ["briefcase", "house", "heart", "book", "graduationcap", "dollarsign.circle", "figure.walk", "fork.knife", "music.note", "gamecontroller"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("A small visual cue is enough. You can also leave this empty.")
                .font(.caption)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 30, maximum: 30), spacing: 6)], spacing: 6) {
                iconButton(nil)
                ForEach(curated, id: \.self) { iconButton($0) }
            }
        }
        .padding(10)
        .frame(width: 180)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.12)))
        .shadow(radius: 8, y: 2)
    }

    private func iconButton(_ name: String?) -> some View {
        Button {
            symbolName = name
            isExpanded = false
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
}
