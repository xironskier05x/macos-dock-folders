// DockFolderRuntime — Universal native launcher engine for macOS Dock Folders
import Cocoa
import UniformTypeIdentifiers

struct TileConfig: Codable {
    var targetPath: String
    var targetBookmarkBase64: String?
    var displayName: String
    var sortMode: String       // "name", "recent", "kind"
    var maxDepth: Int          // e.g. 3
    var tileMode: String       // "folder" or "launcher"
}

struct ItemMetadata {
    let url: URL
    let resolvedURL: URL
    let displayName: String
    let isDirectory: Bool
    let isPackage: Bool
    let isApp: Bool
    let modDate: Date
    let icon: NSImage
}

class SubmenuLoader: NSObject, NSMenuDelegate {
    let folderURL: URL
    let depth: Int
    let maxDepth: Int
    let sortMode: String
    let actionTarget: AppDelegate
    var isLoaded = false

    init(folderURL: URL, depth: Int, maxDepth: Int, sortMode: String, actionTarget: AppDelegate) {
        self.folderURL = folderURL
        self.depth = depth
        self.maxDepth = maxDepth
        self.sortMode = sortMode
        self.actionTarget = actionTarget
        super.init()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if isLoaded { return }
        isLoaded = true
        menu.removeAllItems()
        actionTarget.populateMenu(menu, for: folderURL, depth: depth, maxDepth: maxDepth, sortMode: sortMode)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var config: TileConfig!
    var resolvedTargetURL: URL?
    var submenuHolders: [SubmenuLoader] = []
    var menuOpened = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadConfig()
        DispatchQueue.main.async {
            if !self.menuOpened {
                self.showRootMenu()
            }
        }
    }

    func loadConfig() {
        guard let configURL = Bundle.main.url(forResource: "config", withExtension: "json"),
              let data = try? Data(contentsOf: configURL),
              let decoded = try? JSONDecoder().decode(TileConfig.self, from: data) else {
            NSLog("Failed to load config.json from bundle")
            config = TileConfig(targetPath: NSHomeDirectory(), targetBookmarkBase64: nil, displayName: "Folder", sortMode: "name", maxDepth: 3, tileMode: "folder")
            resolvedTargetURL = URL(fileURLWithPath: NSHomeDirectory())
            return
        }
        self.config = decoded
        self.resolvedTargetURL = resolveTarget()
    }

    func resolveTarget() -> URL {
        if let b64 = config.targetBookmarkBase64, let bookmarkData = Data(base64Encoded: b64) {
            var isStale = false
            if let resolved = try? URL(resolvingBookmarkData: bookmarkData, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &isStale),
               FileManager.default.fileExists(atPath: resolved.path) {
                return resolved
            }
        }
        let fallback = URL(fileURLWithPath: config.targetPath)
        if FileManager.default.fileExists(atPath: fallback.path) {
            return fallback
        }
        return promptRelocate(fallback)
    }

    func promptRelocate(_ fallback: URL) -> URL {
        let alert = NSAlert()
        alert.messageText = "Folder couldn't be found"
        alert.informativeText = "The target folder \"\(config.displayName)\" could not be located at:\n\(fallback.path)\n\nWould you like to locate it?"
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
                return selected
            }
        }
        return fallback
    }

    func application(_ app: NSApplication, openFiles filenames: [String]) {
        self.menuOpened = true
        loadConfig()
        guard let targetURL = self.resolvedTargetURL else {
            NSApp.reply(toOpenOrPrint: .failure)
            NSApp.terminate(nil)
            return
        }

        let fm = FileManager.default
        var successCount = 0
        var failureCount = 0

        for file in filenames {
            let sourceURL = URL(fileURLWithPath: file)
            // Prevent copying parent into child or identical path
            if targetURL.path.hasPrefix(sourceURL.path + "/") || targetURL.path == sourceURL.path {
                failureCount += 1
                continue
            }

            if config.tileMode == "launcher" && sourceURL.pathExtension.lowercased() == "app" {
                let linkURL = targetURL.appendingPathComponent(sourceURL.lastPathComponent)
                do {
                    if !fm.fileExists(atPath: linkURL.path) {
                        try fm.createSymbolicLink(at: linkURL, withDestinationURL: sourceURL)
                    }
                    successCount += 1
                } catch {
                    failureCount += 1
                }
            } else {
                let destURL = targetURL.appendingPathComponent(sourceURL.lastPathComponent)
                do {
                    var finalDestURL = destURL
                    var counter = 1
                    let baseName = destURL.deletingPathExtension().lastPathComponent
                    let ext = destURL.pathExtension
                    while fm.fileExists(atPath: finalDestURL.path) {
                        let newName = ext.isEmpty ? "\(baseName) \(counter)" : "\(baseName) \(counter).\(ext)"
                        finalDestURL = targetURL.appendingPathComponent(newName)
                        counter += 1
                    }
                    try fm.copyItem(at: sourceURL, to: finalDestURL)
                    successCount += 1
                } catch {
                    failureCount += 1
                }
            }
        }

        NSApp.reply(toOpenOrPrint: failureCount == 0 ? .success : .failure)
        NSApp.terminate(nil)
    }

    func calculatePopupPoint() -> NSPoint {
        let mouseLoc = NSEvent.mouseLocation
        let screens = NSScreen.screens
        let currentScreen = screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? (screens.isEmpty ? nil : screens[0])
        let screenFrame = currentScreen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let dockOrientation = (UserDefaults(suiteName: "com.apple.dock")?.string(forKey: "orientation") ?? "bottom").lowercased()

        var popupX = mouseLoc.x
        var popupY = mouseLoc.y

        switch dockOrientation {
        case "left":
            popupX = screenFrame.minX + 50
            popupY = mouseLoc.y
        case "right":
            popupX = screenFrame.maxX - 50
            popupY = mouseLoc.y
        case "bottom":
            popupX = mouseLoc.x
            popupY = screenFrame.minY + 50
        default:
            popupY = screenFrame.minY + 50
        }

        return NSPoint(x: popupX, y: popupY)
    }

    func fetchItems(in folderURL: URL) -> [ItemMetadata] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .isApplicationKey, .isAliasFileKey, .contentModificationDateKey]
        guard let contents = try? fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            return []
        }

        var items: [ItemMetadata] = []
        for url in contents {
            // Resolve alias if needed
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

            let icon = NSWorkspace.shared.icon(forFile: resolved.path)
            icon.size = NSSize(width: 18, height: 18)

            items.append(ItemMetadata(
                url: url,
                resolvedURL: resolved,
                displayName: displayName,
                isDirectory: isDir,
                isPackage: isPkg,
                isApp: isApp,
                modDate: modDate,
                icon: icon
            ))
        }

        return sortMetadata(items, mode: config.sortMode)
    }

    func sortMetadata(_ items: [ItemMetadata], mode: String) -> [ItemMetadata] {
        switch mode.lowercased() {
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

    func populateMenu(_ menu: NSMenu, for folderURL: URL, depth: Int, maxDepth: Int, sortMode: String) {
        let items = fetchItems(in: folderURL)
        var keyIndex = 1

        for item in items {
            let keyEq = (depth == 0 && keyIndex <= 9) ? "\(keyIndex)" : ""
            let menuItem = NSMenuItem(title: item.displayName, action: #selector(itemClicked(_:)), keyEquivalent: keyEq)
            if depth == 0 && keyIndex <= 9 {
                menuItem.keyEquivalentModifierMask = [.command]
                keyIndex += 1
            }
            menuItem.target = self
            menuItem.image = item.icon
            menuItem.representedObject = item.resolvedURL.path

            // Submenu rule: true directory, not a package, not an app, within depth limit
            if item.isDirectory && !item.isPackage && !item.isApp && depth < maxDepth {
                let submenu = NSMenu(title: item.displayName)
                submenu.minimumWidth = 220
                submenu.autoenablesItems = false

                // Attach lazy submenu loader
                let loader = SubmenuLoader(folderURL: item.resolvedURL, depth: depth + 1, maxDepth: maxDepth, sortMode: sortMode, actionTarget: self)
                submenu.delegate = loader
                submenuHolders.append(loader)

                // Placeholder item
                let placeholder = NSMenuItem(title: "Loading…", action: nil, keyEquivalent: "")
                placeholder.isEnabled = false
                submenu.addItem(placeholder)

                menuItem.submenu = submenu
                menuItem.action = nil
            }

            menu.addItem(menuItem)

            // Alternate Option item: Reveal in Finder
            if !item.isDirectory || item.isPackage || item.isApp || depth >= maxDepth {
                let altItem = NSMenuItem(title: "Reveal in Finder: \(item.displayName)", action: #selector(revealInFinder(_:)), keyEquivalent: keyEq)
                altItem.keyEquivalentModifierMask = keyEq.isEmpty ? [.option] : [.option, .command]
                altItem.isAlternate = true
                altItem.image = item.icon
                altItem.target = self
                altItem.representedObject = item.resolvedURL.path
                menu.addItem(altItem)
            }
        }

        if items.isEmpty {
            let emptyItem = NSMenuItem(title: "(Folder is empty)", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        }
    }

    func showRootMenu() {
        self.menuOpened = true
        guard let targetURL = self.resolvedTargetURL else {
            NSApp.terminate(nil)
            return
        }

        let rootMenu = NSMenu(title: config.displayName)
        rootMenu.minimumWidth = 240
        rootMenu.autoenablesItems = false

        // Header
        let headerItem = NSMenuItem(title: config.displayName, action: nil, keyEquivalent: "")
        let headerFont = NSFont.boldSystemFont(ofSize: 13)
        headerItem.attributedTitle = NSAttributedString(string: config.displayName, attributes: [.font: headerFont])
        headerItem.isEnabled = false
        rootMenu.addItem(headerItem)
        rootMenu.addItem(NSMenuItem.separator())

        // Top level items (instant)
        populateMenu(rootMenu, for: targetURL, depth: 0, maxDepth: config.maxDepth, sortMode: config.sortMode)

        // Footer
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

    @objc func openFolderInTerminal() {
        guard let targetURL = self.resolvedTargetURL else { return }
        let termURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        NSWorkspace.shared.open([targetURL], withApplicationAt: termURL, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
