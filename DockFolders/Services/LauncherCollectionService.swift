import Foundation

public enum CollectionServiceError: LocalizedError {
    case invalidCollectionID(String)
    case collectionNotFound
    case unmanagedContainmentViolation
    case sourceDirectoryNotFound
    case migrationItemFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidCollectionID(let reason): return "Invalid collection identifier: \(reason)"
        case .collectionNotFound: return "Managed collection directory was not found."
        case .unmanagedContainmentViolation: return "Safety check failed: cannot modify or delete items outside the managed Collections directory."
        case .sourceDirectoryNotFound: return "Source directory not found for migration."
        case .migrationItemFailed(let msg): return "Migration aborted: \(msg)"
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

    public static func validateCollectionID(_ collectionID: String) throws -> String {
        let trimmed = collectionID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CollectionServiceError.invalidCollectionID("Identifier cannot be empty.")
        }
        guard !trimmed.contains("/"), !trimmed.contains("\\"), !trimmed.contains(".."), !trimmed.contains(":") else {
            throw CollectionServiceError.invalidCollectionID("Identifier contains path traversal or invalid characters.")
        }
        guard UUID(uuidString: trimmed) != nil || trimmed.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else {
            throw CollectionServiceError.invalidCollectionID("Identifier must be a valid UUID or alphanumeric string.")
        }
        return trimmed
    }

    public static func isManagedCollection(url: URL) -> Bool {
        let canonicalBase = collectionsBaseURL.standardizedFileURL.path
        let canonicalTarget = url.standardizedFileURL.path
        return canonicalTarget.hasPrefix(canonicalBase.hasSuffix("/") ? canonicalBase : canonicalBase + "/")
    }

    public static func collectionURL(for collectionID: String, createIfMissing: Bool = false) -> URL? {
        guard let validID = try? validateCollectionID(collectionID) else { return nil }
        let base = collectionsBaseURL.standardizedFileURL
        let dir = base.appendingPathComponent(validID).standardizedFileURL

        guard dir.deletingLastPathComponent().standardizedFileURL == base else {
            return nil
        }

        if createIfMissing {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    public static func createManagedCollection(collectionID: String = UUID().uuidString) throws -> (id: String, url: URL) {
        let validID = try validateCollectionID(collectionID)
        guard let url = collectionURL(for: validID, createIfMissing: true) else {
            throw CollectionServiceError.invalidCollectionID("Could not resolve safe collection directory URL.")
        }
        return (validID, url)
    }

    public static func deleteManagedCollection(collectionID: String) throws {
        let validID = try validateCollectionID(collectionID)
        guard let url = collectionURL(for: validID, createIfMissing: false) else { return }
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
                let idx1 = orderDict[$0.id] ?? orderDict[$0.name] ?? 99999
                let idx2 = orderDict[$1.id] ?? orderDict[$1.name] ?? 99999
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
        let canonicalLegacy = legacyURL.standardizedFileURL
        guard fm.fileExists(atPath: canonicalLegacy.path) else {
            throw CollectionServiceError.sourceDirectoryNotFound
        }

        let validID = try validateCollectionID(newCollectionID)
        let (cid, targetDir) = try createManagedCollection(collectionID: validID)

        do {
            let contents = try fm.contentsOfDirectory(at: canonicalLegacy, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            var count = 0
            for item in contents {
                let resolved = FileHelpers.resolveAliasOrSymlink(at: item)
                guard fm.fileExists(atPath: resolved.path) else {
                    throw CollectionServiceError.migrationItemFailed("Source item at \(item.path) is missing or unresolvable.")
                }
                let destLink = targetDir.appendingPathComponent(item.lastPathComponent)
                try fm.createSymbolicLink(at: destLink, withDestinationURL: resolved)
                guard fm.fileExists(atPath: destLink.path) || (try? destLink.checkResourceIsReachable()) == true else {
                    throw CollectionServiceError.migrationItemFailed("Failed to verify created symlink at \(destLink.path)")
                }
                count += 1
            }

            return (cid, targetDir, count)
        } catch {
            // Clean up temporary collection on failure
            try? deleteManagedCollection(collectionID: cid)
            throw error
        }
    }
}
