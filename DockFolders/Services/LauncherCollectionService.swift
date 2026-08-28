import Foundation

public enum CollectionServiceError: LocalizedError {
    case invalidCollectionID
    case collectionNotFound
    case unmanagedContainmentViolation
    case sourceDirectoryNotFound

    public var errorDescription: String? {
        switch self {
        case .invalidCollectionID: return "Invalid or missing collection identifier."
        case .collectionNotFound: return "Managed collection directory was not found."
        case .unmanagedContainmentViolation: return "Safety check failed: cannot modify or delete items outside the managed Collections directory."
        case .sourceDirectoryNotFound: return "Source directory not found for migration."
        }
    }
}

public struct LauncherCollectionService {
    public static var collectionsBaseURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("macOS Dock Folders").appendingPathComponent("Collections")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.standardizedFileURL
    }

    public static func isManagedCollection(url: URL) -> Bool {
        let canonicalBase = collectionsBaseURL.standardizedFileURL.path
        let canonicalTarget = url.standardizedFileURL.path
        return canonicalTarget.hasPrefix(canonicalBase.hasSuffix("/") ? canonicalBase : canonicalBase + "/")
    }

    public static func collectionURL(for collectionID: String, createIfMissing: Bool = false) -> URL? {
        guard !collectionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let dir = collectionsBaseURL.appendingPathComponent(collectionID).standardizedFileURL
        if createIfMissing {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    public static func createManagedCollection(collectionID: String = UUID().uuidString) throws -> (id: String, url: URL) {
        guard let url = collectionURL(for: collectionID, createIfMissing: true) else {
            throw CollectionServiceError.invalidCollectionID
        }
        return (collectionID, url)
    }

    public static func deleteManagedCollection(collectionID: String) throws {
        guard let url = collectionURL(for: collectionID, createIfMissing: false) else { return }
        guard isManagedCollection(url: url) else {
            throw CollectionServiceError.unmanagedContainmentViolation
        }
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    public static func addItem(sourceURL: URL, to collectionID: String) -> (success: Bool, finalURL: URL?) {
        guard let collectionDir = collectionURL(for: collectionID, createIfMissing: true) else {
            return (false, nil)
        }
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
        let canonicalItem = itemURL.standardizedFileURL
        guard isManagedCollection(url: canonicalItem.deletingLastPathComponent()) else {
            Logger.log("Refusing to delete unmanaged item: \(itemURL.path)", level: .error)
            return false
        }
        do {
            try FileManager.default.removeItem(at: canonicalItem)
            return true
        } catch {
            return false
        }
    }

    public static func fetchItems(for targetURL: URL, customOrder: [String]? = nil) -> [LauncherItem] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: targetURL.path),
              let contents = try? fm.contentsOfDirectory(at: targetURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
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
                let idx1 = orderDict[$0.id] ?? orderDict[$0.name] ?? 9999
                let idx2 = orderDict[$1.id] ?? orderDict[$1.name] ?? 9999
                if idx1 != idx2 { return idx1 < idx2 }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        } else {
            items.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        return items
    }

    public static func migrateLegacyToManaged(legacyURL: URL, newCollectionID: String = UUID().uuidString) throws -> (collectionID: String, collectionURL: URL, migratedCount: Int) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: legacyURL.path) else {
            throw CollectionServiceError.sourceDirectoryNotFound
        }

        let (cid, targetDir) = try createManagedCollection(collectionID: newCollectionID)
        let contents = try fm.contentsOfDirectory(at: legacyURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])

        var count = 0
        for item in contents {
            let resolved = FileHelpers.resolveAliasOrSymlink(at: item)
            let destLink = targetDir.appendingPathComponent(item.lastPathComponent)
            try? fm.createSymbolicLink(at: destLink, withDestinationURL: resolved)
            count += 1
        }

        return (cid, targetDir, count)
    }
}
