#!/bin/bash
# dock-folders — Generate .app wrappers for folders so custom icons show in the macOS Dock
# Each generated app shows a native popup menu with the folder's contents when clicked.
#
# Usage:
#   ./dock-folders.sh /path/to/folder1 [/path/to/folder2 ...]
#   ./dock-folders.sh --output-dir ~/MyApps /path/to/folder
#   ./dock-folders.sh --all /path/to/parent-directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_OUTPUT_DIR="$SCRIPT_DIR/build"
OUTPUT_DIR=""
ALL_MODE=false
FOLDERS=()

# ─── Argument parsing ───────────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] FOLDER [FOLDER ...]

Generate .app wrappers for folders so their custom icons show in the macOS Dock.

Options:
  --output-dir DIR   Where to place generated .app bundles
                     (default: ~/Applications/Dock Folders/)
  --all DIR          Process all subdirectories within DIR
  -h, --help         Show this help

Examples:
  $(basename "$0") ~/Documents/dock-folders/coding
  $(basename "$0") --all ~/Documents/dock-folders
  $(basename "$0") --output-dir ~/Desktop ~/Documents/my-folder
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --all)
            ALL_MODE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            FOLDERS+=("$1")
            shift
            ;;
    esac
done

# In --all mode, the single argument is the parent directory
if $ALL_MODE; then
    if [[ ${#FOLDERS[@]} -ne 1 ]]; then
        echo "Error: --all requires exactly one directory argument"
        exit 1
    fi
    PARENT_DIR="${FOLDERS[0]}"
    if [[ ! -d "$PARENT_DIR" ]]; then
        echo "Error: '$PARENT_DIR' is not a directory"
        exit 1
    fi
    FOLDERS=()
    while IFS= read -r -d '' dir; do
        FOLDERS+=("$dir")
    done < <(find "$PARENT_DIR" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -print0 | sort -z)
fi

if [[ ${#FOLDERS[@]} -eq 0 ]]; then
    echo "Error: No folders specified. Use -h for help."
    exit 1
fi

OUTPUT_DIR="${OUTPUT_DIR:-$DEFAULT_OUTPUT_DIR}"
mkdir -p "$OUTPUT_DIR"

# ─── Icon extraction ────────────────────────────────────────────────────────────
# Extracts the folder's rendered icon (including custom emoji + color) as .icns
create_icns() {
    local folder_path="$1"
    local icns_path="$2"
    local png_path="${icns_path%.icns}.png"
    local iconset_dir="${icns_path%.icns}.iconset"

    # Check for "Customize Folder" emoji icon (stored as JSON xattr)
    local emoji=""
    local xattr_data
    xattr_data=$(xattr -p com.apple.icon.folder#S "$folder_path" 2>/dev/null) || true
    if [[ -n "$xattr_data" ]]; then
        # Parse emoji from JSON like {"emoji":"👨‍💻"}
        emoji=$(echo "$xattr_data" | python3 -c "import sys,json; print(json.load(sys.stdin).get('emoji',''))" 2>/dev/null) || true
    fi

    # Step 1: Render the folder icon as 1024x1024 PNG via AppleScript ObjC bridge
    if [[ -n "$emoji" ]]; then
        # Render emoji on dark background (macOS adds its own squircle mask)
        osascript <<ICONSCRIPT >/dev/null 2>&1
use framework "AppKit"
use framework "Foundation"
use scripting additions

set px to 1024

-- Create canvas
set bitmapRep to (current application's NSBitmapImageRep's alloc()'s initWithBitmapDataPlanes:(missing value) pixelsWide:px pixelsHigh:px bitsPerSample:8 samplesPerPixel:4 hasAlpha:true isPlanar:false colorSpaceName:(current application's NSCalibratedRGBColorSpace) bytesPerRow:0 bitsPerPixel:0)

set ctx to (current application's NSGraphicsContext's graphicsContextWithBitmapImageRep:bitmapRep)
current application's NSGraphicsContext's setCurrentContext:ctx

-- Fill with dark background
set bgColor to current application's NSColor's colorWithCalibratedRed:0.455 green:0.455 blue:0.471 alpha:1.0
set bgPath to current application's NSBezierPath's bezierPathWithRect:{{0, 0}, {px, px}}
bgColor's setFill()
bgPath's fill()

-- Draw emoji large and centered
set emojiStr to current application's NSString's stringWithString:"${emoji}"
set emojiSize to 620
set emojiFont to current application's NSFont's systemFontOfSize:emojiSize
set emojiAttrs to current application's NSDictionary's dictionaryWithObjects:{emojiFont} forKeys:{current application's NSFontAttributeName}
set attrStr to (current application's NSAttributedString's alloc()'s initWithString:emojiStr attributes:emojiAttrs)
set strSize to attrStr's |size|()
set strW to strSize's width
set strH to strSize's height
set drawX to ((px - strW) / 2)
set drawY to ((px - strH) / 2)
attrStr's drawAtPoint:{x:drawX, y:drawY}

current application's NSGraphicsContext's setCurrentContext:(missing value)

set pngData to bitmapRep's representationUsingType:4 |properties|:(missing value)
set outURL to current application's NSURL's fileURLWithPath:"${png_path}"
pngData's writeToURL:outURL options:0 |error|:(missing value)
ICONSCRIPT
    else
        # No custom emoji — use NSWorkspace's standard icon
        osascript <<ICONSCRIPT >/dev/null 2>&1
use framework "AppKit"
use framework "Foundation"
use scripting additions

set ws to current application's NSWorkspace's sharedWorkspace()
set theIcon to ws's iconForFile:"${folder_path}"
theIcon's setSize:{width:1024, height:1024}

set bitmapRep to (current application's NSBitmapImageRep's alloc()'s initWithBitmapDataPlanes:(missing value) pixelsWide:1024 pixelsHigh:1024 bitsPerSample:8 samplesPerPixel:4 hasAlpha:true isPlanar:false colorSpaceName:(current application's NSCalibratedRGBColorSpace) bytesPerRow:0 bitsPerPixel:0)

set ctx to (current application's NSGraphicsContext's graphicsContextWithBitmapImageRep:bitmapRep)
current application's NSGraphicsContext's setCurrentContext:ctx
theIcon's drawInRect:{origin:{x:0, y:0}, |size|:{width:1024, height:1024}}
current application's NSGraphicsContext's setCurrentContext:(missing value)

set pngData to bitmapRep's representationUsingType:4 |properties|:(missing value)
set outURL to current application's NSURL's fileURLWithPath:"${png_path}"
pngData's writeToURL:outURL options:0 |error|:(missing value)
ICONSCRIPT
    fi

    if [[ ! -f "$png_path" || ! -s "$png_path" ]]; then
        return 1
    fi

    # Step 2: Create iconset with all required sizes via sips
    mkdir -p "$iconset_dir"
    sips -z 16 16     "$png_path" --out "$iconset_dir/icon_16x16.png"      >/dev/null 2>&1
    sips -z 32 32     "$png_path" --out "$iconset_dir/icon_16x16@2x.png"   >/dev/null 2>&1
    sips -z 32 32     "$png_path" --out "$iconset_dir/icon_32x32.png"      >/dev/null 2>&1
    sips -z 64 64     "$png_path" --out "$iconset_dir/icon_32x32@2x.png"   >/dev/null 2>&1
    sips -z 128 128   "$png_path" --out "$iconset_dir/icon_128x128.png"    >/dev/null 2>&1
    sips -z 256 256   "$png_path" --out "$iconset_dir/icon_128x128@2x.png" >/dev/null 2>&1
    sips -z 256 256   "$png_path" --out "$iconset_dir/icon_256x256.png"    >/dev/null 2>&1
    sips -z 512 512   "$png_path" --out "$iconset_dir/icon_256x256@2x.png" >/dev/null 2>&1
    sips -z 512 512   "$png_path" --out "$iconset_dir/icon_512x512.png"    >/dev/null 2>&1
    sips -z 1024 1024 "$png_path" --out "$iconset_dir/icon_512x512@2x.png" >/dev/null 2>&1

    # Step 3: Convert iconset to icns
    iconutil -c icns "$iconset_dir" -o "$icns_path" 2>/dev/null
    local result=$?

    # Cleanup
    rm -rf "$iconset_dir" "$png_path"
    return $result
}

# ─── AppleScript template ───────────────────────────────────────────────────────
generate_applescript() {
    local folder_path="$1"
    local folder_name="$2"

    cat <<APPLESCRIPT
use framework "AppKit"
use framework "Foundation"
use scripting additions

property NSMenu : a reference to current application's NSMenu
property NSMenuItem : a reference to current application's NSMenuItem
property NSWorkspace : a reference to current application's NSWorkspace
property NSEvent : a reference to current application's NSEvent
property NSURL : a reference to current application's NSURL
property NSImage : a reference to current application's NSImage

on run
    showFolderMenu()
end run

on reopen
    showFolderMenu()
end reopen

on showFolderMenu()
    set folderPath to "$folder_path"
    
    -- Use "list folder" from Standard Additions (runs in-process, no Apple Events needed)
    try
        set folderAlias to (POSIX file folderPath) as alias
        set allNames to list folder folderAlias without invisibles
    on error errMsg number errNum
        display dialog "Cannot read folder: " & folderPath & return & return & "Error " & errNum & ": " & errMsg buttons {"OK"} default button "OK" with icon caution
        return
    end try
    
    -- Sort names alphabetically (A-Z, case-insensitive) using Cocoa
    set cocoaArray to current application's NSMutableArray's arrayWithArray:allNames
    cocoaArray's sortUsingSelector:"localizedCaseInsensitiveCompare:"
    set allNames to cocoaArray as list
    
    if (count of allNames) is 0 then
        display dialog "Folder is empty." buttons {"OK"} default button "OK"
        return
    end if
    
    -- Build NSMenu with icons
    set theMenu to NSMenu's alloc()'s initWithTitle:""
    (theMenu's setMinimumWidth:220)
    (theMenu's setAutoenablesItems:false)
    set ws to NSWorkspace's sharedWorkspace()
    
    -- Header item (folder name, non-clickable)
    set headerItem to (NSMenuItem's alloc()'s initWithTitle:"$folder_name" action:(missing value) keyEquivalent:"")
    set headerFont to current application's NSFont's boldSystemFontOfSize:13
    set headerAttrs to current application's NSDictionary's dictionaryWithObject:headerFont forKey:(current application's NSFontAttributeName)
    set headerAttrStr to (current application's NSAttributedString's alloc()'s initWithString:"$folder_name" attributes:headerAttrs)
    (headerItem's setAttributedTitle:headerAttrStr)
    (headerItem's setEnabled:false)
    (theMenu's addItem:headerItem)
    (theMenu's addItem:(NSMenuItem's separatorItem()))
    
    repeat with aName in allNames
        set itemPath to folderPath & "/" & aName
        
        -- Display name: strip .app extension for cleaner look
        set displayName to aName as text
        if displayName ends with ".app" then
            set displayName to text 1 thru -5 of displayName
        end if
        
        set menuItem to (NSMenuItem's alloc()'s initWithTitle:displayName action:(missing value) keyEquivalent:"")
        (menuItem's setEnabled:true)
        set itemIcon to (ws's iconForFile:itemPath)
        (itemIcon's setSize:{width:24, height:24})
        (menuItem's setImage:itemIcon)
        (menuItem's setRepresentedObject:itemPath)
        (theMenu's addItem:menuItem)
    end repeat
    
    -- Add separator + "Show in Finder" at bottom
    (theMenu's addItem:(NSMenuItem's separatorItem()))
    set finderItem to (NSMenuItem's alloc()'s initWithTitle:"Show in Finder" action:(missing value) keyEquivalent:"")
    (finderItem's setEnabled:true)
    (finderItem's setTag:-1)
    (theMenu's addItem:finderItem)
    
    -- Position popup near the bottom of screen (Dock area)
    set mouseLoc to NSEvent's mouseLocation()
    set popupX to (mouseLoc's x) as real
    set popupY to 50
    
    set popupPoint to {popupX, popupY}
    
    set wasSelected to (theMenu's popUpMenuPositioningItem:(missing value) atLocation:popupPoint inView:(missing value))
    
    if wasSelected as boolean then
        set clicked to theMenu's highlightedItem()
        if clicked is not missing value then
            set clickedTag to (clicked's tag()) as integer
            if clickedTag is -1 then
                -- "Show in Finder" via NSWorkspace (no Apple Events needed)
                set folderURL to NSURL's fileURLWithPath:folderPath
                ws's openURL:folderURL
            else
                set clickedPath to (clicked's representedObject()) as text
                set clickedURL to NSURL's fileURLWithPath:clickedPath
                ws's openURL:clickedURL
            end if
        end if
    end if
end showFolderMenu
APPLESCRIPT
}

# ─── Main loop ───────────────────────────────────────────────────────────────────
echo "🗂  Dock Folders Generator"
echo "   Output: $OUTPUT_DIR"
echo ""

for folder in "${FOLDERS[@]}"; do
    # Resolve to absolute path
    folder="$(cd "$folder" 2>/dev/null && pwd)"

    if [[ ! -d "$folder" ]]; then
        echo "⚠ Skipping '$folder' — not a directory"
        continue
    fi

    folder_name="$(basename "$folder")"
    app_name="${folder_name}.app"
    app_path="$OUTPUT_DIR/$app_name"

    echo "📁 Processing: $folder_name"

    # Remove old version if it exists
    if [[ -d "$app_path" ]]; then
        rm -rf "$app_path"
    fi

    # 1. Generate AppleScript source
    tmp_script="$OUTPUT_DIR/.tmp_${folder_name}.applescript"
    generate_applescript "$folder" "$folder_name" > "$tmp_script"

    # 2. Compile to .app bundle (stay-open so it handles reopen events)
    echo "  ⚙ Compiling app..."
    osacompile -s -o "$app_path" "$tmp_script" 2>/dev/null
    rm -f "$tmp_script"

    # 3. Extract and set custom icon
    echo "  🎨 Extracting folder icon..."
    tmp_icns="$OUTPUT_DIR/.tmp_${folder_name}.icns"

    if create_icns "$folder" "$tmp_icns"; then
        cp "$tmp_icns" "$app_path/Contents/Resources/applet.icns"
        # Remove the asset catalog — it contains the default applet icon and
        # takes precedence over applet.icns on modern macOS
        rm -f "$app_path/Contents/Resources/Assets.car"
        echo "  ✅ Icon applied"
    else
        echo "  ⚠ Could not extract icon, using system default"
    fi
    rm -f "$tmp_icns"

    # 4. Update Info.plist with a proper bundle identifier
    bundle_id="com.dock-folders.$(echo "$folder_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $bundle_id" "$app_path/Contents/Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $bundle_id" "$app_path/Contents/Info.plist" 2>/dev/null

    # Set a proper display name
    /usr/libexec/PlistBuddy -c "Set :CFBundleName $folder_name" "$app_path/Contents/Info.plist" 2>/dev/null

    # Hide from CMD+Tab app switcher (agent app — no Dock bounce, no menu bar)
    /usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$app_path/Contents/Info.plist" 2>/dev/null || true

    # Add usage descriptions so macOS can prompt for permissions
    /usr/libexec/PlistBuddy -c "Add :NSAppleEventsUsageDescription string This app needs permission to show folder contents." "$app_path/Contents/Info.plist" 2>/dev/null || true

    # 5. Ad-hoc code-sign so macOS TCC can track the app's identity
    #    Without signing, TCC silently blocks access to ~/Documents, ~/Desktop, etc.
    echo "  🔏 Code-signing..."
    xattr -cr "$app_path" 2>/dev/null
    codesign --force --sign - "$app_path" 2>&1 || echo "  ⚠ Code-signing failed (non-fatal)"

    # Touch to refresh icon cache
    touch "$app_path"

    echo "  ✅ Created: $app_path"
    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Done! Drag the .app files from '$OUTPUT_DIR' into your Dock."
echo ""
echo "💡 First launch: if the folder is in ~/Documents, ~/Desktop,"
echo "   or ~/Downloads, macOS may ask for permission — click Allow."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

