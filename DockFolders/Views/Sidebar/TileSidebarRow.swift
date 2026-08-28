import SwiftUI

public struct TileSidebarRow: View {
    @ObservedObject var tile: DockTile

    public var body: some View {
        HStack(spacing: 10) {
            if let img = tile.iconImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .cornerRadius(6)
            } else {
                Image(systemName: tile.config.resolvedTileMode.systemImage)
                    .font(.system(size: 20))
                    .frame(width: 28, height: 28)
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(tile.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(.primary)

                HStack(spacing: 4) {
                    Text(tile.config.resolvedTileMode.displayName)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(4)

                    Text(tile.config.resolvedPresentationMode == .grid ? "Grid" : "Menu")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    if tile.isDockPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.accentColor)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
