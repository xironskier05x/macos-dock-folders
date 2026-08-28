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
        .alert("Notice", isPresented: Binding(
            get: { tileStore.lastWarningMessage != nil },
            set: { if !$0 { tileStore.lastWarningMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                tileStore.lastWarningMessage = nil
            }
        } message: {
            if let msg = tileStore.lastWarningMessage {
                Text(msg)
            }
        }
        .alert("Error", isPresented: Binding(
            get: { tileStore.errorMessage != nil },
            set: { if !$0 { tileStore.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                tileStore.errorMessage = nil
            }
        } message: {
            if let err = tileStore.errorMessage {
                Text(err)
            }
        }
    }
}
