import SwiftUI

public struct TilePreviewView: View {
    let tile: DockTile

    public var body: some View {
        VStack(spacing: 16) {
            Text("Live Dock & Popup Preview")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            if tile.config.resolvedPresentationMode == .grid {
                GridLauncherPreview(tile: tile)
            } else {
                MenuLauncherPreview(tile: tile)
            }
        }
    }
}
