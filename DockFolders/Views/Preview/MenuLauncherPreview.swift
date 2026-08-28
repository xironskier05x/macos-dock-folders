import SwiftUI

public struct MenuLauncherPreview: View {
    let tile: DockTile

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(tile.name)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            Divider()

            VStack(alignment: .leading, spacing: 2) {
                MockMenuItem(title: "ChatGPT.app", icon: "/System/Applications/Utilities/Terminal.app", shortcut: "⌘1")
                MockMenuItem(title: "Claude.app", icon: "/System/Applications/Safari.app", shortcut: "⌘2")
                MockMenuItem(title: "Documentation", icon: "/System/Library/CoreServices/Finder.app", hasSubmenu: true)
                MockMenuItem(title: "Research.pdf", icon: "/System/Applications/Preview.app", shortcut: "⌘3")
            }
            .padding(.vertical, 4)

            Divider()

            VStack(alignment: .leading, spacing: 2) {
                MockMenuItem(title: "Show in Finder", icon: "/System/Library/CoreServices/Finder.app", shortcut: "⌘O")
                MockMenuItem(title: "Open in Terminal", icon: "/System/Applications/Utilities/Terminal.app", shortcut: "⌘T")
            }
            .padding(.vertical, 4)
        }
        .frame(width: 220)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }
}

struct MockMenuItem: View {
    let title: String
    let icon: String
    var shortcut: String? = nil
    var hasSubmenu: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            let img = NSWorkspace.shared.icon(forFile: icon)
            Image(nsImage: img)
                .resizable()
                .frame(width: 16, height: 16)
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.primary)
            Spacer()
            if let sc = shortcut {
                Text(sc)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            if hasSubmenu {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
    }
}
