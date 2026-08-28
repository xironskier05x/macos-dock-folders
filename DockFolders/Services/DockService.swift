import Foundation

public struct DockService {
    private static func canonicalAppPath(_ path: String) -> String {
        return URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private static func extractCanonicalPath(from tileData: [String: Any]) -> String? {
        guard let fileData = tileData["file-data"] as? [String: Any],
              let urlStr = fileData["_CFURLString"] as? String else {
            return nil
        }
        if let url = URL(string: urlStr) {
            return url.standardizedFileURL.path
        }
        return URL(fileURLWithPath: urlStr).standardizedFileURL.path
    }

    public static func isTileInDock(appPath: String) -> Bool {
        let canonical = canonicalAppPath(appPath)
        if let dockApps = UserDefaults(suiteName: "com.apple.dock")?.array(forKey: "persistent-apps") as? [[String: Any]] {
            for item in dockApps {
                if let tileData = item["tile-data"] as? [String: Any],
                   let path = extractCanonicalPath(from: tileData) {
                    if path == canonical {
                        return true
                    }
                }
            }
        }
        return false
    }

    public static func addToDock(appPath: String) -> Bool {
        let canonical = canonicalAppPath(appPath)
        if isTileInDock(appPath: canonical) {
            return true
        }

        let escaped = FileHelpers.escapeXML(canonical)
        let tileData = "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>\(escaped)</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
        
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        p.arguments = ["write", "com.apple.dock", "persistent-apps", "-array-add", tileData]
        try? p.run()
        p.waitUntilExit()

        restartDock()
        return isTileInDock(appPath: canonical)
    }

    public static func removeFromDock(appPath: String) -> Bool {
        let canonical = canonicalAppPath(appPath)
        guard let userDefaults = UserDefaults(suiteName: "com.apple.dock"),
              var dockApps = userDefaults.array(forKey: "persistent-apps") as? [[String: Any]] else {
            return false
        }

        let originalCount = dockApps.count
        dockApps.removeAll { item in
            if let tileData = item["tile-data"] as? [String: Any],
               let path = extractCanonicalPath(from: tileData) {
                return path == canonical
            }
            return false
        }

        if dockApps.count != originalCount {
            userDefaults.set(dockApps, forKey: "persistent-apps")
            userDefaults.synchronize()
            restartDock()
            return true
        }
        return false
    }

    public static func updateDockPath(oldPath: String, newPath: String) -> Bool {
        let oldCanonical = canonicalAppPath(oldPath)
        let newCanonical = canonicalAppPath(newPath)
        if oldCanonical == newCanonical { return true }

        if isTileInDock(appPath: oldCanonical) {
            _ = removeFromDock(appPath: oldCanonical)
            return addToDock(appPath: newCanonical)
        }
        return false
    }

    public static func restartDock() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        p.arguments = ["Dock"]
        try? p.run()
        p.waitUntilExit()
    }
}
