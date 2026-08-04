import AppKit
import SwiftUI

@main
struct BalancedSpacesApp: App {
    @State private var store = SpaceStore()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    private var isMenuStyle: Bool {
        MenuBarStyle(rawValue: UserDefaults.standard.string(forKey: "menuBarStyle") ?? "") == .menu
    }

    var body: some Scene {
        MenuBarExtra(isInserted: .constant(!isMenuStyle)) {
            ContentView(store: store)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)

        MenuBarExtra(isInserted: .constant(isMenuStyle)) {
            ContentView(store: store)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.menu)

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
