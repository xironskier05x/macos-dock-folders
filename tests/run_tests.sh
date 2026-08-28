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

echo "🧪 Starting macOS Dock Folders 2.1 Test Suite"
echo "──────────────────────────────────────────────"

SCRIPT="./dock-folders.sh"

# Test 1: Problematic Folder Names (Quotes, Ampersands, Angle Brackets, Apostrophes, Emojis)
echo "Test 1: Problematic folder names with special characters..."
WEIRD_DIR="$TEST_DIR/Evan's \"AI & ML\" <2026> 🚀"
mkdir -p "$WEIRD_DIR/sub1"
touch "$WEIRD_DIR/file.txt" "$WEIRD_DIR/sub1/nested.txt"

if $SCRIPT --output-dir "$OUT_DIR" "$WEIRD_DIR" >/dev/null 2>&1; then
    # Verify the app bundle was built and is valid
    APP_PATH="$OUT_DIR/Evan's \"AI & ML\" <2026> 🚀.app"
    if [[ -d "$APP_PATH" ]] && plutil -lint "$APP_PATH/Contents/Info.plist" >/dev/null 2>&1; then
        pass "Special characters & quotes handled cleanly in XML and Swift config"
    else
        fail "Special character app bundle is corrupted or missing"
    fi
else
    fail "Script crashed on folder with special characters"
fi

# Test 2: Same-named folders in different parent directories (Collision Handling)
echo "Test 2: Collision handling for same-named folders..."
DIR_WORK="$TEST_DIR/Work/Tools"
DIR_PERS="$TEST_DIR/Personal/Tools"
mkdir -p "$DIR_WORK" "$DIR_PERS"

if $SCRIPT --output-dir "$OUT_DIR" "$DIR_WORK" "$DIR_PERS" >/dev/null 2>&1; then
    APP1="$OUT_DIR/Tools.app"
    APP2="$OUT_DIR/Tools (Personal).app"
    if [[ -d "$APP1" && -d "$APP2" ]]; then
        ID1=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP1/Contents/Info.plist")
        ID2=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP2/Contents/Info.plist")
        if [[ "$ID1" != "$ID2" ]]; then
            pass "Same-named folders disambiguated with distinct bundle IDs: $ID1 vs $ID2"
        else
            fail "Bundle IDs collided for same-named folders"
        fi
    else
        fail "Same-named folders overwrote each other instead of disambiguating"
    fi
else
    fail "Script failed processing same-named folders"
fi

# Test 3: Safe Overwrite Protection
echo "Test 3: Safe overwrite protection for non-Dock-Folders apps..."
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

# Running without --force should protect the existing app
OUTPUT=$($SCRIPT --output-dir "$OUT_DIR" "$TEST_DIR/Safari" 2>&1 || true)
if echo "$OUTPUT" | grep -q "was not created by Dock Folders"; then
    pass "Unrelated app overwrite correctly blocked without --force"
else
    fail "Unrelated app was unsafely overwritten"
fi

# Running with --force should succeed
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

# Test 4: CLI Argument Validation
echo "Test 4: CLI input validation..."
# Invalid max-depth
if $SCRIPT --max-depth "banana" "$WEIRD_DIR" >/dev/null 2>&1; then
    fail "Accepted invalid --max-depth string"
else
    pass "Rejected invalid --max-depth"
fi

# Invalid SF Symbol
if $SCRIPT --symbol "invalid.symbol.definitely.does.not.exist" "$WEIRD_DIR" >/dev/null 2>&1; then
    fail "Accepted non-existent SF Symbol"
else
    pass "Rejected non-existent SF Symbol"
fi

# Invalid sort mode
if $SCRIPT --sort "alphabet" "$WEIRD_DIR" >/dev/null 2>&1; then
    fail "Accepted invalid --sort mode"
else
    pass "Rejected invalid --sort mode"
fi

# Test 5: LaunchServices Rank Verification (LSHandlerRank = None)
echo "Test 5: LaunchServices registration verification..."
APP="$OUT_DIR/Tools.app"
RANK=$(/usr/libexec/PlistBuddy -c "Print :CFBundleDocumentTypes:0:LSHandlerRank" "$APP/Contents/Info.plist" 2>/dev/null || echo "")
if [[ "$RANK" == "None" ]]; then
    pass "LSHandlerRank set to 'None' (avoids Open With pollution)"
else
    fail "LSHandlerRank is '$RANK' (expected 'None')"
fi

# Test 6: URL Bookmark & Config Persistence
echo "Test 6: Bookmark & Config JSON persistence..."
CFG="$APP/Contents/Resources/config.json"
if [[ -f "$CFG" ]]; then
    B64=$(python3 -c "import json; print(bool(json.load(open('$CFG')).get('targetBookmarkBase64')))" 2>/dev/null || echo "False")
    if [[ "$B64" == "True" ]]; then
        pass "Base64 URL Bookmark stored for persistent self-healing folder tracking"
    else
        fail "URL Bookmark missing from config.json"
    fi
else
    fail "config.json missing from app bundle"
fi

# Test 7: Strict Code Signing Verification
echo "Test 7: Strict code signing verification..."
if codesign --verify --deep --strict "$APP" >/dev/null 2>&1; then
    pass "App bundle passed strict ad-hoc code signature verification"
else
    fail "App bundle failed strict codesign verification"
fi

echo "──────────────────────────────────────────────"
echo "Results: $PASS_COUNT Passed, $FAIL_COUNT Failed"
if [[ $FAIL_COUNT -eq 0 ]]; then
    echo "🎉 All tests passed successfully!"
    exit 0
else
    echo "❌ Some tests failed."
    exit 1
fi
