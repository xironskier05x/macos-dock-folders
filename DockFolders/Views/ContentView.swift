import SwiftUI

public struct ContentView: View {
    @EnvironmentObject var tileStore: TileStore
    @EnvironmentObject var selectionStore: SelectionStore

    public var body: some View {
        NavigationSplitView {
            TileSidebarView()
        } detail: {
            if let selectedId = selectionStore.selectedTileId,
               let tile = tileStore.tile(for: selectedId) {
                TileDetailView(tile: tile)
            } else {
                TileEmptyStateView()
            }
        }
        .sheet(isPresented: $selectionStore.isShowingNewTileSheet) {
            TileEditorView()
        }
        .sheet(item: $selectionStore.editingTile) { tile in
            TileEditorView(existingTile: tile)
        }
        .sheet(isPresented: $selectionStore.isShowingSettings) {
            SettingsView()
        }
    }
}
