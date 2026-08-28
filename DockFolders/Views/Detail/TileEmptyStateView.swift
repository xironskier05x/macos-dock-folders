import SwiftUI

public struct TileEmptyStateView: View {
    @EnvironmentObject var selectionStore: SelectionStore

    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))

            VStack(spacing: 6) {
                Text("No Dock Folder Selected")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Select an existing Dock Folder from the sidebar or create a new one.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }

            Button(action: { selectionStore.isShowingNewTileSheet = true }) {
                Label("Create New Dock Folder", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
