import Foundation
import AppKit

public enum TileGenerationError: LocalizedError {
    case invalidTileName(String)
    case outputDirectoryEscape
    case unrelatedAppCollision(String)
    case collisionLimitExceeded(String)
    case iconGenerationFailed
    case plistValidationFailed
    case codeSigningFailed(String)
    case runtimeNotFound
    case installFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidTileName(let reason): return "Invalid tile name: \(reason)"
        case .outputDirectoryEscape: return "Safety violation: Target app path escapes the designated output directory."
        case .unrelatedAppCollision(let path): return "An existing application at '\(path)' was not created by Dock Folders. Overwrite blocked for safety."
        case .collisionLimitExceeded(let name): return "Could not resolve a unique filename for '\(name)' after parent and hash disambiguation."
        case .iconGenerationFailed: return "Failed to render or generate applet.icns iconset."
        case .plistValidationFailed: return "Generated Info.plist failed property list validation."
        case .codeSigningFailed(let msg): return "Ad-hoc code signing or strict validation failed: \(msg)"
        case .runtimeNotFound: return "DockFolderRuntime binary not found."
        case .installFailed(let msg): return "Installation failed: \(msg)"
        }
    }
}

public struct TileGeneratorService {
    public static func resolveSafeAppPath(name: String, targetPath: String, outputDirectory: URL, force: Bool = false) throws -> (appURL: URL, appName: String) {
        let validName = try FileHelpers.validateTileName(name)
        let fm = FileManager.default
        let canonicalOut = outputDirectory.standardizedFileURL

        let targetURL = URL(fileURLWithPath: targetPath).standardizedFileURL
        let parentName = targetURL.deletingLastPathComponent().lastPathComponent
        let shortHash = FileHelpers.deterministicHash(for: targetPath, length: 6)

        // Candidate 1: Name.app
        var candidateName = "\(validName).app"
        var candidateURL = canonicalOut.appendingPathComponent(candidateName).standardizedFileURL

        guard FileHelpers.isChild(childURL: candidateURL, of: canonicalOut) else {
            throw TileGenerationError.outputDirectoryEscape
        }

        func checkCandidate(url: URL) throws -> Bool {
            if !fm.fileExists(atPath: url.path) { return true }
            
            // Check if dock folder
            let plistURL = url.appendingPathComponent("Contents/Info.plist")
            guard fm.fileExists(atPath: plistURL.path),
                  let plistData = try? Data(contentsOf: plistURL),
                  let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
                  let isDockFolder = plist["DockFoldersGenerated"] as? Bool, isDockFolder else {
                if force { return true }
                throw TileGenerationError.unrelatedAppCollision(url.path)
            }

            // Check if matches same target
            let configURL = url.appendingPathComponent("Contents/Resources/config.json")
            if let cfgData = try? Data(contentsOf: configURL),
               let cfg = try? JSONDecoder().decode(DockTileConfig.self, from: cfgData) {
                let existingTarget = URL(fileURLWithPath: cfg.targetPath).standardizedFileURL.path
                if existingTarget == targetURL.path {
                    return true // Same target: safe to update in place
                }
            }
            return false
        }

        if try checkCandidate(url: candidateURL) {
            return (candidateURL, candidateName)
        }

        // Candidate 2: Name (Parent).app
        candidateName = "\(validName) (\(parentName)).app"
        candidateURL = canonicalOut.appendingPathComponent(candidateName).standardizedFileURL
        guard FileHelpers.isChild(childURL: candidateURL, of: canonicalOut) else {
            throw TileGenerationError.outputDirectoryEscape
        }

        if try checkCandidate(url: candidateURL) {
            return (candidateURL, candidateName)
        }

        // Candidate 3: Name [hash].app
        candidateName = "\(validName) [\(shortHash)].app"
        candidateURL = canonicalOut.appendingPathComponent(candidateName).standardizedFileURL
        guard FileHelpers.isChild(childURL: candidateURL, of: canonicalOut) else {
            throw TileGenerationError.outputDirectoryEscape
        }

        if try checkCandidate(url: candidateURL) {
            return (candidateURL, candidateName)
        }

        throw TileGenerationError.collisionLimitExceeded(validName)
    }

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
        collectionID: String? = nil,
        outputDirectory: URL = TileDiscoveryService.defaultOutputDirectory,
        runtimeURL: URL,
        force: Bool = false
    ) throws -> String {
        let fm = FileManager.default
        let canonicalOut = outputDirectory.standardizedFileURL
        try fm.createDirectory(at: canonicalOut, withIntermediateDirectories: true)

        guard fm.fileExists(atPath: runtimeURL.path), fm.isExecutableFile(atPath: runtimeURL.path) else {
            throw TileGenerationError.runtimeNotFound
        }

        let (destinationURL, appName) = try resolveSafeAppPath(name: name, targetPath: targetPath, outputDirectory: canonicalOut, force: force)
        let appPath = destinationURL.path
        let bundleID = FileHelpers.bundleIdentifier(for: targetPath)

        // Clear stale repair state
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let repairFile = appSupport.appendingPathComponent("macOS Dock Folders/\(bundleID)/repaired_state.json")
        try? fm.removeItem(at: repairFile)

        // Transactional Staging Directory inside output directory
        let stagingBase = canonicalOut.appendingPathComponent(".staging_\(UUID().uuidString)")
        let stagingApp = stagingBase.appendingPathComponent(appName)
        let macosDir = stagingApp.appendingPathComponent("Contents/MacOS")
        let resDir = stagingApp.appendingPathComponent("Contents/Resources")

        defer {
            try? fm.removeItem(at: stagingBase)
        }

        try fm.createDirectory(at: macosDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: resDir, withIntermediateDirectories: true)

        // 1. Copy runtime binary
        let destRuntime = macosDir.appendingPathComponent("DockFolderRuntime")
        try fm.copyItem(at: runtimeURL, to: destRuntime)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destRuntime.path)

        // 2. Base64 Bookmark
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
            collectionID: collectionID,
            iconConfig: iconConfig
        )
        let configData = try JSONEncoder().encode(cfg)
        try configData.write(to: resDir.appendingPathComponent("config.json"))

        // 4. Generate applet.icns (Must succeed!)
        let icnsDest = resDir.appendingPathComponent("applet.icns")
        guard IconRendererService.generateIcns(config: iconConfig, folderPath: targetPath, destinationPath: icnsDest.path) else {
            throw TileGenerationError.iconGenerationFailed
        }

        // 5. Generate Info.plist
        let escapedTitle = FileHelpers.escapeXML(name)
        let plistString = """
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
        guard let plistData = plistString.data(using: .utf8),
              (try? PropertyListSerialization.propertyList(from: plistData, format: nil)) != nil else {
            throw TileGenerationError.plistValidationFailed
        }
        let plistURL = stagingApp.appendingPathComponent("Contents/Info.plist")
        try plistData.write(to: plistURL)

        // 6. Ad-hoc codesign and strict verification
        let pSign = Process()
        pSign.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        pSign.arguments = ["--force", "--sign", "-", stagingApp.path]
        try pSign.run()
        pSign.waitUntilExit()
        guard pSign.terminationStatus == 0 else {
            throw TileGenerationError.codeSigningFailed("codesign exited with code \(pSign.terminationStatus)")
        }

        let pVerify = Process()
        pVerify.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        pVerify.arguments = ["--verify", "--strict", stagingApp.path]
        try pVerify.run()
        pVerify.waitUntilExit()
        guard pVerify.terminationStatus == 0 else {
            throw TileGenerationError.codeSigningFailed("strict verification failed")
        }

        // 7. Transactional install with backup & rollback
        let backupPath = canonicalOut.appendingPathComponent(".backup_\(appName)_\(UUID().uuidString)").path
        if fm.fileExists(atPath: appPath) {
            try fm.moveItem(atPath: appPath, toPath: backupPath)
        }

        do {
            try fm.moveItem(at: stagingApp, to: destinationURL)
            try? fm.removeItem(atPath: backupPath)
            return appPath
        } catch {
            if fm.fileExists(atPath: backupPath) {
                try? fm.moveItem(atPath: backupPath, toPath: appPath)
            }
            throw TileGenerationError.installFailed(error.localizedDescription)
        }
    }
}
