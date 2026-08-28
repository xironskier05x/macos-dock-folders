import Foundation
import AppKit

public struct TileGeneratorService {
    public static func generateTile(
        name: String,
        targetPath: String,
        tileMode: TileMode,
        presentationMode: PresentationMode,
        sortMode: SortMode,
        maxDepth: Int,
        gridColumns: Int,
        showLabels: Bool,
        iconConfig: IconConfiguration,
        customOrder: [String]?,
        outputDirectory: URL = TileDiscoveryService.defaultOutputDirectory,
        runtimeURL: URL
    ) throws -> String {
        let fm = FileManager.default
        try fm.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let appName = "\(name).app"
        let appPath = outputDirectory.appendingPathComponent(appName).path
        let bundleID = FileHelpers.bundleIdentifier(for: targetPath)

        // Clear stale repair state
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let repairFile = appSupport.appendingPathComponent("macOS Dock Folders/\(bundleID)/repaired_state.json")
        try? fm.removeItem(at: repairFile)

        // Transactional Staging Directory
        let stagingBase = outputDirectory.appendingPathComponent(".staging_\(UUID().uuidString)")
        let stagingApp = stagingBase.appendingPathComponent(appName)
        let macosDir = stagingApp.appendingPathComponent("Contents/MacOS")
        let resDir = stagingApp.appendingPathComponent("Contents/Resources")

        try fm.createDirectory(at: macosDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: resDir, withIntermediateDirectories: true)

        // 1. Copy universal runtime binary
        let destRuntime = macosDir.appendingPathComponent("DockFolderRuntime")
        try fm.copyItem(at: runtimeURL, to: destRuntime)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destRuntime.path)

        // 2. Generate Base64 URL Bookmark
        let bookmarkB64 = BookmarkService.createBookmarkBase64(for: targetPath)

        // 3. Write config.json
        let cfg = DockTileConfig(
            targetPath: targetPath,
            targetBookmarkBase64: bookmarkB64,
            displayName: name,
            sortMode: sortMode.rawValue,
            maxDepth: maxDepth,
            tileMode: tileMode.rawValue,
            presentation: presentationMode.rawValue,
            gridColumns: gridColumns,
            showLabels: showLabels,
            customOrder: customOrder,
            iconConfig: iconConfig
        )
        let configData = try JSONEncoder().encode(cfg)
        try configData.write(to: resDir.appendingPathComponent("config.json"))

        // 4. Generate applet.icns
        let icnsDest = resDir.appendingPathComponent("applet.icns")
        _ = IconRendererService.generateIcns(config: iconConfig, folderPath: targetPath, destinationPath: icnsDest.path)

        // 5. Write Info.plist
        let escapedTitle = FileHelpers.escapeXML(name)
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleExecutable</key>
            <string>DockFolderRuntime</string>
            <key>CFBundleIdentifier</key>
            <string>\(bundleID)</string>
            <key>CFBundleName</key>
            <string>\(escapedTitle)</string>
            <key>CFBundleDisplayName</key>
            <string>\(escapedTitle)</string>
            <key>CFBundleIconFile</key>
            <string>applet.icns</string>
            <key>CFBundlePackageType</key>
            <string>APPL</string>
            <key>CFBundleShortVersionString</key>
            <string>3.0</string>
            <key>DockFoldersGenerated</key>
            <true/>
            <key>LSUIElement</key>
            <true/>
            <key>NSHighResolutionCapable</key>
            <true/>
            <key>CFBundleDocumentTypes</key>
            <array>
                <dict>
                    <key>CFBundleTypeName</key>
                    <string>All Files</string>
                    <key>CFBundleTypeRole</key>
                    <string>Viewer</string>
                    <key>LSHandlerRank</key>
                    <string>None</string>
                    <key>LSItemContentTypes</key>
                    <array>
                        <string>public.item</string>
                        <string>public.content</string>
                        <string>public.data</string>
                    </array>
                </dict>
            </array>
        </dict>
        </plist>
        """
        try plistContent.write(to: stagingApp.appendingPathComponent("Contents/Info.plist"), atomically: true, encoding: .utf8)

        // 6. Ad-hoc codesign and validation
        let pSign = Process()
        pSign.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        pSign.arguments = ["--force", "--sign", "-", stagingApp.path]
        try? pSign.run()
        pSign.waitUntilExit()

        // 7. Transactional install with backup & rollback
        let backupPath = outputDirectory.appendingPathComponent(".backup_\(appName)_\(UUID().uuidString)").path
        if fm.fileExists(atPath: appPath) {
            try fm.moveItem(atPath: appPath, toPath: backupPath)
        }

        do {
            try fm.moveItem(at: stagingApp, to: URL(fileURLWithPath: appPath))
            try? fm.removeItem(atPath: backupPath)
            try? fm.removeItem(at: stagingBase)
            return appPath
        } catch {
            if fm.fileExists(atPath: backupPath) {
                try? fm.moveItem(atPath: backupPath, toPath: appPath)
            }
            try? fm.removeItem(at: stagingBase)
            throw error
        }
    }
}
