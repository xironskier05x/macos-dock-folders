import SwiftUI

@main
struct DockFoldersApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var tileStore = TileStore()
    @StateObject private var selectionStore = SelectionStore()

    var body: some Scene {
        WindowGroup("Dock Folders Manager") {
            ContentView()
                .environmentObject(tileStore)
                .environmentObject(selectionStore)
                .frame(minWidth: 800, minHeight: 520)
        }
        .commands {
            SidebarCommands()

            CommandGroup(replacing: .newItem) {
                Button("New Dock Folder…") {
                    selectionStore.isShowingNewTileSheet = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandMenu("Folder") {
                Button("Rebuild Selected Launcher") {
                    if let selectedId = selectionStore.selectedTileId,
                       let tile = tileStore.tile(for: selectedId),
                       let runtimeURL = RuntimeInstallerService.getOrCreateRuntime() {
                        _ = try? tileStore.rebuildTile(tile, runtimeURL: runtimeURL)
                    }
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Toggle Dock Pin") {
                    if let selectedId = selectionStore.selectedTileId,
                       let tile = tileStore.tile(for: selectedId) {
                        tileStore.toggleDockPin(for: tile)
                    }
                }

                Button("Reveal in Finder") {
                    if let selectedId = selectionStore.selectedTileId,
                       let tile = tileStore.tile(for: selectedId) {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: tile.appPath)])
                    }
                }
            }
        }

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}
