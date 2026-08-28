import SwiftUI

public struct TileSidebarView: View {
    @EnvironmentObject var tileStore: TileStore
    @EnvironmentObject var selectionStore: SelectionStore

    var filteredTiles: [DockTile] {
        let query = selectionStore.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            return tileStore.tiles
        }
        return tileStore.tiles.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    public var body: some View {
        List(selection: $selectionStore.selectedTileId) {
            Section(header: Text("My Dock Folders (\(tileStore.tiles.count))").font(.caption).foregroundColor(.secondary)) {
                ForEach(filteredTiles) { tile in
                    NavigationLink(value: tile.id) {
                        TileSidebarRow(tile: tile)
                    }
                    .contextMenu {
                        Button(action: {
                            if let runtimeURL = RuntimeInstallerService.getOrCreateRuntime() {
                                _ = try? tileStore.rebuildTile(tile, runtimeURL: runtimeURL)
                            }
                        }) {
                            Label("Rebuild Launcher", systemImage: "arrow.clockwise")
                        }

                        Button(action: {
                            tileStore.toggleDockPin(for: tile)
                        }) {
                            Label(tile.isDockPinned ? "Remove from Dock" : "Add to Dock", systemImage: tile.isDockPinned ? "pin.slash" : "pin")
                        }

                        Button(action: {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: tile.appPath)])
                        }) {
                            Label("Reveal in Finder", systemImage: "folder")
                        }

                        Divider()

                        Button(role: .destructive, action: {
                            tileStore.deleteTile(tile, deleteCollection: true)
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $selectionStore.searchText, placement: .sidebar, prompt: "Filter Folders…")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { selectionStore.isShowingNewTileSheet = true }) {
                    Label("New Dock Folder", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("Create a new Dock Folder (⌘N)")
            }
        }
    }
}
