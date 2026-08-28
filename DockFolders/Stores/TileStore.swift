import Foundation
import SwiftUI
import AppKit

public class TileStore: ObservableObject {
    @Published public var tiles: [DockTile] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?

    public init() {
        loadTiles()
    }

    public func loadTiles() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let discovered = TileDiscoveryService.discoverTiles(in: PreferencesStore.shared.defaultOutputDirectory)
            DispatchQueue.main.async {
                self.tiles = discovered
                self.isLoading = false
            }
        }
    }

    public func tile(for id: String) -> DockTile? {
        tiles.first { $0.id == id }
    }

    public func createTile(
        name: String,
        targetPath: String,
        mode: TileMode,
        presentation: PresentationMode,
        sort: SortMode,
        maxDepth: Int,
        gridColumns: Int,
        showLabels: Bool,
        iconConfig: IconConfiguration,
        customOrder: [String]?,
        addToDock: Bool,
        runtimeURL: URL
    ) -> (success: Bool, tile: DockTile?, error: Error?) {
        do {
            let appPath = try TileGeneratorService.generateTile(
                name: name,
                targetPath: targetPath,
                tileMode: mode,
                presentationMode: presentation,
                sortMode: sort,
                maxDepth: maxDepth,
                gridColumns: gridColumns,
                showLabels: showLabels,
                iconConfig: iconConfig,
                customOrder: customOrder,
                outputDirectory: PreferencesStore.shared.defaultOutputDirectory,
                runtimeURL: runtimeURL
            )

            var isPinned = false
            if addToDock {
                isPinned = DockService.addToDock(appPath: appPath)
            }

            var items: [LauncherItem] = []
            if mode == .launcher {
                let tileID = FileHelpers.deterministicHash(for: targetPath)
                items = LauncherCollectionService.fetchItems(for: tileID, customOrder: customOrder)
            }

            let iconImage = IconRendererService.renderImage(config: iconConfig, fallbackFolder: targetPath, size: 256)
            let cfg = DockTileConfig(
                targetPath: targetPath,
                displayName: name,
                sortMode: sort.rawValue,
                maxDepth: maxDepth,
                tileMode: mode.rawValue,
                presentation: presentation.rawValue,
                gridColumns: gridColumns,
                showLabels: showLabels,
                customOrder: customOrder,
                iconConfig: iconConfig
            )

            let tile = DockTile(
                id: FileHelpers.deterministicHash(for: appPath),
                name: name,
                appPath: appPath,
                config: cfg,
                isDockPinned: isPinned,
                iconImage: iconImage,
                items: items,
                lastModified: Date()
            )

            DispatchQueue.main.async {
                self.tiles.removeAll { $0.appPath == appPath }
                self.tiles.append(tile)
                self.tiles.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }

            return (true, tile, nil)
        } catch {
            return (false, nil, error)
        }
    }

    public func rebuildTile(_ tile: DockTile, runtimeURL: URL) -> Bool {
        let result = createTile(
            name: tile.name,
            targetPath: tile.config.targetPath,
            mode: tile.config.resolvedTileMode,
            presentation: tile.config.resolvedPresentationMode,
            sort: tile.config.resolvedSortMode,
            maxDepth: tile.config.resolvedMaxDepth,
            gridColumns: tile.config.resolvedGridColumns,
            showLabels: tile.config.resolvedShowLabels,
            iconConfig: tile.config.iconConfig ?? IconConfiguration(),
            customOrder: tile.config.customOrder,
            addToDock: false,
            runtimeURL: runtimeURL
        )
        return result.success
    }

    public func deleteTile(_ tile: DockTile, deleteCollection: Bool = false) {
        // 1. Remove from Dock if pinned
        if tile.isDockPinned {
            _ = DockService.removeFromDock(appPath: tile.appPath)
        }

        // 2. Delete generated .app bundle
        try? FileManager.default.removeItem(atPath: tile.appPath)

        // 3. If Launcher collection and requested, delete internal collection directory
        if deleteCollection && tile.config.resolvedTileMode == .launcher {
            let tileID = FileHelpers.deterministicHash(for: tile.config.targetPath)
            let collectionDir = LauncherCollectionService.collectionDirectory(for: tileID)
            try? FileManager.default.removeItem(at: collectionDir)
        }

        // 4. Update memory store
        DispatchQueue.main.async {
            self.tiles.removeAll { $0.id == tile.id }
        }
    }

    public func toggleDockPin(for tile: DockTile) {
        if tile.isDockPinned {
            if DockService.removeFromDock(appPath: tile.appPath) {
                tile.isDockPinned = false
            }
        } else {
            if DockService.addToDock(appPath: tile.appPath) {
                tile.isDockPinned = true
            }
        }
    }
}
