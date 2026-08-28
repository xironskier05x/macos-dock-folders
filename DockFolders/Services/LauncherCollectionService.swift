import Foundation

public struct LauncherCollectionService {
    public static var collectionsBaseURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("macOS Dock Folders").appendingPathComponent("Collections")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public static func collectionDirectory(for tileID: String) -> URL {
        let dir = collectionsBaseURL.appendingPathComponent(tileID)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public static func addItem(sourceURL: URL, to tileID: String) -> (success: Bool, finalURL: URL?) {
        let collectionDir = collectionDirectory(for: tileID)
        let fm = FileManager.default

        let destURL = collectionDir.appendingPathComponent(sourceURL.lastPathComponent)
        var finalDestURL = destURL
        var counter = 1
        let baseName = destURL.deletingPathExtension().lastPathComponent
        let ext = destURL.pathExtension

        while fm.fileExists(atPath: finalDestURL.path) {
            let newName = ext.isEmpty ? "\(baseName) \(counter)" : "\(baseName) \(counter).\(ext)"
            finalDestURL = collectionDir.appendingPathComponent(newName)
            counter += 1
        }

        do {
            try fm.createSymbolicLink(at: finalDestURL, withDestinationURL: sourceURL)
            return (true, finalDestURL)
        } catch {
            return (false, nil)
        }
    }

    public static func removeItem(at itemURL: URL) -> Bool {
        // Safe remove: only deletes the symlink inside the collection directory
        guard itemURL.path.contains("macOS Dock Folders/Collections") else { return false }
        do {
            try FileManager.default.removeItem(at: itemURL)
            return true
        } catch {
            return false
        }
    }

    public static func fetchItems(for tileID: String, customOrder: [String]? = nil) -> [LauncherItem] {
        let collectionDir = collectionDirectory(for: tileID)
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: collectionDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }

        var items: [LauncherItem] = contents.map { url in
            let info = FileHelpers.inspectItem(at: url)
            return LauncherItem(
                id: url.lastPathComponent,
                name: info.displayName,
                path: url.path,
                resolvedPath: info.resolvedURL.path,
                isDirectory: info.isDir,
                isPackage: info.isPkg,
                isApp: info.isApp,
                isBroken: info.isBroken,
                icon: info.icon
            )
        }

        if let order = customOrder, !order.isEmpty {
            let orderDict = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
            items.sort {
                let idx1 = orderDict[$0.name] ?? orderDict[$0.id] ?? 9999
                let idx2 = orderDict[$1.name] ?? orderDict[$1.id] ?? 9999
                if idx1 != idx2 { return idx1 < idx2 }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        } else {
            items.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        return items
    }
}
