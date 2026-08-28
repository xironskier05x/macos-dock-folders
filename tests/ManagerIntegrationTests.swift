import Foundation
import AppKit

// ANSI Colors
let cGreen = "\u{001B}[32m"
let cRed = "\u{001B}[31m"
let cBold = "\u{001B}[1m"
let cReset = "\u{001B}[0m"

var passedCount = 0
var failedCount = 0

func assertTest(_ condition: Bool, _ name: String, file: String = #file, line: Int = #line) {
    if condition {
        print("  \(cGreen)✅ PASS:\(cReset) \(name)")
        passedCount += 1
    } else {
        print("  \(cRed)❌ FAIL:\(cReset) \(name) (line \(line))")
        failedCount += 1
    }
}

func runAllTests() {
    print("\(cBold)🧪 Running Native Manager Integration Tests (Production Services)\(cReset)")
    print("────────────────────────────────────────────────────────────────────────")

    let fm = FileManager.default
    let tempDir = fm.temporaryDirectory.appendingPathComponent("ManagerTests_\(UUID().uuidString)")
    try? fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

    let runtimeURL = URL(fileURLWithPath: "build/DockFolderRuntime").standardizedFileURL
    guard fm.fileExists(atPath: runtimeURL.path) else {
        print("❌ Error: build/DockFolderRuntime not found. Run ./script/build_and_run.sh first.")
        exit(1)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test 1: P0 TileGeneratorService Overwrite Protection (No Force Bypass)
    // ─────────────────────────────────────────────────────────────────────────
    print("\n[Suite 1] Native Generator Overwrite Protection (Foreign App Safety)...")
    do {
        let outDir = tempDir.appendingPathComponent("Apps")
        try fm.createDirectory(at: outDir, withIntermediateDirectories: true)

        let targetDir = tempDir.appendingPathComponent("AI_Source")
        try fm.createDirectory(at: targetDir, withIntermediateDirectories: true)
        try "dummy".write(to: targetDir.appendingPathComponent("dummy.txt"), atomically: true, encoding: .utf8)

        // 1. Create genuine AI Apps.app
        let aiAppPath = try TileGeneratorService.generateTile(
            name: "AI Apps",
            targetPath: targetDir.path,
            tileMode: .launcher,
            presentationMode: .grid,
            sortMode: .custom,
            maxDepth: 3,
            gridColumns: 5,
            showLabels: true,
            iconConfig: IconConfiguration(),
            customOrder: nil,
            collectionID: UUID().uuidString,
            outputDirectory: outDir,
            runtimeURL: runtimeURL
        )
        let aiAppURL = URL(fileURLWithPath: aiAppPath)
        assertTest(fm.fileExists(atPath: aiAppPath), "Generated valid AI Apps.app")

        // 2. Create unrelated foreign Calculator.app fixture
        let calcApp = outDir.appendingPathComponent("Calculator.app")
        let calcContents = calcApp.appendingPathComponent("Contents")
        try fm.createDirectory(at: calcContents, withIntermediateDirectories: true)
        let foreignData = "ORIGINAL_FOREIGN_CALCULATOR_DATA".data(using: .utf8)!
        try foreignData.write(to: calcContents.appendingPathComponent("Info.plist"))

        // 3. Attempt to rename AI Apps -> Calculator with allowedExistingAppURL = aiAppURL
        var renameThrew = false
        var resolvedPath: String = ""
        do {
            resolvedPath = try TileGeneratorService.generateTile(
                name: "Calculator",
                targetPath: targetDir.path,
                tileMode: .launcher,
                presentationMode: .grid,
                sortMode: .custom,
                maxDepth: 3,
                gridColumns: 5,
                showLabels: true,
                iconConfig: IconConfiguration(),
                customOrder: nil,
                collectionID: UUID().uuidString,
                outputDirectory: outDir,
                runtimeURL: runtimeURL,
                allowedExistingAppURL: aiAppURL,
                allowForeignOverwrite: false
            )
        } catch {
            renameThrew = true
        }

        // 4. Assert foreign Calculator.app was NOT overwritten
        let calcPlistData = try? Data(contentsOf: calcContents.appendingPathComponent("Info.plist"))
        let calcUnchanged = (calcPlistData == foreignData)
        assertTest(calcUnchanged, "Foreign Calculator.app byte content was NOT overwritten or corrupted")

        // 5. If disambiguated, it must have chosen a distinct name (e.g. Calculator (AI_Source).app)
        if !renameThrew {
            assertTest(resolvedPath != calcApp.path, "Disambiguated safe name instead of overwriting foreign app")
        } else {
            assertTest(true, "Safely threw collision error rather than overwriting foreign app")
        }

        // 6. Assert AI Apps in-place update succeeds
        let updateSamePath = try TileGeneratorService.generateTile(
            name: "AI Apps",
            targetPath: targetDir.path,
            tileMode: .launcher,
            presentationMode: .grid,
            sortMode: .custom,
            maxDepth: 3,
            gridColumns: 5,
            showLabels: true,
            iconConfig: IconConfiguration(),
            customOrder: nil,
            collectionID: UUID().uuidString,
            outputDirectory: outDir,
            runtimeURL: runtimeURL,
            allowedExistingAppURL: aiAppURL,
            allowForeignOverwrite: false
        )
        assertTest(updateSamePath == aiAppPath, "In-place update of current tile with allowedExistingAppURL succeeds")
    } catch {
        assertTest(false, "Generator safety suite failed with error: \(error)")
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test 2: Managed Collection Lifecycle & Non-Destructive Deletion
    // ─────────────────────────────────────────────────────────────────────────
    print("\n[Suite 2] Managed Collection Lifecycle & Non-Destructive Safety...")
    do {
        let testCID = UUID().uuidString
        let (cid, colURL) = try LauncherCollectionService.createManagedCollection(collectionID: testCID)
        assertTest(LauncherCollectionService.isManagedCollection(url: colURL), "Created collection is verified managed inside Collections root")

        let sourceDir = tempDir.appendingPathComponent("SourceDocs")
        try fm.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        let doc1 = sourceDir.appendingPathComponent("App1.app")
        let doc2 = sourceDir.appendingPathComponent("Doc2.pdf")
        try "app1".write(to: doc1, atomically: true, encoding: .utf8)
        try "doc2".write(to: doc2, atomically: true, encoding: .utf8)

        let add1 = LauncherCollectionService.addItem(sourceURL: doc1, to: cid)
        let add2 = LauncherCollectionService.addItem(sourceURL: doc2, to: cid)
        assertTest(add1.success && add2.success, "Added items as symlinks into managed collection")

        let items = LauncherCollectionService.fetchItems(for: colURL)
        assertTest(items.count == 2, "Fetched 2 items from managed collection")

        // Delete managed collection
        try LauncherCollectionService.deleteManagedCollection(collectionID: cid)
        assertTest(!fm.fileExists(atPath: colURL.path), "Managed collection directory deleted")
        assertTest(fm.fileExists(atPath: doc1.path) && fm.fileExists(atPath: doc2.path), "Original source documents remain 100% intact")
    } catch {
        assertTest(false, "Managed collection lifecycle failed with error: \(error)")
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test 3: Collection ID Validation & Path Traversal Protection
    // ─────────────────────────────────────────────────────────────────────────
    print("\n[Suite 3] Malicious Collection ID Traversal Rejection...")
    let maliciousIDs = [
        "../../Desktop",
        "foo/bar",
        "..",
        "",
        "   ",
        "a:b",
        "sub/dir/test"
    ]
    for id in maliciousIDs {
        var threw = false
        do {
            _ = try LauncherCollectionService.validateCollectionID(id)
        } catch {
            threw = true
        }
        let url = LauncherCollectionService.collectionURL(for: id, createIfMissing: false)
        assertTest(threw && url == nil, "Rejected malicious collectionID: '\(id)'")
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test 4: Custom App Ordering Alignment (Runtime & Manager)
    // ─────────────────────────────────────────────────────────────────────────
    print("\n[Suite 4] App Custom Ordering by Stable itemID...")
    do {
        let testDir = tempDir.appendingPathComponent("OrderTest")
        try fm.createDirectory(at: testDir, withIntermediateDirectories: true)
        let appClaude = testDir.appendingPathComponent("Claude.app")
        let appChatGPT = testDir.appendingPathComponent("ChatGPT.app")
        let appXcode = testDir.appendingPathComponent("Xcode.app")
        try "c".write(to: appClaude, atomically: true, encoding: .utf8)
        try "g".write(to: appChatGPT, atomically: true, encoding: .utf8)
        try "x".write(to: appXcode, atomically: true, encoding: .utf8)

        let customOrder = ["Xcode.app", "ChatGPT.app", "Claude.app"]
        let items = LauncherCollectionService.fetchItems(for: testDir, customOrder: customOrder)
        let itemNames = items.map { $0.id }
        assertTest(itemNames == ["Xcode.app", "ChatGPT.app", "Claude.app"], "Manager fetchItems preserves custom app order by itemID")
    } catch {
        assertTest(false, "Custom order test failed: \(error)")
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test 5: Legacy Discovery & Transactional Migration with Rollback
    // ─────────────────────────────────────────────────────────────────────────
    print("\n[Suite 5] Legacy Launcher Discovery & Transactional Migration...")
    do {
        let legacyDir = tempDir.appendingPathComponent("LegacyFolder")
        try fm.createDirectory(at: legacyDir, withIntermediateDirectories: true)
        let f1 = legacyDir.appendingPathComponent("ToolA.app")
        let f2 = legacyDir.appendingPathComponent("DocB.txt")
        try "a".write(to: f1, atomically: true, encoding: .utf8)
        try "b".write(to: f2, atomically: true, encoding: .utf8)

        // Migrate to managed collection
        let newCID = UUID().uuidString
        let (cid, _, count) = try LauncherCollectionService.migrateLegacyToManaged(legacyURL: legacyDir, newCollectionID: newCID)
        assertTest(count == 2 && cid == newCID, "Migrated legacy items into managed collection")
        assertTest(fm.fileExists(atPath: f1.path) && fm.fileExists(atPath: f2.path), "Original legacy folder and files remain untouched")

        // Forced failure migration rollback test
        let nonExistentDir = tempDir.appendingPathComponent("NonExistentFolder")
        var migrationFailed = false
        do {
            _ = try LauncherCollectionService.migrateLegacyToManaged(legacyURL: nonExistentDir)
        } catch {
            migrationFailed = true
        }
        assertTest(migrationFailed, "Migration safely fails and aborts on invalid source directory")

        try? LauncherCollectionService.deleteManagedCollection(collectionID: cid)
    } catch {
        assertTest(false, "Legacy migration failed: \(error)")
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test 6: PreferencesStore Defaults Wiring
    // ─────────────────────────────────────────────────────────────────────────
    print("\n[Suite 6] PreferencesStore Defaults Wiring...")
    let prefs = PreferencesStore.shared
    prefs.defaultTileModeRaw = TileMode.folder.rawValue
    prefs.defaultPresentationRaw = PresentationMode.menu.rawValue
    prefs.defaultGridColumns = 6
    prefs.defaultShowLabels = false
    prefs.defaultSortModeRaw = SortMode.recent.rawValue
    prefs.autoAddToDock = true

    assertTest(prefs.defaultTileMode == .folder, "PreferencesStore defaultTileMode resolves correctly")
    assertTest(prefs.defaultPresentation == .menu, "PreferencesStore defaultPresentation resolves correctly")
    assertTest(prefs.defaultGridColumns == 6, "PreferencesStore defaultGridColumns == 6")
    assertTest(prefs.defaultShowLabels == false, "PreferencesStore defaultShowLabels == false")
    assertTest(prefs.defaultSortMode == .recent, "PreferencesStore defaultSortMode == .recent")
    assertTest(prefs.autoAddToDock == true, "PreferencesStore autoAddToDock == true")

    // Restore defaults
    prefs.defaultTileModeRaw = TileMode.launcher.rawValue
    prefs.defaultPresentationRaw = PresentationMode.grid.rawValue
    prefs.defaultGridColumns = 5
    prefs.defaultShowLabels = true
    prefs.defaultSortModeRaw = SortMode.custom.rawValue
    prefs.autoAddToDock = false

    // ─────────────────────────────────────────────────────────────────────────
    // Test 7: Grid Navigation State Model
    // ─────────────────────────────────────────────────────────────────────────
    print("\n[Suite 7] Grid Navigation State Model...")
    var nav = GridNavigationState(selectedIndex: 0, columnsCount: 5, totalItems: 12)
    nav.moveRight()
    assertTest(nav.selectedIndex == 1, "Grid navigation moved right to index 1")
    nav.moveDown()
    assertTest(nav.selectedIndex == 6, "Grid navigation moved down by column count to index 6")
    nav.moveDown()
    assertTest(nav.selectedIndex == 11, "Grid navigation moved down to index 11")
    nav.moveDown()
    assertTest(nav.selectedIndex == 11, "Grid navigation clamped at last item index 11")
    nav.moveLeft()
    assertTest(nav.selectedIndex == 10, "Grid navigation moved left to index 10")
    nav.moveUp()
    assertTest(nav.selectedIndex == 5, "Grid navigation moved up to index 5")

    // ─────────────────────────────────────────────────────────────────────────
    // Test 8: Large Directory Performance (1,000+ Items)
    // ─────────────────────────────────────────────────────────────────────────
    print("\n[Suite 8] Large Directory Performance (1,000 items)...")
    do {
        let largeDir = tempDir.appendingPathComponent("Large1000")
        try fm.createDirectory(at: largeDir, withIntermediateDirectories: true)
        for i in 1...1000 {
            try "item".write(to: largeDir.appendingPathComponent("item_\(i).txt"), atomically: true, encoding: .utf8)
        }

        let start = Date()
        let items = LauncherCollectionService.fetchItems(for: largeDir)
        let elapsedMs = Date().timeIntervalSince(start) * 1000
        assertTest(items.count == 1000, "Successfully mapped 1,000 directory items")
        assertTest(elapsedMs < 1000, "1,000-item mapping completed in \(Int(elapsedMs))ms (< 1000ms)")
    } catch {
        assertTest(false, "Large directory test failed: \(error)")
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test 9: Pinned Rename Transaction & Old Dock Removal Failure Rollback
    // ─────────────────────────────────────────────────────────────────────────
    print("\n[Suite 9] Pinned Rename Transaction & Failure Rollback...")
    do {
        let store = TileStore()
        let targetDir = tempDir.appendingPathComponent("RenameTarget")
        try fm.createDirectory(at: targetDir, withIntermediateDirectories: true)
        try "content".write(to: targetDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)

        // Mock Dock state in memory
        var mockDock = Set<String>()
        DockService.isTileInDockOverride = { mockDock.contains($0) }
        DockService.addToDockOverride = { mockDock.insert($0); return true }
        DockService.removeFromDockOverride = { mockDock.remove($0); return true }

        let initialTile = try store.createTile(
            name: "Initial Launcher",
            targetPath: targetDir.path,
            mode: .launcher,
            presentation: .grid,
            sort: .custom,
            maxDepth: 3,
            gridColumns: 5,
            showLabels: true,
            iconConfig: IconConfiguration(),
            customOrder: nil,
            collectionID: UUID().uuidString,
            addToDock: true,
            runtimeURL: runtimeURL
        )
        assertTest(initialTile.isDockPinned && mockDock.contains(initialTile.appPath), "Initial tile created and pinned to Dock")

        let oldPath = initialTile.appPath

        // 1. Successful Rename
        let renamedTile = try store.updateTile(
            existingTile: initialTile,
            newName: "Renamed Launcher",
            targetPath: targetDir.path,
            mode: .launcher,
            presentation: .grid,
            sort: .custom,
            maxDepth: 3,
            gridColumns: 5,
            showLabels: true,
            iconConfig: IconConfiguration(),
            customOrder: nil,
            runtimeURL: runtimeURL
        )
        assertTest(renamedTile.name == "Renamed Launcher", "Tile renamed successfully")
        assertTest(!fm.fileExists(atPath: oldPath), "Old .app was deleted after successful rename")
        assertTest(fm.fileExists(atPath: renamedTile.appPath), "New .app exists on disk")
        assertTest(mockDock.contains(renamedTile.appPath) && !mockDock.contains(oldPath), "Dock updated atomically: old removed, new added")

        // 2. Injected Old Dock Removal Failure -> Rollback
        let currentAppPath = renamedTile.appPath
        DockService.removeFromDockOverride = { _ in false } // Inject failure

        var renameFailed = false
        do {
            _ = try store.updateTile(
                existingTile: renamedTile,
                newName: "Failed Rename Target",
                targetPath: targetDir.path,
                mode: .launcher,
                presentation: .grid,
                sort: .custom,
                maxDepth: 3,
                gridColumns: 5,
                showLabels: true,
                iconConfig: IconConfiguration(),
                customOrder: nil,
                runtimeURL: runtimeURL
            )
        } catch {
            renameFailed = true
        }

        assertTest(renameFailed, "Update threw error when old Dock removal failed")
        assertTest(fm.fileExists(atPath: currentAppPath), "Old app preserved on rollback")
        assertTest(mockDock.contains(currentAppPath), "Old Dock entry preserved on rollback")

        // Reset Dock overrides
        DockService.isTileInDockOverride = nil
        DockService.addToDockOverride = nil
        DockService.removeFromDockOverride = nil
    } catch {
        assertTest(false, "Pinned rename transaction suite failed: \(error)")
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test 10: Dock Warning and Error State Surfacing
    // ─────────────────────────────────────────────────────────────────────────
    print("\n[Suite 10] Dock Warning and Error State Surfacing...")
    do {
        let store = TileStore()
        let targetDir = tempDir.appendingPathComponent("WarningTarget")
        try fm.createDirectory(at: targetDir, withIntermediateDirectories: true)

        let tile = try store.createTile(
            name: "Warning Tile",
            targetPath: targetDir.path,
            mode: .launcher,
            presentation: .grid,
            sort: .custom,
            maxDepth: 3,
            gridColumns: 5,
            showLabels: true,
            iconConfig: IconConfiguration(),
            customOrder: nil,
            collectionID: UUID().uuidString,
            addToDock: false,
            runtimeURL: runtimeURL
        )

        // Force toggleDockPin failure
        DockService.addToDockOverride = { _ in false }
        let toggleSuccess = store.toggleDockPin(for: tile)
        assertTest(!toggleSuccess, "toggleDockPin returned false on Dock failure")
        assertTest(store.lastWarningMessage != nil, "Structured warning surfaced in store.lastWarningMessage")

        // Acknowledge / clear warning
        store.lastWarningMessage = nil
        assertTest(store.lastWarningMessage == nil, "Warning cleared cleanly")

        DockService.addToDockOverride = nil
    } catch {
        assertTest(false, "Dock warning state test failed: \(error)")
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Test 11: Real Grid Launcher Dismissal Lifecycle
    // ─────────────────────────────────────────────────────────────────────────
    print("\n[Suite 11] Real Grid Launcher Dismissal Lifecycle...")
    do {
        let dummyURL = tempDir.appendingPathComponent("GridTarget")
        try fm.createDirectory(at: dummyURL, withIntermediateDirectories: true)

        let gridWin = GridLauncherWindow(
            title: "Test Grid",
            targetURL: dummyURL,
            items: [],
            columnsCount: 5,
            showLabels: true,
            anchorPoint: NSPoint(x: 100, y: 100)
        )

        var dismissedByEscape = false
        gridWin.onDismiss = {
            dismissedByEscape = true
        }
        gridWin.cancelOperation(nil)
        assertTest(dismissedByEscape, "Grid window cancelOperation (Escape) triggers onDismiss")

        var dismissedByResign = false
        gridWin.onDismiss = {
            dismissedByResign = true
        }
        gridWin.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification))

        // Run runloop briefly for 0.15s async dispatch
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        assertTest(dismissedByResign, "Grid window windowDidResignKey triggers onDismiss")
    } catch {
        assertTest(false, "Grid dismissal lifecycle test failed: \(error)")
    }

    // Cleanup
    try? fm.removeItem(at: tempDir)

    print("\n────────────────────────────────────────────────────────────────────────")
    print("Manager Integration Results: \(passedCount) Passed, \(failedCount) Failed")
    if failedCount > 0 {
        exit(1)
    }
}

@main
struct ManagerIntegrationTestsRunner {
    static func main() {
        runAllTests()
    }
}
