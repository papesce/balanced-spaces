import AppKit
import SwiftUI

@main
struct BalancedSpacesApp: App {
    @State private var store = SpaceStore()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView(store: store)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }

    private var menuBarLabel: some View {
        HStack(spacing: 4) {
            if let symbol = store.currentEntry?.symbolName, !symbol.isEmpty {
                Image(systemName: symbol)
            }
            Text(store.currentSpaceName)
        }
    }
}
