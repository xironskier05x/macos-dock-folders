import Foundation
import AppKit

public struct TileDiscoveryService {
    public static var defaultOutputDirectory: URL {
        let appDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Dock Folders")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir
    }

    public static func discoverTiles(in searchDirectory: URL = defaultOutputDirectory) -> [DockTile] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: searchDirectory, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return []
        }

        var tiles: [DockTile] = []

        for url in contents where url.pathExtension.lowercased() == "app" {
            let plistURL = url.appendingPathComponent("Contents/Info.plist")
            let configURL = url.appendingPathComponent("Contents/Resources/config.json")
            let iconURL = url.appendingPathComponent("Contents/Resources/applet.icns")

            guard fm.fileExists(atPath: plistURL.path),
                  let plistData = try? Data(contentsOf: plistURL),
                  let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
                  let isDockFolder = plist["DockFoldersGenerated"] as? Bool, isDockFolder else {
                continue
            }

            var config: DockTileConfig
            if let configData = try? Data(contentsOf: configURL),
               let decoded = try? JSONDecoder().decode(DockTileConfig.self, from: configData) {
                config = decoded
            } else {
                // Backward-compatible fallback
                let targetPath = (plist["CFBundleName"] as? String) ?? url.deletingPathExtension().lastPathComponent
                config = DockTileConfig(targetPath: targetPath, displayName: url.deletingPathExtension().lastPathComponent)
            }

            let name = config.displayName.isEmpty ? url.deletingPathExtension().lastPathComponent : config.displayName
            let iconImage = NSImage(contentsOf: iconURL)
            let isPinned = DockService.isTileInDock(appPath: url.path)
            let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()

            var items: [LauncherItem] = []
            if config.resolvedTileMode == .launcher {
                let tileID = FileHelpers.deterministicHash(for: config.targetPath)
                items = LauncherCollectionService.fetchItems(for: tileID, customOrder: config.customOrder)
            }

            let tile = DockTile(
                id: FileHelpers.deterministicHash(for: url.path),
                name: name,
                appPath: url.path,
                config: config,
                isDockPinned: isPinned,
                iconImage: iconImage,
                items: items,
                lastModified: modDate
            )
            tiles.append(tile)
        }

        return tiles.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
