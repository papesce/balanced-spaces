import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var backupsFolder: URL?
    @State private var launchAtLoginError: String?

    private let fileManager = SpaceFileManager()
    private var isSigned: Bool {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return false }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return false }
        var info: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(staticCode, flags, &info) == errSecSuccess,
              let teamID = (info as? [String: Any])?["teamid"] as? String,
              !teamID.isEmpty else { return false }
        return true
    }

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { SMAppService.mainApp.status == .enabled },
                    set: { setLaunchAtLogin($0) }
                ))
                .disabled(!isSigned)
                if !isSigned {
                    Text("Requires a signed build.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
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

            Section("About") {
                Text("Balanced Spaces \(AppInfo.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onAppear { backupsFolder = try? fileManager.backupsFolderURL() }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = "Couldn't update login item: \(error.localizedDescription)"
        }
    }
}

enum AppInfo {
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.1"
}
