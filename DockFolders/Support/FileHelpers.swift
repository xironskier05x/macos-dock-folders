import Foundation
import AppKit
import CryptoKit

public struct FileHelpers {
    public static func escapeXML(_ str: String) -> String {
        var res = str
        res = res.replacingOccurrences(of: "&", with: "&amp;")
        res = res.replacingOccurrences(of: "<", with: "&lt;")
        res = res.replacingOccurrences(of: ">", with: "&gt;")
        res = res.replacingOccurrences(of: "\"", with: "&quot;")
        res = res.replacingOccurrences(of: "'", with: "&apos;")
        return res
    }

    public static func deterministicHash(for path: String, length: Int = 12) -> String {
        let data = Data(path.utf8)
        let digest = SHA256.hash(data: data)
        let hashString = digest.map { String(format: "%02x", $0) }.joined()
        return String(hashString.prefix(length))
    }

    public static func bundleIdentifier(for path: String) -> String {
        let hash = deterministicHash(for: path, length: 12)
        return "com.macosdockfolders.tile.\(hash)"
    }

    public static func resolveAliasOrSymlink(at url: URL) -> URL {
        var resolved = url
        let keys: Set<URLResourceKey> = [.isAliasFileKey, .isSymbolicLinkKey]
        if let values = try? url.resourceValues(forKeys: keys) {
            if values.isAliasFile == true {
                if let target = try? URL(resolvingAliasFileAt: url, options: [.withoutUI, .withoutMounting]) {
                    resolved = target
                }
            } else if values.isSymbolicLink == true {
                resolved = url.resolvingSymlinksInPath()
            }
        }
        return resolved
    }

    public static func inspectItem(at url: URL) -> (displayName: String, resolvedURL: URL, isDir: Bool, isPkg: Bool, isApp: Bool, isBroken: Bool, modDate: Date, icon: NSImage) {
        let resolved = resolveAliasOrSymlink(at: url)
        let fm = FileManager.default
        let exists = fm.fileExists(atPath: resolved.path)
        
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isPackageKey, .isApplicationKey, .contentModificationDateKey]
        let values = try? resolved.resourceValues(forKeys: keys)
        let isDir = values?.isDirectory ?? false
        let isPkg = values?.isPackage ?? false
        let isApp = resolved.pathExtension.lowercased() == "app" || (values?.isApplication ?? false)
        let modDate = values?.contentModificationDate ?? Date.distantPast

        var displayName = url.deletingPathExtension().lastPathComponent
        if !isApp && !url.pathExtension.isEmpty {
            displayName = url.lastPathComponent
        }

        let icon = NSWorkspace.shared.icon(forFile: resolved.path)
        icon.size = NSSize(width: 32, height: 32)

        return (displayName, resolved, isDir, isPkg, isApp, !exists, modDate, icon)
    }
}
