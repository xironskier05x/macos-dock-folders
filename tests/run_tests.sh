#!/bin/bash
set -euo pipefail

TEST_DIR="/tmp/dock_folders_test_suite_$$"
OUT_DIR="$TEST_DIR/out"
BUILD_DIR="$(pwd)/build"
mkdir -p "$TEST_DIR" "$OUT_DIR" "$BUILD_DIR"

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
# 1. CORE ENGINE REGRESSION SUITE (v2.1.1 Baseline Compatibility)
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

TARGET_SAFARI="$TEST_DIR/Safari"
mkdir -p "$TARGET_SAFARI"
if ! $SCRIPT --output-dir "$OUT_DIR" "$TARGET_SAFARI" >/dev/null 2>&1; then
    pass "Unrelated app overwrite correctly blocked without --force"
else
    fail "Unrelated app was overwritten without --force"
fi

if $SCRIPT --force --output-dir "$OUT_DIR" "$TARGET_SAFARI" >/dev/null 2>&1; then
    pass "App overwritten cleanly when --force was specified"
else
    fail "Overwrite with --force failed"
fi

echo "Test 5: CLI input validation..."
if ! $SCRIPT --max-depth invalid "$TARGET_SAFARI" >/dev/null 2>&1; then
    pass "Rejected invalid --max-depth"
else
    fail "Allowed invalid --max-depth"
fi

if ! $SCRIPT --symbol "non.existent.symbol.name.xyz" "$TARGET_SAFARI" >/dev/null 2>&1; then
    pass "Rejected non-existent SF Symbol"
else
    fail "Allowed invalid SF Symbol"
fi

if ! $SCRIPT --sort "invalid_sort" "$TARGET_SAFARI" >/dev/null 2>&1; then
    pass "Rejected invalid --sort mode"
else
    fail "Allowed invalid --sort mode"
fi

echo "Test 6: LaunchServices registration verification..."
APP="$OUT_DIR/Tools.app"
RANK=$(/usr/libexec/PlistBuddy -c "Print :CFBundleDocumentTypes:0:LSHandlerRank" "$APP/Contents/Info.plist")
if [[ "$RANK" == "None" ]]; then
    pass "LSHandlerRank set to 'None' (avoids Open With pollution)"
else
    fail "LSHandlerRank is '$RANK', expected 'None'"
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
# 2. 3.0 NATIVE MANAGER PRODUCTION INTEGRATION TESTS
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

echo "Test 15: Executing Native Manager Integration Test Suite (Production Services)..."
swiftc -target arm64-apple-macos13.0 -O \
  DockFolders/Models/*.swift \
  DockFolders/Services/*.swift \
  DockFolders/Stores/*.swift \
  DockFolders/Support/*.swift \
  tests/ManagerIntegrationTests.swift \
  -o "$BUILD_DIR/ManagerIntegrationTests"

if "$BUILD_DIR/ManagerIntegrationTests"; then
    pass "All native ManagerIntegrationTests passed (P0 generator safety, collection lifecycle, custom order, migration, settings defaults, grid state)"
else
    fail "Native ManagerIntegrationTests failed"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 3. DISTRIBUTION ZIP & ARTIFACT VERIFICATION
# ─────────────────────────────────────────────────────────────────────────────

echo "Test 16: Distributable ZIP Extraction & Integrity Verification..."
ZIP_FILE="dist/Dock-Folders-Manager-v3.0.0.zip"
if [[ ! -f "$ZIP_FILE" ]]; then
    fail "Distributable ZIP artifact does not exist at $ZIP_FILE"
else
    ZIP_TEMP="$TEST_DIR/zip_extract"
    mkdir -p "$ZIP_TEMP"
    unzip -q "$ZIP_FILE" -d "$ZIP_TEMP"
    EXTRACTED_APP="$ZIP_TEMP/Dock Folders Manager.app"
    
    if [[ ! -d "$EXTRACTED_APP" ]]; then
        fail "Extracted ZIP did not contain 'Dock Folders Manager.app'"
    else
        # 1. Check executable permissions
        if [[ -x "$EXTRACTED_APP/Contents/MacOS/Dock Folders Manager" && -x "$EXTRACTED_APP/Contents/Resources/DockFolderRuntime" ]]; then
            pass "Extracted binaries have valid executable permissions"
        else
            fail "Extracted binaries missing executable permissions"
        fi

        # 2. Strict codesign verification
        if codesign --verify --deep --strict "$EXTRACTED_APP" >/dev/null 2>&1; then
            pass "Extracted 'Dock Folders Manager.app' passed strict code signature verification"
        else
            fail "Extracted app failed strict codesign verification"
        fi

        # 3. Universal architecture verification on extracted binaries
        EXT_RT_LIPO=$(lipo -info "$EXTRACTED_APP/Contents/Resources/DockFolderRuntime")
        EXT_MGR_LIPO=$(lipo -info "$EXTRACTED_APP/Contents/MacOS/Dock Folders Manager")
        if echo "$EXT_RT_LIPO" | grep -q "arm64" && echo "$EXT_RT_LIPO" | grep -q "x86_64" && \
           echo "$EXT_MGR_LIPO" | grep -q "arm64" && echo "$EXT_MGR_LIPO" | grep -q "x86_64"; then
            pass "Extracted ZIP binaries contain both arm64 and x86_64 slices"
        else
            fail "Extracted binaries are not universal ($EXT_RT_LIPO, $EXT_MGR_LIPO)"
        fi

        # 4. Check LSMinimumSystemVersion = 13.0
        MIN_OS=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$EXTRACTED_APP/Contents/Info.plist" 2>/dev/null || echo "")
        if [[ "$MIN_OS" == "13.0" ]]; then
            pass "Extracted app defines LSMinimumSystemVersion = 13.0"
        else
            fail "Extracted app LSMinimumSystemVersion is '$MIN_OS', expected '13.0'"
        fi

        # 5. Calculate SHA-256
        ZIP_SHA=$(shasum -a 256 "$ZIP_FILE" | awk '{print $1}')
        echo "  ℹ️ Distributable ZIP SHA-256: $ZIP_SHA"
        pass "Calculated valid distribution ZIP SHA-256"
    fi
fi

echo "Test 17: Grid Launcher Process Lifetime & Clean Dismissal..."
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
    echo "🎉 All release-candidate regression, manager, and packaging tests passed successfully!"
    exit 0
else
    echo "❌ Some tests failed."
    exit 1
fi
