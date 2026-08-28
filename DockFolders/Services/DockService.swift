import Foundation

public struct DockService {
    public static func isTileInDock(appPath: String) -> Bool {
        let appBundleName = (appPath as NSString).lastPathComponent
        if let dockApps = UserDefaults(suiteName: "com.apple.dock")?.array(forKey: "persistent-apps") as? [[String: Any]] {
            for item in dockApps {
                if let tileData = item["tile-data"] as? [String: Any],
                   let fileData = tileData["file-data"] as? [String: Any],
                   let urlStr = fileData["_CFURLString"] as? String {
                    if urlStr.contains(appBundleName) || urlStr.contains(appPath) {
                        return true
                    }
                }
            }
        }
        return false
    }

    public static func addToDock(appPath: String) -> Bool {
        if isTileInDock(appPath: appPath) {
            return true
        }

        let escaped = FileHelpers.escapeXML(appPath)
        let tileData = "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>\(escaped)</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
        
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        p.arguments = ["write", "com.apple.dock", "persistent-apps", "-array-add", tileData]
        try? p.run()
        p.waitUntilExit()

        restartDock()
        return isTileInDock(appPath: appPath)
    }

    public static func removeFromDock(appPath: String) -> Bool {
        let appBundleName = (appPath as NSString).lastPathComponent
        guard let userDefaults = UserDefaults(suiteName: "com.apple.dock"),
              var dockApps = userDefaults.array(forKey: "persistent-apps") as? [[String: Any]] else {
            return false
        }

        let originalCount = dockApps.count
        dockApps.removeAll { item in
            if let tileData = item["tile-data"] as? [String: Any],
               let fileData = tileData["file-data"] as? [String: Any],
               let urlStr = fileData["_CFURLString"] as? String {
                return urlStr.contains(appBundleName) || urlStr.contains(appPath)
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

    public static func restartDock() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        p.arguments = ["Dock"]
        try? p.run()
        p.waitUntilExit()
    }
}
