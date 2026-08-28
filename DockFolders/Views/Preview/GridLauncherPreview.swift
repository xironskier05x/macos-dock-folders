import SwiftUI

public struct GridLauncherPreview: View {
    let tile: DockTile

    var previewItems: [LauncherItem] {
        if !tile.items.isEmpty {
            return Array(tile.items.prefix(15))
        }
        // Fallback mockup items
        return [
            LauncherItem(name: "ChatGPT", path: "", resolvedPath: "", isDirectory: false, isPackage: true, isApp: true, icon: NSWorkspace.shared.icon(forFile: "/System/Applications/Utilities/Terminal.app")),
            LauncherItem(name: "Claude", path: "", resolvedPath: "", isDirectory: false, isPackage: true, isApp: true, icon: NSWorkspace.shared.icon(forFile: "/System/Applications/Safari.app")),
            LauncherItem(name: "Notes", path: "", resolvedPath: "", isDirectory: false, isPackage: true, isApp: true, icon: NSWorkspace.shared.icon(forFile: "/System/Applications/Notes.app")),
            LauncherItem(name: "Documentation", path: "", resolvedPath: "", isDirectory: true, isPackage: false, isApp: false, icon: NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app")),
            LauncherItem(name: "Project Plan", path: "", resolvedPath: "", isDirectory: false, isPackage: false, isApp: false, icon: NSWorkspace.shared.icon(forFile: "/System/Applications/TextEdit.app"))
        ]
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(tile.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(previewItems.count) items")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()

            let cols = max(3, min(tile.config.resolvedGridColumns, 6))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: cols), spacing: 10) {
                ForEach(previewItems) { item in
                    VStack(spacing: 4) {
                        Image(nsImage: item.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 36, height: 36)
                        if tile.config.resolvedShowLabels {
                            Text(item.name)
                                .font(.system(size: 10))
                                .lineLimit(1)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(4)
                }
            }
            .padding(12)
        }
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}
