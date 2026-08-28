import SwiftUI

public struct GridLauncherPreview: View {
    let tile: DockTile

    var previewItems: [LauncherItem] {
        if !tile.items.isEmpty {
            return Array(tile.items.prefix(15))
        }
        return [
            LauncherItem(name: "ChatGPT", path: "", resolvedPath: "", isDirectory: false, isPackage: true, isApp: true, icon: NSWorkspace.shared.icon(forFile: "/System/Applications/Utilities/Terminal.app")),
            LauncherItem(name: "Claude", path: "", resolvedPath: "", isDirectory: false, isPackage: true, isApp: true, icon: NSWorkspace.shared.icon(forFile: "/System/Applications/Safari.app")),
            LauncherItem(name: "Notes", path: "", resolvedPath: "", isDirectory: false, isPackage: true, isApp: true, icon: NSWorkspace.shared.icon(forFile: "/System/Applications/Notes.app")),
            LauncherItem(name: "Finder", path: "", resolvedPath: "", isDirectory: true, isPackage: false, isApp: false, icon: NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app")),
            LauncherItem(name: "TextEdit", path: "", resolvedPath: "", isDirectory: false, isPackage: false, isApp: false, icon: NSWorkspace.shared.icon(forFile: "/System/Applications/TextEdit.app"))
        ]
    }

    var colsCount: Int {
        let count = max(1, previewItems.count)
        return max(1, min(tile.config.resolvedGridColumns, count))
    }

    public var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(60), spacing: 8), count: colsCount), spacing: 8) {
            ForEach(previewItems) { item in
                VStack(spacing: 4) {
                    Image(nsImage: item.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 38, height: 38)
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    if tile.config.resolvedShowLabels {
                        Text(item.name)
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                            .foregroundColor(.primary)
                    }
                }
                .padding(4)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
    }
}
