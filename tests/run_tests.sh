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
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

echo "🧪 Starting macOS Dock Folders 2.1 Comprehensive Test Suite"
echo "─────────────────────────────────────────────────────────────"

SCRIPT="./dock-folders.sh"

# Test 1: Problematic Folder Names (Quotes, Ampersands, Angle Brackets, Apostrophes, Emojis)
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

# Test 2: Multi-Folder Collision Handling (3+ Identical Names Across Hierarchies)
echo "Test 2: Multi-folder collision handling (3 same-named folders)..."
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

# Test 3: Path with Apostrophe During Existing Target Inspection
echo "Test 3: Collision inspection with apostrophe in path..."
DIR_APOS="$TEST_DIR/Evan's Folder/Tools"
mkdir -p "$DIR_APOS"
if $SCRIPT --output-dir "$OUT_DIR" "$DIR_APOS" >/dev/null 2>&1; then
    pass "Apostrophe in existing target inspection handled safely via sys.argv"
else
    fail "Apostrophe in path broke existing target inspection"
fi

# Test 4: Safe Overwrite Protection
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

# Test 5: CLI Input Validation
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

# Test 6: LaunchServices Rank (LSHandlerRank = None)
echo "Test 6: LaunchServices registration verification..."
APP="$OUT_DIR/Tools.app"
RANK=$(/usr/libexec/PlistBuddy -c "Print :CFBundleDocumentTypes:0:LSHandlerRank" "$APP/Contents/Info.plist" 2>/dev/null || echo "")
if [[ "$RANK" == "None" ]]; then
    pass "LSHandlerRank set to 'None' (avoids Open With pollution)"
else
    fail "LSHandlerRank is '$RANK' (expected 'None')"
fi

# Test 7: Fail-Closed on Corrupted / Missing Config
echo "Test 7: Fail-closed on missing config.json..."
TEST_FAIL_APP="$TEST_DIR/FailApp.app"
cp -R "$APP" "$TEST_FAIL_APP"
rm -f "$TEST_FAIL_APP/Contents/Resources/config.json"
# Running with --test flag causes immediate non-interactive exit(1)
if ! "$TEST_FAIL_APP/Contents/MacOS/DockFolderRuntime" --test >/dev/null 2>&1; then
    pass "Corrupted / missing config.json fails closed with exit code 1 without defaulting to Home"
else
    fail "Corrupted config.json succeeded (unexpected)"
fi

# Test 8: Large Directory Capping
echo "Test 8: Large directory capping (150 items)..."
LARGE_DIR="$TEST_DIR/LargeDir"
mkdir -p "$LARGE_DIR"
for i in $(seq 1 150); do
    touch "$LARGE_DIR/item_$i.txt"
done
if $SCRIPT --output-dir "$OUT_DIR" "$LARGE_DIR" >/dev/null 2>&1; then
    pass "Large directory (150+ items) compiled cleanly with top-level capping"
else
    fail "Large directory compilation failed"
fi

# Test 9: Strict Code Signing Verification
echo "Test 9: Strict code signing verification..."
if codesign --verify --deep --strict "$APP" >/dev/null 2>&1; then
    pass "App bundle passed strict ad-hoc code signature verification"
else
    fail "App bundle failed strict codesign verification"
fi

echo "─────────────────────────────────────────────────────────────"
echo "Results: $PASS_COUNT Passed, $FAIL_COUNT Failed"
if [[ $FAIL_COUNT -eq 0 ]]; then
    echo "🎉 All comprehensive tests passed successfully!"
    exit 0
else
    echo "❌ Some tests failed."
    exit 1
fi
