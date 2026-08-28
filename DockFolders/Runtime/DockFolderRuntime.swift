// DockFolderRuntime 3.0 — Universal native launcher engine for macOS Dock Folders
import Cocoa
import UniformTypeIdentifiers
import SwiftUI

struct RuntimeTileConfig: Codable {
    var targetPath: String
    var targetBookmarkBase64: String?
    var displayName: String
    var sortMode: String?       // "name", "recent", "kind", "custom"
    var maxDepth: Int?          // e.g. 3
    var tileMode: String?       // "folder" or "launcher"
    var presentation: String?   // "menu" or "grid"
    var gridColumns: Int?       // 4..7 (default: 5)
    var showLabels: Bool?       // default: true
    var customOrder: [String]?  // custom item names / order
}

struct RepairedState: Codable {
    var targetPath: String
    var targetBookmarkBase64: String?
}

struct RawItem {
    let url: URL
    let resolvedURL: URL
    let displayName: String
    let isDirectory: Bool
    let isPackage: Bool
    let isApp: Bool
    let modDate: Date
}

class SubmenuLoader: NSObject, NSMenuDelegate {
    let folderURL: URL
    let depth: Int
    let maxDepth: Int
    let sortMode: String
    let customOrder: [String]?
    let actionTarget: RuntimeAppDelegate
    var isLoaded = false

    init(folderURL: URL, depth: Int, maxDepth: Int, sortMode: String, customOrder: [String]?, actionTarget: RuntimeAppDelegate) {
        self.folderURL = folderURL
        self.depth = depth
        self.maxDepth = maxDepth
        self.sortMode = sortMode
        self.customOrder = customOrder
        self.actionTarget = actionTarget
        super.init()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if isLoaded { return }
        isLoaded = true
        menu.removeAllItems()
        actionTarget.populateMenu(menu, for: folderURL, depth: depth, maxDepth: maxDepth, sortMode: sortMode, customOrder: customOrder)
    }
}

class RuntimeAppDelegate: NSObject, NSApplicationDelegate {
    var config: RuntimeTileConfig?
    var resolvedTargetURL: URL?
    var submenuHolders: [SubmenuLoader] = []
    var gridWindow: GridLauncherWindow?
    var menuOpened = false
    let maxItemsPerLevel = 100

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !loadConfig() || resolvedTargetURL == nil {
            failDamagedConfig()
            return
        }

        DispatchQueue.main.async {
            if !self.menuOpened {
                let presentation = (self.config?.presentation ?? "menu").lowercased()
                if presentation == "grid" {
                    self.showGridLauncher()
                } else {
                    self.showRootMenu()
                }
            }
        }
    }

    var appSupportStateURL: URL? {
        guard let bundleID = Bundle.main.bundleIdentifier else { return nil }
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = appSupport.appendingPathComponent("macOS Dock Folders").appendingPathComponent(bundleID)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        return dir.appendingPathComponent("repaired_state.json")
    }

    func loadConfig() -> Bool {
        guard let bundleConfigURL = Bundle.main.url(forResource: "config", withExtension: "json"),
              let data = try? Data(contentsOf: bundleConfigURL),
              var bundleConfig = try? JSONDecoder().decode(RuntimeTileConfig.self, from: data) else {
            return false // Fail closed!
        }

        if let stateURL = appSupportStateURL,
           let stateData = try? Data(contentsOf: stateURL),
           let state = try? JSONDecoder().decode(RepairedState.self, from: stateData) {
            bundleConfig.targetPath = state.targetPath
            bundleConfig.targetBookmarkBase64 = state.targetBookmarkBase64
        }

        self.config = bundleConfig
        self.resolvedTargetURL = resolveTarget(from: bundleConfig)
        return true
    }

    func persistRepairedState(targetURL: URL) {
        guard var currentConfig = self.config else { return }
        currentConfig.targetPath = targetURL.path
        var b64: String? = nil
        if let bookmarkData = try? targetURL.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil) {
            b64 = bookmarkData.base64EncodedString()
            currentConfig.targetBookmarkBase64 = b64
        }
        self.config = currentConfig

        if let stateURL = appSupportStateURL {
            let state = RepairedState(targetPath: targetURL.path, targetBookmarkBase64: b64)
            if let encoded = try? JSONEncoder().encode(state) {
                try? encoded.write(to: stateURL)
            }
        }
    }

    func failDamagedConfig() {
        fputs("Error: Dock Folder configuration is damaged or target folder is unavailable.\n", stderr)
        if CommandLine.arguments.contains("--test") || ProcessInfo.processInfo.environment["CI"] != nil {
            exit(1)
        }
        let alert = NSAlert()
        alert.messageText = "Dock Folder Target Unavailable"
        alert.informativeText = "The target folder for this Dock launcher could not be found or its configuration is damaged.\nPlease re-run dock-folders or Dock Folders Manager to regenerate it."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
        exit(1)
    }

    func resolveTarget(from cfg: RuntimeTileConfig) -> URL? {
        if let b64 = cfg.targetBookmarkBase64, let bookmarkData = Data(base64Encoded: b64) {
            var isStale = false
            if let resolved = try? URL(resolvingBookmarkData: bookmarkData, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &isStale),
               FileManager.default.fileExists(atPath: resolved.path) {
                if isStale {
                    persistRepairedState(targetURL: resolved)
                }
                return resolved
            }
        }
        let fallback = URL(fileURLWithPath: cfg.targetPath)
        if FileManager.default.fileExists(atPath: fallback.path) {
            return fallback
        }
        return promptRelocate(fallback)
    }

    func promptRelocate(_ fallback: URL) -> URL? {
        guard let cfg = self.config else { return nil }
        if CommandLine.arguments.contains("--test") || ProcessInfo.processInfo.environment["CI"] != nil {
            return nil
        }
        let alert = NSAlert()
        alert.messageText = "Folder Couldn't Be Found"
        alert.informativeText = "The target folder \"\(cfg.displayName)\" could not be located at:\n\(fallback.path)\n\nWould you like to locate it?"
        alert.addButton(withTitle: "Locate Folder…")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = "Select Folder"
            if panel.runModal() == .OK, let selected = panel.url {
                persistRepairedState(targetURL: selected)
                return selected
            }
        }
        return nil
    }

    func application(_ app: NSApplication, openFiles filenames: [String]) {
        self.menuOpened = true
        if !loadConfig() {
            NSApp.reply(toOpenOrPrint: .failure)
            NSApp.terminate(nil)
            return
        }
        guard let targetURL = self.resolvedTargetURL, let cfg = self.config else {
            NSApp.reply(toOpenOrPrint: .failure)
            NSApp.terminate(nil)
            return
        }

        let fm = FileManager.default
        var successCount = 0
        var failureCount = 0

        for file in filenames {
            let sourceURL = URL(fileURLWithPath: file)
            if targetURL.path.hasPrefix(sourceURL.path + "/") || targetURL.path == sourceURL.path {
                failureCount += 1
                continue
            }

            let destURL = targetURL.appendingPathComponent(sourceURL.lastPathComponent)
            var finalDestURL = destURL
            var counter = 1
            let baseName = destURL.deletingPathExtension().lastPathComponent
            let ext = destURL.pathExtension
            while fm.fileExists(atPath: finalDestURL.path) {
                let newName = ext.isEmpty ? "\(baseName) \(counter)" : "\(baseName) \(counter).\(ext)"
                finalDestURL = targetURL.appendingPathComponent(newName)
                counter += 1
            }

            let tileMode = cfg.tileMode ?? "folder"
            if tileMode == "launcher" {
                do {
                    try fm.createSymbolicLink(at: finalDestURL, withDestinationURL: sourceURL)
                    successCount += 1
                } catch {
                    failureCount += 1
                }
            } else {
                do {
                    try fm.copyItem(at: sourceURL, to: finalDestURL)
                    successCount += 1
                } catch {
                    failureCount += 1
                }
            }
        }

        NSApp.reply(toOpenOrPrint: failureCount == 0 && successCount > 0 ? .success : .failure)
        NSApp.terminate(nil)
    }

    func calculatePopupPoint() -> NSPoint {
        let mouseLoc = NSEvent.mouseLocation
        let screens = NSScreen.screens
        let currentScreen = screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? (screens.isEmpty ? nil : screens[0])
        guard let screen = currentScreen else {
            return NSPoint(x: mouseLoc.x, y: 50)
        }

        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        let dockOrientation = (UserDefaults(suiteName: "com.apple.dock")?.string(forKey: "orientation") ?? "bottom").lowercased()

        var popupX = mouseLoc.x
        var popupY = mouseLoc.y

        switch dockOrientation {
        case "left":
            popupX = max(visibleFrame.minX + 6, screenFrame.minX + 45)
            popupY = max(visibleFrame.minY + 20, min(mouseLoc.y, visibleFrame.maxY - 20))
        case "right":
            popupX = min(visibleFrame.maxX - 6, screenFrame.maxX - 45)
            popupY = max(visibleFrame.minY + 20, min(mouseLoc.y, visibleFrame.maxY - 20))
        case "bottom":
            popupX = max(visibleFrame.minX + 20, min(mouseLoc.x, visibleFrame.maxX - 20))
            popupY = max(visibleFrame.minY + 6, screenFrame.minY + 45)
        default:
            popupX = mouseLoc.x
            popupY = visibleFrame.minY + 6
        }

        return NSPoint(x: popupX, y: popupY)
    }

    func fetchRawItems(in folderURL: URL, sortMode: String, customOrder: [String]?) -> [RawItem] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .isApplicationKey, .isAliasFileKey, .contentModificationDateKey]
        guard let contents = try? fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            return []
        }

        var items: [RawItem] = []
        for url in contents {
            var resolved = url
            let values = try? url.resourceValues(forKeys: Set(keys))
            if values?.isAliasFile == true {
                if let target = (try? URL(resolvingAliasFileAt: url, options: [.withoutUI, .withoutMounting])) {
                    resolved = target
                }
            }

            let resolvedValues = try? resolved.resourceValues(forKeys: Set(keys))
            let isDir = resolvedValues?.isDirectory ?? false
            let isPkg = resolvedValues?.isPackage ?? false
            let isApp = resolved.pathExtension.lowercased() == "app" || (resolvedValues?.isApplication ?? false)
            let modDate = resolvedValues?.contentModificationDate ?? Date.distantPast

            var displayName = url.deletingPathExtension().lastPathComponent
            if !isApp && !url.pathExtension.isEmpty {
                displayName = url.lastPathComponent
            }

            items.append(RawItem(
                url: url,
                resolvedURL: resolved,
                displayName: displayName,
                isDirectory: isDir,
                isPackage: isPkg,
                isApp: isApp,
                modDate: modDate
            ))
        }

        return sortRawItems(items, mode: sortMode, customOrder: customOrder)
    }

    func sortRawItems(_ items: [RawItem], mode: String, customOrder: [String]?) -> [RawItem] {
        switch mode.lowercased() {
        case "custom":
            if let order = customOrder, !order.isEmpty {
                let orderDict = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
                return items.sorted {
                    let idx1 = orderDict[$0.displayName] ?? 9999
                    let idx2 = orderDict[$1.displayName] ?? 9999
                    if idx1 != idx2 { return idx1 < idx2 }
                    return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
            }
            return items.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        case "recent", "date", "modified":
            return items.sorted { $0.modDate > $1.modDate }
        case "kind", "type":
            return items.sorted {
                let p1 = $0.isApp ? 0 : ($0.isDirectory && !$0.isPackage ? 1 : 2)
                let p2 = $1.isApp ? 0 : ($1.isDirectory && !$1.isPackage ? 1 : 2)
                if p1 != p2 { return p1 < p2 }
                return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        default:
            return items.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        }
    }

    func populateMenu(_ menu: NSMenu, for folderURL: URL, depth: Int, maxDepth: Int, sortMode: String, customOrder: [String]?) {
        let allRawItems = fetchRawItems(in: folderURL, sortMode: sortMode, customOrder: customOrder)
        let totalCount = allRawItems.count
        let displayedRawItems = (totalCount > maxItemsPerLevel) ? Array(allRawItems.prefix(maxItemsPerLevel)) : allRawItems

        var keyIndex = 1

        for raw in displayedRawItems {
            let icon = NSWorkspace.shared.icon(forFile: raw.resolvedURL.path)
            icon.size = NSSize(width: 18, height: 18)

            let keyEq = (depth == 0 && keyIndex <= 9) ? "\(keyIndex)" : ""
            let menuItem = NSMenuItem(title: raw.displayName, action: #selector(itemClicked(_:)), keyEquivalent: keyEq)
            if depth == 0 && keyIndex <= 9 {
                menuItem.keyEquivalentModifierMask = [.command]
                keyIndex += 1
            }
            menuItem.target = self
            menuItem.image = icon
            menuItem.representedObject = raw.resolvedURL.path

            if raw.isDirectory && !raw.isPackage && !raw.isApp && depth < maxDepth {
                let submenu = NSMenu(title: raw.displayName)
                submenu.minimumWidth = 220
                submenu.autoenablesItems = false

                let loader = SubmenuLoader(folderURL: raw.resolvedURL, depth: depth + 1, maxDepth: maxDepth, sortMode: sortMode, customOrder: nil, actionTarget: self)
                submenu.delegate = loader
                submenuHolders.append(loader)

                let placeholder = NSMenuItem(title: "Loading…", action: nil, keyEquivalent: "")
                placeholder.isEnabled = false
                submenu.addItem(placeholder)

                menuItem.submenu = submenu
                menuItem.action = nil
            }

            menu.addItem(menuItem)

            if !raw.isDirectory || raw.isPackage || raw.isApp || depth >= maxDepth {
                let altItem = NSMenuItem(title: "Reveal in Finder: \(raw.displayName)", action: #selector(revealInFinder(_:)), keyEquivalent: keyEq)
                altItem.keyEquivalentModifierMask = keyEq.isEmpty ? [.option] : [.option, .command]
                altItem.isAlternate = true
                altItem.image = icon
                altItem.target = self
                altItem.representedObject = raw.resolvedURL.path
                menu.addItem(altItem)
            }
        }

        if totalCount > maxItemsPerLevel {
            menu.addItem(NSMenuItem.separator())
            let moreItem = NSMenuItem(title: "Show All in Finder… (\(totalCount) items)", action: #selector(openSpecificFolderInFinder(_:)), keyEquivalent: "")
            moreItem.representedObject = folderURL.path
            moreItem.target = self
            menu.addItem(moreItem)
        }

        if allRawItems.isEmpty {
            let emptyItem = NSMenuItem(title: "(Folder is empty)", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        }
    }

    func showRootMenu() {
        self.menuOpened = true
        guard let cfg = self.config, let targetURL = self.resolvedTargetURL else {
            failDamagedConfig()
            return
        }

        let rootMenu = NSMenu(title: cfg.displayName)
        rootMenu.minimumWidth = 240
        rootMenu.autoenablesItems = false

        let headerItem = NSMenuItem(title: cfg.displayName, action: nil, keyEquivalent: "")
        let headerFont = NSFont.boldSystemFont(ofSize: 13)
        headerItem.attributedTitle = NSAttributedString(string: cfg.displayName, attributes: [.font: headerFont])
        headerItem.isEnabled = false
        rootMenu.addItem(headerItem)
        rootMenu.addItem(NSMenuItem.separator())

        populateMenu(rootMenu, for: targetURL, depth: 0, maxDepth: cfg.maxDepth ?? 3, sortMode: cfg.sortMode ?? "name", customOrder: cfg.customOrder)

        rootMenu.addItem(NSMenuItem.separator())
        let finderItem = NSMenuItem(title: "Show in Finder", action: #selector(openFolderInFinder), keyEquivalent: "o")
        finderItem.keyEquivalentModifierMask = [.command]
        if let finderIcon = NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app") as NSImage? {
            finderIcon.size = NSSize(width: 18, height: 18)
            finderItem.image = finderIcon
        }
        finderItem.target = self
        rootMenu.addItem(finderItem)

        let termItem = NSMenuItem(title: "Open in Terminal", action: #selector(openFolderInTerminal), keyEquivalent: "t")
        termItem.keyEquivalentModifierMask = [.command]
        if let termIcon = NSWorkspace.shared.icon(forFile: "/System/Applications/Utilities/Terminal.app") as NSImage? {
            termIcon.size = NSSize(width: 18, height: 18)
            termItem.image = termIcon
        }
        termItem.target = self
        rootMenu.addItem(termItem)

        let point = calculatePopupPoint()
        rootMenu.popUp(positioning: nil, at: point, in: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.terminate(nil)
        }
    }

    func showGridLauncher() {
        self.menuOpened = true
        guard let cfg = self.config, let targetURL = self.resolvedTargetURL else {
            failDamagedConfig()
            return
        }

        let rawItems = fetchRawItems(in: targetURL, sortMode: cfg.sortMode ?? "name", customOrder: cfg.customOrder)
        let launcherItems: [LauncherItem] = rawItems.map { raw in
            let icon = NSWorkspace.shared.icon(forFile: raw.resolvedURL.path)
            icon.size = NSSize(width: 48, height: 48)
            return LauncherItem(
                id: raw.url.lastPathComponent,
                name: raw.displayName,
                path: raw.url.path,
                resolvedPath: raw.resolvedURL.path,
                isDirectory: raw.isDirectory,
                isPackage: raw.isPackage,
                isApp: raw.isApp,
                isBroken: !FileManager.default.fileExists(atPath: raw.resolvedURL.path),
                icon: icon
            )
        }

        let anchor = calculatePopupPoint()
        let win = GridLauncherWindow(
            title: cfg.displayName,
            targetURL: targetURL,
            items: launcherItems,
            columnsCount: cfg.gridColumns ?? 5,
            showLabels: cfg.showLabels ?? true,
            anchorPoint: anchor
        )
        self.gridWindow = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func itemClicked(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    @objc func revealInFinder(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    @objc func openFolderInFinder() {
        guard let targetURL = self.resolvedTargetURL else { return }
        NSWorkspace.shared.open(targetURL)
    }

    @objc func openSpecificFolderInFinder(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    @objc func openFolderInTerminal() {
        guard let targetURL = self.resolvedTargetURL else { return }
        let termURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        NSWorkspace.shared.open([targetURL], withApplicationAt: termURL, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
    }
}

@main
struct DockFolderRuntimeMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = RuntimeAppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
