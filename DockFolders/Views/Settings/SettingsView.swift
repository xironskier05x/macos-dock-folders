import SwiftUI

public struct SettingsView: View {
    @ObservedObject var prefs = PreferencesStore.shared

    public var body: some View {
        Form {
            Section(header: Text("Defaults & Generation")) {
                HStack {
                    TextField("Output Directory", text: $prefs.defaultOutputDirectoryPath)
                    Button("Browse…") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        if panel.runModal() == .OK, let url = panel.url {
                            prefs.defaultOutputDirectoryPath = url.path
                        }
                    }
                }

                Picker("Default Tile Mode", selection: $prefs.defaultTileModeRaw) {
                    ForEach(TileMode.allCases) { mode in
                        Text(mode.displayName).tag(mode.rawValue)
                    }
                }

                Picker("Default Presentation", selection: $prefs.defaultPresentationRaw) {
                    ForEach(PresentationMode.allCases) { pres in
                        Text(pres.displayName).tag(pres.rawValue)
                    }
                }

                Stepper("Default Grid Columns: \(prefs.defaultGridColumns)", value: $prefs.defaultGridColumns, in: 4...7)
                Toggle("Show Item Text Labels in Grid by default", isOn: $prefs.defaultShowLabels)
                Toggle("Add new folders to macOS Dock automatically", isOn: $prefs.autoAddToDock)
            }

            Section(header: Text("Safety & Privacy")) {
                Toggle("Confirm when deleting a Dock Folder", isOn: $prefs.confirmDeletion)
                HStack {
                    Text("Telemetry & Analytics:")
                    Spacer()
                    Text("100% Offline & Disabled")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .frame(width: 480, height: 320)
    }
}
