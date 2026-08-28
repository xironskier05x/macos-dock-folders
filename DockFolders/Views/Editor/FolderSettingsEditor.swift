import SwiftUI

public struct FolderSettingsEditor: View {
    @Binding var targetPath: String
    @Binding var maxDepth: Int

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Source Directory")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack {
                TextField("Path to folder…", text: $targetPath)
                    .textFieldStyle(.roundedBorder)

                Button("Browse…") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        targetPath = url.path
                    }
                }
            }

            Divider()

            HStack {
                Text("Submenu Nesting Depth:")
                Spacer()
                Stepper("\(maxDepth) level\(maxDepth == 1 ? "" : "s")", value: $maxDepth, in: 0...10)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
    }
}
