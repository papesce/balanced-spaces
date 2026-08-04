import SwiftUI

struct OnboardingView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome to Balanced Spaces")
                .font(.title3)
                .bold()
            Text("This app tracks notes and an icon for each macOS Space (virtual desktop). Switch desktops with Ctrl+←/→ and this window updates to show the current one.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                bullet("Pick an icon and name for the space you're on right now")
                bullet("Jot quick notes — they're saved automatically")
                bullet("Use ⌘E to rename, ⌘N to jump to notes")
                bullet("Export/Import to back up or move your spaces between Macs")
            }

            Button("Got it") { onDismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(14)
        .frame(width: 340)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
            Text(text)
        }
        .font(.callout)
    }
}
