import Foundation
import SwiftUI
import AppKit

public class TileStore: ObservableObject {
    @Published public var tiles: [DockTile] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var lastWarningMessage: String?

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
        collectionID: String?,
        addToDock: Bool,
        runtimeURL: URL
    ) throws -> DockTile {
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
            collectionID: collectionID,
            outputDirectory: PreferencesStore.shared.defaultOutputDirectory,
            runtimeURL: runtimeURL
        )

        var isPinned = false
        if addToDock {
            let added = DockService.addToDock(appPath: appPath)
            isPinned = DockService.isTileInDock(appPath: appPath)
            if !added || !isPinned {
                let warning = "Launcher created successfully, but it could not be added to the Dock."
                self.lastWarningMessage = warning
            }
        } else {
            isPinned = DockService.isTileInDock(appPath: appPath)
        }

        var items: [LauncherItem] = []
        if mode == .launcher {
            let targetURL = URL(fileURLWithPath: targetPath)
            items = LauncherCollectionService.fetchItems(for: targetURL, customOrder: customOrder)
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
            collectionID: collectionID,
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

        return tile
    }

    public func updateTile(
        existingTile: DockTile,
        newName: String,
        targetPath: String,
        mode: TileMode,
        presentation: PresentationMode,
        sort: SortMode,
        maxDepth: Int,
        gridColumns: Int,
        showLabels: Bool,
        iconConfig: IconConfiguration,
        customOrder: [String]?,
        runtimeURL: URL,
        newCollectionID: String? = nil
    ) throws -> DockTile {
        let oldAppPath = existingTile.appPath
        let wasPinned = DockService.isTileInDock(appPath: oldAppPath)
        let finalCollectionID = newCollectionID ?? existingTile.config.collectionID

        let newAppPath = try TileGeneratorService.generateTile(
            name: newName,
            targetPath: targetPath,
            tileMode: mode,
            presentationMode: presentation,
            sortMode: sort,
            maxDepth: maxDepth,
            gridColumns: gridColumns,
            showLabels: showLabels,
            iconConfig: iconConfig,
            customOrder: customOrder,
            collectionID: finalCollectionID,
            outputDirectory: PreferencesStore.shared.defaultOutputDirectory,
            runtimeURL: runtimeURL,
            allowedExistingAppURL: URL(fileURLWithPath: oldAppPath),
            allowForeignOverwrite: false
        )

        // Transactional rename & Dock update
        if oldAppPath != newAppPath {
            if wasPinned {
                let addSuccess = DockService.addToDock(appPath: newAppPath)
                guard addSuccess && DockService.isTileInDock(appPath: newAppPath) else {
                    // Roll back new app if Dock addition fails
                    try? FileManager.default.removeItem(atPath: newAppPath)
                    throw TileGenerationError.installFailed("Failed to update Dock entry for renamed tile. Changes rolled back.")
                }
                _ = DockService.removeFromDock(appPath: oldAppPath)
            }
            if FileManager.default.fileExists(atPath: oldAppPath) {
                try? FileManager.default.removeItem(atPath: oldAppPath)
            }
        }

        let isPinned = DockService.isTileInDock(appPath: newAppPath)
        let iconImage = IconRendererService.renderImage(config: iconConfig, fallbackFolder: targetPath, size: 256)
        
        var items: [LauncherItem] = []
        if mode == .launcher {
            let targetURL = URL(fileURLWithPath: targetPath)
            items = LauncherCollectionService.fetchItems(for: targetURL, customOrder: customOrder)
        }

        existingTile.name = newName
        existingTile.appPath = newAppPath
        existingTile.isDockPinned = isPinned
        existingTile.iconImage = iconImage
        existingTile.items = items
        existingTile.lastModified = Date()
        existingTile.config = DockTileConfig(
            targetPath: targetPath,
            displayName: newName,
            sortMode: sort.rawValue,
            maxDepth: maxDepth,
            tileMode: mode.rawValue,
            presentation: presentation.rawValue,
            gridColumns: gridColumns,
            showLabels: showLabels,
            customOrder: customOrder,
            collectionID: finalCollectionID,
            iconConfig: iconConfig
        )

        DispatchQueue.main.async {
            self.objectWillChange.send()
        }

        return existingTile
    }

    public func rebuildTile(_ tile: DockTile, runtimeURL: URL) throws -> DockTile {
        return try updateTile(
            existingTile: tile,
            newName: tile.name,
            targetPath: tile.config.targetPath,
            mode: tile.config.resolvedTileMode,
            presentation: tile.config.resolvedPresentationMode,
            sort: tile.config.resolvedSortMode,
            maxDepth: tile.config.resolvedMaxDepth,
            gridColumns: tile.config.resolvedGridColumns,
            showLabels: tile.config.resolvedShowLabels,
            iconConfig: tile.config.iconConfig ?? IconConfiguration(),
            customOrder: tile.config.customOrder,
            runtimeURL: runtimeURL
        )
    }

    public func migrateLegacyTile(_ tile: DockTile, runtimeURL: URL) throws -> DockTile {
        guard tile.config.isLegacyLauncher else { return tile }
        let legacyURL = URL(fileURLWithPath: tile.config.targetPath)
        
        // 1. Transactionally migrate into a temporary managed collection
        let (cid, targetDir, _) = try LauncherCollectionService.migrateLegacyToManaged(legacyURL: legacyURL)

        do {
            // 2. Generate and update tile with new collection
            let migratedTile = try updateTile(
                existingTile: tile,
                newName: tile.name,
                targetPath: targetDir.path,
                mode: .launcher,
                presentation: tile.config.resolvedPresentationMode,
                sort: tile.config.resolvedSortMode,
                maxDepth: tile.config.resolvedMaxDepth,
                gridColumns: tile.config.resolvedGridColumns,
                showLabels: tile.config.resolvedShowLabels,
                iconConfig: tile.config.iconConfig ?? IconConfiguration(),
                customOrder: tile.config.customOrder,
                runtimeURL: runtimeURL,
                newCollectionID: cid
            )
            return migratedTile
        } catch {
            // 3. Rollback managed collection on failure without mutating tile or original directory
            try? LauncherCollectionService.deleteManagedCollection(collectionID: cid)
            throw error
        }
    }

    public func deleteTile(_ tile: DockTile, deleteCollection: Bool = false) {
        if tile.isDockPinned {
            _ = DockService.removeFromDock(appPath: tile.appPath)
        }

        try? FileManager.default.removeItem(atPath: tile.appPath)

        if deleteCollection, let cid = tile.config.collectionID {
            try? LauncherCollectionService.deleteManagedCollection(collectionID: cid)
        }

        DispatchQueue.main.async {
            self.tiles.removeAll { $0.id == tile.id }
        }
    }

    @discardableResult
    public func toggleDockPin(for tile: DockTile) -> Bool {
        if tile.isDockPinned {
            if DockService.removeFromDock(appPath: tile.appPath) {
                tile.isDockPinned = false
                return true
            } else {
                self.lastWarningMessage = "Could not remove tile from Dock."
                return false
            }
        } else {
            if DockService.addToDock(appPath: tile.appPath) && DockService.isTileInDock(appPath: tile.appPath) {
                tile.isDockPinned = true
                return true
            } else {
                self.lastWarningMessage = "Could not add tile to Dock."
                return false
            }
        }
    }
}
