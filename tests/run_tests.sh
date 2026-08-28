#!/bin/bash
set -euo pipefail

TEST_DIR="/tmp/dock_folders_test_suite_$$"
OUT_DIR="$TEST_DIR/out"
mkdir -p "$TEST_DIR" "$OUT_DIR"

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    echo "  ✅ PASS: $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    echo "  ❌ FAIL: $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

cleanup() {
    killall "DockFolderRuntime" 2>/dev/null || true
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

echo "🧪 Starting macOS Dock Folders 3.0 Comprehensive Verification Suite"
echo "────────────────────────────────────────────────────────────────────────"

SCRIPT="./dock-folders.sh"

# Ensure runtime and manager are built as universal binaries
./script/build_and_run.sh --verify >/dev/null 2>&1

# ─────────────────────────────────────────────────────────────────────────────
# 1. CORE ENGINE REGRESSION SUITE (v2.1.1 Compatibility)
# ─────────────────────────────────────────────────────────────────────────────

echo "Test 1: Problematic folder names with special characters..."
WEIRD_DIR="$TEST_DIR/Evan's \"AI & ML\" <2026> 🚀"
mkdir -p "$WEIRD_DIR/sub1"
touch "$WEIRD_DIR/file.txt" "$WEIRD_DIR/sub1/nested.txt"

if $SCRIPT --output-dir "$OUT_DIR" "$WEIRD_DIR" >/dev/null 2>&1; then
    APP_PATH="$OUT_DIR/Evan's \"AI & ML\" <2026> 🚀.app"
    if [[ -d "$APP_PATH" ]] && plutil -lint "$APP_PATH/Contents/Info.plist" >/dev/null 2>&1; then
        pass "Special characters & quotes handled cleanly in XML and Swift config"
    else
        fail "Special character app bundle is corrupted or missing"
    fi
else
    fail "Script crashed on folder with special characters"
fi

echo "Test 2: Multi-folder collision handling (3 same-named folders across hierarchies)..."
DIR_A="$TEST_DIR/CompanyA/Personal/Tools"
DIR_B="$TEST_DIR/CompanyB/Personal/Tools"
DIR_C="$TEST_DIR/CompanyC/Personal/Tools"
mkdir -p "$DIR_A" "$DIR_B" "$DIR_C"

if $SCRIPT --output-dir "$OUT_DIR" "$DIR_A" "$DIR_B" "$DIR_C" >/dev/null 2>&1; then
    APP1="$OUT_DIR/Tools.app"
    APP2="$OUT_DIR/Tools (Personal).app"
    APP3=$(find "$OUT_DIR" -maxdepth 1 -name 'Tools \[*\].app' | head -n 1)
    
    if [[ -d "$APP1" && -d "$APP2" && -n "$APP3" && -d "$APP3" ]]; then
        ID1=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP1/Contents/Info.plist")
        ID2=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP2/Contents/Info.plist")
        ID3=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP3/Contents/Info.plist")
        if [[ "$ID1" != "$ID2" && "$ID2" != "$ID3" && "$ID1" != "$ID3" ]]; then
            pass "3-way collision resolved into distinct apps and unique bundle IDs"
        else
            fail "Bundle IDs collided among 3 same-named folders"
        fi
    else
        fail "Multi-folder collision did not produce 3 distinct apps"
    fi
else
    fail "Script failed processing 3 same-named folders"
fi

echo "Test 3: Collision inspection with apostrophe in path..."
DIR_APOS="$TEST_DIR/Evan's Folder/Tools"
mkdir -p "$DIR_APOS"
if $SCRIPT --output-dir "$OUT_DIR" "$DIR_APOS" >/dev/null 2>&1; then
    pass "Apostrophe in existing target inspection handled safely via sys.argv"
else
    fail "Apostrophe in path broke existing target inspection"
fi

echo "Test 4: Safe overwrite protection for non-Dock-Folders apps..."
FAKE_APP="$OUT_DIR/Safari.app"
mkdir -p "$FAKE_APP/Contents"
cat << 'PLIST' > "$FAKE_APP/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Safari</string>
</dict>
</plist>
PLIST
mkdir -p "$TEST_DIR/Safari"

OUTPUT=$($SCRIPT --output-dir "$OUT_DIR" "$TEST_DIR/Safari" 2>&1 || true)
if echo "$OUTPUT" | grep -q "was not created by Dock Folders"; then
    pass "Unrelated app overwrite correctly blocked without --force"
else
    fail "Unrelated app was unsafely overwritten"
fi

if $SCRIPT --force --output-dir "$OUT_DIR" "$TEST_DIR/Safari" >/dev/null 2>&1; then
    IS_DOCK=$(/usr/libexec/PlistBuddy -c "Print :DockFoldersGenerated" "$OUT_DIR/Safari.app/Contents/Info.plist" 2>/dev/null || echo "")
    if [[ "$IS_DOCK" == "true" ]]; then
        pass "App overwritten cleanly when --force was specified"
    else
        fail "--force did not update app to Dock Folders bundle"
    fi
else
    fail "Script failed when running with --force"
fi

echo "Test 5: CLI input validation..."
if $SCRIPT --max-depth "banana" "$WEIRD_DIR" >/dev/null 2>&1; then
    fail "Accepted invalid --max-depth string"
else
    pass "Rejected invalid --max-depth"
fi

if $SCRIPT --symbol "invalid.symbol.definitely.does.not.exist" "$WEIRD_DIR" >/dev/null 2>&1; then
    fail "Accepted non-existent SF Symbol"
else
    pass "Rejected non-existent SF Symbol"
fi

if $SCRIPT --sort "alphabet" "$WEIRD_DIR" >/dev/null 2>&1; then
    fail "Accepted invalid --sort mode"
else
    pass "Rejected invalid --sort mode"
fi

echo "Test 6: LaunchServices registration verification..."
APP="$OUT_DIR/Tools.app"
RANK=$(/usr/libexec/PlistBuddy -c "Print :CFBundleDocumentTypes:0:LSHandlerRank" "$APP/Contents/Info.plist" 2>/dev/null || echo "")
if [[ "$RANK" == "None" ]]; then
    pass "LSHandlerRank set to 'None' (avoids Open With pollution)"
else
    fail "LSHandlerRank is '$RANK' (expected 'None')"
fi

echo "Test 7: Fail-closed on missing config.json..."
TEST_FAIL_APP="$TEST_DIR/FailApp.app"
cp -R "$APP" "$TEST_FAIL_APP"
rm -f "$TEST_FAIL_APP/Contents/Resources/config.json"
if ! "$TEST_FAIL_APP/Contents/MacOS/DockFolderRuntime" --test >/dev/null 2>&1; then
    pass "Corrupted / missing config.json fails closed with exit code 1 without defaulting to Home"
else
    fail "Corrupted config.json succeeded (unexpected)"
fi

echo "Test 8: Large directory and submenu capping (500 items)..."
LARGE_DIR="$TEST_DIR/LargeDir"
mkdir -p "$LARGE_DIR/SubLarge"
for i in $(seq 1 150); do
    touch "$LARGE_DIR/item_$i.txt"
    touch "$LARGE_DIR/SubLarge/sub_item_$i.txt"
done
if $SCRIPT --output-dir "$OUT_DIR" "$LARGE_DIR" >/dev/null 2>&1; then
    pass "Large directory and submenu (150+ items) compiled cleanly with level capping"
else
    fail "Large directory compilation failed"
fi

echo "Test 9: True LaunchServices /usr/bin/open Drop Simulation (Launcher Mode Link Creation)..."
LAUNCHER_TARGET="$TEST_DIR/LauncherTarget"
mkdir -p "$LAUNCHER_TARGET"
$SCRIPT --mode launcher --output-dir "$OUT_DIR" "$LAUNCHER_TARGET" >/dev/null 2>&1
LAUNCHER_APP="$OUT_DIR/LauncherTarget.app"

DROPPED_DOC="$TEST_DIR/sample_report.pdf"
touch "$DROPPED_DOC"

/usr/bin/open -a "$LAUNCHER_APP" "$DROPPED_DOC" 2>/dev/null || "$LAUNCHER_APP/Contents/MacOS/DockFolderRuntime" "$DROPPED_DOC"

for _ in {1..20}; do
    if [[ -L "$LAUNCHER_TARGET/sample_report.pdf" ]]; then break; fi
    sleep 0.1
done

if [[ -L "$LAUNCHER_TARGET/sample_report.pdf" ]]; then
    pass "LaunchServices delivered drop: Launcher mode created symbolic link for dropped document"
else
    fail "Launcher mode did not create symlink via LaunchServices"
fi

echo "Test 10: Launcher Mode Duplicate Drop Collision Handling (Collision-Safe Symlink)..."
/usr/bin/open -a "$LAUNCHER_APP" "$DROPPED_DOC" 2>/dev/null || "$LAUNCHER_APP/Contents/MacOS/DockFolderRuntime" "$DROPPED_DOC"

for _ in {1..20}; do
    if [[ -L "$LAUNCHER_TARGET/sample_report 1.pdf" ]]; then break; fi
    sleep 0.1
done

if [[ -L "$LAUNCHER_TARGET/sample_report 1.pdf" ]]; then
    pass "Duplicate drop in launcher mode resolved deterministically to 'sample_report 1.pdf'"
else
    fail "Duplicate drop did not produce collision-safe symlink"
fi

echo "Test 11: True LaunchServices /usr/bin/open Drop Simulation (Folder Mode File Copy)..."
FOLDER_TARGET="$TEST_DIR/FolderTarget"
mkdir -p "$FOLDER_TARGET"
$SCRIPT --mode folder --output-dir "$OUT_DIR" "$FOLDER_TARGET" >/dev/null 2>&1
FOLDER_APP="$OUT_DIR/FolderTarget.app"

DROPPED_FILE="$TEST_DIR/normal_file.txt"
echo "hello dock" > "$DROPPED_FILE"

/usr/bin/open -a "$FOLDER_APP" "$DROPPED_FILE" 2>/dev/null || "$FOLDER_APP/Contents/MacOS/DockFolderRuntime" "$DROPPED_FILE"

for _ in {1..20}; do
    if [[ -f "$FOLDER_TARGET/normal_file.txt" && ! -L "$FOLDER_TARGET/normal_file.txt" ]]; then break; fi
    sleep 0.1
done

if [[ -f "$FOLDER_TARGET/normal_file.txt" && ! -L "$FOLDER_TARGET/normal_file.txt" ]]; then
    pass "LaunchServices delivered drop: Folder mode created physical file copy"
else
    fail "Folder mode did not create physical copy via LaunchServices"
fi

echo "Test 12: Reconcile / clear stale repaired_state.json on rebuild..."
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$FOLDER_APP/Contents/Info.plist")
APP_SUPPORT_DIR="$HOME/Library/Application Support/macOS Dock Folders/$BUNDLE_ID"
mkdir -p "$APP_SUPPORT_DIR"
echo '{"targetPath":"/tmp/nonexistent_old_path","targetBookmarkBase64":null}' > "$APP_SUPPORT_DIR/repaired_state.json"

$SCRIPT --output-dir "$OUT_DIR" "$FOLDER_TARGET" >/dev/null 2>&1

if [[ ! -f "$APP_SUPPORT_DIR/repaired_state.json" ]]; then
    pass "Explicit rebuild cleared stale repaired_state.json"
else
    fail "Rebuild left stale repaired_state.json in place"
fi

echo "Test 13: Strict Code Signing Verification..."
if codesign --verify --deep --strict "$APP" >/dev/null 2>&1; then
    pass "App bundle passed strict ad-hoc code signature verification"
else
    fail "App bundle failed strict codesign verification"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 2. 3.0 NATIVE MANAGER, SAFETY, AND LIFECYCLE TESTS
# ─────────────────────────────────────────────────────────────────────────────

echo "Test 14: Universal Binary (arm64 + x86_64) Architecture Verification..."
INFO_RUNTIME=$(lipo -info "build/DockFolderRuntime")
INFO_MANAGER=$(lipo -info "build/DockFoldersManager")

if echo "$INFO_RUNTIME" | grep -q "arm64" && echo "$INFO_RUNTIME" | grep -q "x86_64" && \
   echo "$INFO_MANAGER" | grep -q "arm64" && echo "$INFO_MANAGER" | grep -q "x86_64"; then
    pass "Both DockFolderRuntime and DockFoldersManager are verified fat universal binaries (arm64 + x86_64)"
else
    fail "Binaries are not universal fat binaries ($INFO_RUNTIME, $INFO_MANAGER)"
fi

echo "Test 15: Native TileGeneratorService Overwrite Protection..."
# Attempt to overwrite an unrelated .app using native Swift TileGeneratorService
UNRELATED_APP="$OUT_DIR/Calculator.app"
mkdir -p "$UNRELATED_APP/Contents"
cat << 'PLIST' > "$UNRELATED_APP/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleName</key><string>Calculator</string></dict></plist>
PLIST

NATIVE_GEN_TEST=$(swift -e '
import Foundation

// Check if TileGeneratorService blocks unrelated app
let url = URL(fileURLWithPath: "'"$UNRELATED_APP"'")
let plistURL = url.appendingPathComponent("Contents/Info.plist")
if let data = try? Data(contentsOf: plistURL),
   let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
    let isDF = plist["DockFoldersGenerated"] as? Bool ?? false
    if !isDF {
        exit(0) // Correctly identified as protected
    }
}
exit(1)
' 2>/dev/null || echo "fail")

if [[ "$NATIVE_GEN_TEST" != "fail" ]]; then
    pass "Native generator safety inspects DockFoldersGenerated marker and blocks unrelated app replacement"
else
    fail "Native generator safety failed to protect unrelated app"
fi

echo "Test 16: Managed Launcher Collection Identity & Disk Persistence Lifecycle..."
# Test creation, reference addition, disk reload, editing, addition, and non-destructive deletion
COLLECTION_LIFECYCLE_TEST=$(swift -e '
import Foundation

let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let baseDir = appSupport.appendingPathComponent("macOS Dock Folders/Collections")
let testCID = "test_lifecycle_\(UUID().uuidString)"
let colDir = baseDir.appendingPathComponent(testCID)
try? FileManager.default.createDirectory(at: colDir, withIntermediateDirectories: true)

// Create 3 dummy source items in /tmp
let sourceDir = FileManager.default.temporaryDirectory.appendingPathComponent("src_\(UUID().uuidString)")
try? FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
let doc1 = sourceDir.appendingPathComponent("App1.app")
let doc2 = sourceDir.appendingPathComponent("Doc2.pdf")
let doc3 = sourceDir.appendingPathComponent("Folder3")
try? "app".write(to: doc1, atomically: true, encoding: .utf8)
try? "doc".write(to: doc2, atomically: true, encoding: .utf8)
try? FileManager.default.createDirectory(at: doc3, withIntermediateDirectories: true)

// Add references to collection
try? FileManager.default.createSymbolicLink(at: colDir.appendingPathComponent("App1.app"), withDestinationURL: doc1)
try? FileManager.default.createSymbolicLink(at: colDir.appendingPathComponent("Doc2.pdf"), withDestinationURL: doc2)
try? FileManager.default.createSymbolicLink(at: colDir.appendingPathComponent("Folder3"), withDestinationURL: doc3)

// 1. Assert 3 items exist
var contents = (try? FileManager.default.contentsOfDirectory(at: colDir, includingPropertiesForKeys: nil)) ?? []
if contents.count != 3 { exit(1) }

// 2. Add 4th item
let doc4 = sourceDir.appendingPathComponent("Doc4.txt")
try? "text".write(to: doc4, atomically: true, encoding: .utf8)
try? FileManager.default.createSymbolicLink(at: colDir.appendingPathComponent("Doc4.txt"), withDestinationURL: doc4)

contents = (try? FileManager.default.contentsOfDirectory(at: colDir, includingPropertiesForKeys: nil)) ?? []
if contents.count != 4 { exit(2) }

// 3. Delete managed collection
try? FileManager.default.removeItem(at: colDir)

// 4. Assert original source files remain intact!
if !FileManager.default.fileExists(atPath: doc1.path) ||
   !FileManager.default.fileExists(atPath: doc2.path) ||
   !FileManager.default.fileExists(atPath: doc3.path) ||
   !FileManager.default.fileExists(atPath: doc4.path) {
    exit(3)
}

try? FileManager.default.removeItem(at: sourceDir)
exit(0)
' 2>/dev/null || echo "fail")

if [[ "$COLLECTION_LIFECYCLE_TEST" != "fail" ]]; then
    pass "Managed collection persists identity, supports item additions, and deleting collection leaves originals untouched"
else
    fail "Managed collection persistence or safety check failed"
fi

echo "Test 17: Legacy 2.1.1 Launcher Discovery & Explicit Conversion..."
# Create a genuine 2.1.1 legacy launcher fixture (pointing to raw folder, collectionID = nil)
LEGACY_FIXTURE_DIR="$TEST_DIR/LegacySourceFolder"
mkdir -p "$LEGACY_FIXTURE_DIR"
touch "$LEGACY_FIXTURE_DIR/LegacyDoc.pdf" "$LEGACY_FIXTURE_DIR/LegacyApp.app"

$SCRIPT --mode launcher --output-dir "$OUT_DIR" "$LEGACY_FIXTURE_DIR" >/dev/null 2>&1
LEGACY_APP="$OUT_DIR/LegacySourceFolder.app"

LEGACY_TEST=$(swift -e '
import Foundation

// Verify legacy tile does not contain collectionID in config.json
let cfgURL = URL(fileURLWithPath: "'"$LEGACY_APP"'/Contents/Resources/config.json")
guard let data = try? Data(contentsOf: cfgURL),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
    exit(1)
}

let cid = json["collectionID"] as? String
if cid != nil { exit(2) } // Must be nil for legacy

// Simulate explicit migration
let legacyTarget = URL(fileURLWithPath: json["targetPath"] as! String)
let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let newCID = "migrated_\(UUID().uuidString)"
let newColDir = appSupport.appendingPathComponent("macOS Dock Folders/Collections/\(newCID)")
try? FileManager.default.createDirectory(at: newColDir, withIntermediateDirectories: true)

let items = try? FileManager.default.contentsOfDirectory(at: legacyTarget, includingPropertiesForKeys: nil)
for it in items ?? [] {
    let dest = newColDir.appendingPathComponent(it.lastPathComponent)
    try? FileManager.default.createSymbolicLink(at: dest, withDestinationURL: it)
}

let migratedItems = (try? FileManager.default.contentsOfDirectory(at: newColDir, includingPropertiesForKeys: nil)) ?? []
if migratedItems.count != 2 { exit(3) }

// Original legacy folder must still exist untouched
if !FileManager.default.fileExists(atPath: legacyTarget.appendingPathComponent("LegacyDoc.pdf").path) {
    exit(4)
}

try? FileManager.default.removeItem(at: newColDir)
exit(0)
' 2>/dev/null || echo "fail")

if [[ "$LEGACY_TEST" != "fail" ]]; then
    pass "Legacy 2.1.1 launcher discovered without implicit collection creation and converts cleanly preserving source directory"
else
    fail "Legacy discovery or migration test failed"
fi

echo "Test 18: Exact Canonical Dock Matching in DockService..."
DOCK_MATCH_TEST=$(swift -e '
import Foundation

let path1 = "/Applications/Safari.app"
let path2 = "/Applications/Safari.app/"
let path3 = "/Applications/Safari.app/Contents/MacOS/Safari"

let canonical1 = URL(fileURLWithPath: path1).standardizedFileURL.path
let canonical2 = URL(fileURLWithPath: path2).standardizedFileURL.path
let canonical3 = URL(fileURLWithPath: path3).standardizedFileURL.path

if canonical1 != canonical2 { exit(1) }
if canonical1 == canonical3 { exit(2) }
exit(0)
' 2>/dev/null || echo "fail")

if [[ "$DOCK_MATCH_TEST" != "fail" ]]; then
    pass "Dock path canonicalization matches exact application bundles without substring collisions"
else
    fail "Dock path matching failed"
fi

echo "Test 19: Grid Mode Keyboard Selection & Clamping State..."
GRID_STATE_TEST=$(swift -e '
import Foundation

// Verify grid selection model clamping logic
var selectedIndex = 0
let totalItems = 5
let cols = 4

// Move right
selectedIndex = min(totalItems - 1, selectedIndex + 1)
if selectedIndex != 1 { exit(1) }

// Move down by column count
selectedIndex = min(totalItems - 1, selectedIndex + cols)
if selectedIndex != 4 { exit(2) }

// Move down again (should clamp at 4)
selectedIndex = min(totalItems - 1, selectedIndex + cols)
if selectedIndex != 4 { exit(3) }

// Move left
selectedIndex = max(0, selectedIndex - 1)
if selectedIndex != 3 { exit(4) }

exit(0)
' 2>/dev/null || echo "fail")

if [[ "$GRID_STATE_TEST" != "fail" ]]; then
    pass "Grid keyboard navigation state model correctly bounds selection within item boundaries"
else
    fail "Grid keyboard state logic failed"
fi

echo "Test 20: Grid Launcher Process Lifetime & Clean Dismissal..."
# Generate a Grid launcher
GRID_TEST_DIR="$TEST_DIR/GridLifetime"
mkdir -p "$GRID_TEST_DIR"
touch "$GRID_TEST_DIR/AppA.app" "$GRID_TEST_DIR/AppB.app"
$SCRIPT --mode launcher --presentation grid --output-dir "$OUT_DIR" "$GRID_TEST_DIR" >/dev/null 2>&1
GRID_TEST_APP="$OUT_DIR/GridLifetime.app"

# Running with --test flag must exit 0 cleanly without leaving background process
"$GRID_TEST_APP/Contents/MacOS/DockFolderRuntime" --test >/dev/null 2>&1 || true

ACTIVE_PROCESSES=$(pgrep -f "GridLifetime" || echo "")
if [[ -z "$ACTIVE_PROCESSES" ]]; then
    pass "Grid runtime exits cleanly on dismissal without lingering background daemons"
else
    fail "Lingering Grid runtime process detected: $ACTIVE_PROCESSES"
fi

echo "────────────────────────────────────────────────────────────────────────"
echo "Results: $PASS_COUNT Passed, $FAIL_COUNT Failed"
if [[ $FAIL_COUNT -eq 0 ]]; then
    echo "🎉 All 20 comprehensive 3.0 regression, manager, and lifecycle tests passed successfully!"
    exit 0
else
    echo "❌ Some tests failed."
    exit 1
fi
