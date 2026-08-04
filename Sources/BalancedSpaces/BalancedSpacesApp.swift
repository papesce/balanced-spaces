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
            Text(store.currentSpaceName)
        }
        .menuBarExtraStyle(.window)
    }
}
