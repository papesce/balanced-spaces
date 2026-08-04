import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("menuBarStyle") private var menuBarStyle = MenuBarStyle.window.rawValue
    @State private var backupsFolder: URL?
    @State private var launchAtLoginError: String?

    private let backupManager = BackupManager()

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { setLaunchAtLogin($0) }
                ))
                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Menu Bar") {
                Picker("Style", selection: $menuBarStyle) {
                    Text("Window").tag(MenuBarStyle.window.rawValue)
                    Text("Menu").tag(MenuBarStyle.menu.rawValue)
                }
                Text("Restart Balanced Spaces for a style change to take effect.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Backups") {
                HStack {
                    Text(backupsFolder?.path ?? "—")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                    Spacer()
                    Button("Reveal in Finder") {
                        if let backupsFolder {
                            NSWorkspace.shared.activateFileViewerSelecting([backupsFolder])
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 380)
        .onAppear { backupsFolder = try? backupManager.backupsFolderURL() }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = "Couldn't update login item: \(error.localizedDescription)"
        }
    }
}

enum MenuBarStyle: String {
    case window
    case menu
}
