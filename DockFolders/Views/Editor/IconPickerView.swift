import SwiftUI

public struct IconPickerView: View {
    @Binding var iconConfig: IconConfiguration
    let fallbackFolder: String?

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 20) {
                // Live preview thumbnail
                let previewImg = IconRendererService.renderImage(config: iconConfig, fallbackFolder: fallbackFolder, size: 128)
                Image(nsImage: previewImg)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .cornerRadius(14)
                    .shadow(color: .black.opacity(0.2), radius: 3, y: 1)

                Picker("Icon Style", selection: $iconConfig.type) {
                    Text("SF Symbol").tag(IconConfiguration.IconType.symbol)
                    Text("Emoji").tag(IconConfiguration.IconType.emoji)
                    Text("Custom Image").tag(IconConfiguration.IconType.customImage)
                    if fallbackFolder != nil {
                        Text("Default Folder").tag(IconConfiguration.IconType.defaultFolder)
                    }
                }
                .pickerStyle(.segmented)
            }

            if iconConfig.type == .symbol {
                SymbolPickerView(selectedSymbol: Binding(
                    get: { iconConfig.symbolName ?? "folder.badge.gear" },
                    set: { iconConfig.symbolName = $0 }
                ))
                ColorPickerSection(selectedHex: $iconConfig.colorHex)
            } else if iconConfig.type == .emoji {
                HStack {
                    Text("Emoji Character:")
                    TextField("🚀", text: Binding(
                        get: { iconConfig.emoji ?? "📁" },
                        set: { iconConfig.emoji = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                }
                ColorPickerSection(selectedHex: $iconConfig.colorHex)
            } else if iconConfig.type == .customImage {
                HStack {
                    Button("Choose Image…") {
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [.png, .jpeg, .icns]
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK, let url = panel.url {
                            iconConfig.imagePath = url.path
                        }
                    }
                    if let path = iconConfig.imagePath {
                        Text((path as NSString).lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
    }
}
