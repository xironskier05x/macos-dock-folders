#!/bin/bash
# dock-folders 2.1 — Bulletproof Native macOS Dock Folder Generator
#
# Generates ultra-fast, native .app wrappers for folders with lazy-loaded popup
# menus, two-phase icon loading, persistent bookmark self-healing, package detection,
# alias resolution, safe overwrite protection, and collision-free bundle identifiers.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_OUTPUT_DIR="$HOME/Applications/Dock Folders"
OUTPUT_DIR=""
ALL_MODE=false
SYMBOL_NAME=""
COLOR_ARG="dark"
IMAGE_PATH=""
SORT_MODE="name"
TILE_MODE="folder"
MAX_DEPTH=3
ADD_TO_DOCK=false
FORCE=false
FOLDERS=()

# ─── Usage / Help ─────────────────────────────────────────────────────────────
usage() {
    cat <<EOHELP
Usage: $(basename "$0") [OPTIONS] FOLDER [FOLDER ...]

Generate ultra-fast native .app wrappers for folders with rich Dock popup menus.

Options:
  --output-dir DIR      Where to place generated .app bundles (default: ~/Applications/Dock Folders)
  --all DIR             Process all subdirectories within DIR
  --mode MODE           Tile mode: 'folder' (browses directory) or 'launcher' (virtual app drawer) (default: folder)
  --symbol NAME         SF Symbol name for icon (e.g. folder.badge.gear, terminal.fill)
  --color COLOR         Icon color: preset (blue, purple, green, orange, red, dark, etc.) or hex code (#007AFF)
  --image PATH          Custom PNG/JPEG/ICNS file to use as icon
  --sort MODE           Sort order: 'name' (A-Z), 'recent' (modified date), 'kind' (Apps/Folders/Files) (default: name)
  --max-depth N         Nested subfolder menu depth limit [0..10] (default: 3)
  --add-to-dock         Automatically pin the generated .app to your macOS Dock
  --force               Allow overwriting existing .app bundles not created by Dock Folders
  -h, --help            Show this help

Keyboard & Mouse Shortcuts in Generated App:
  Click / ↵             Open selected item
  ⌥ Option + Click       Reveal selected item in Finder
  ⌘1 ... ⌘9             Quick-launch top 9 items
  ⌘O                    Open root folder in Finder
  ⌘T                    Open root folder in Terminal
  Drag & Drop           Drag files onto Dock icon (copies in folder mode; links in launcher mode)

Examples:
  $(basename "$0") ~/Documents/Coding
  $(basename "$0") --mode launcher --symbol "sparkles" --color purple ~/Applications/AI_Apps
  $(basename "$0") --symbol "terminal.fill" --color dark ~/Developer/Projects
  $(basename "$0") --all ~/Documents/DockFolders --add-to-dock
EOHELP
    exit 0
}

# ─── Argument parsing & validation ───────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-dir)
            [[ $# -lt 2 ]] && { echo "Error: --output-dir requires a directory path"; exit 1; }
            OUTPUT_DIR="$2"; shift 2 ;;
        --all)
            ALL_MODE=true; shift ;;
        --mode)
            [[ $# -lt 2 ]] && { echo "Error: --mode requires an argument ('folder' or 'launcher')"; exit 1; }
            TILE_MODE="$2"; shift 2 ;;
        --symbol)
            [[ $# -lt 2 ]] && { echo "Error: --symbol requires an SF Symbol name"; exit 1; }
            SYMBOL_NAME="$2"; shift 2 ;;
        --color)
            [[ $# -lt 2 ]] && { echo "Error: --color requires a color name or hex code"; exit 1; }
            COLOR_ARG="$2"; shift 2 ;;
        --image)
            [[ $# -lt 2 ]] && { echo "Error: --image requires an image file path"; exit 1; }
            IMAGE_PATH="$2"; shift 2 ;;
        --sort)
            [[ $# -lt 2 ]] && { echo "Error: --sort requires a mode ('name', 'recent', 'kind')"; exit 1; }
            SORT_MODE="$2"; shift 2 ;;
        --max-depth)
            [[ $# -lt 2 ]] && { echo "Error: --max-depth requires an integer"; exit 1; }
            MAX_DEPTH="$2"; shift 2 ;;
        --add-to-dock)
            ADD_TO_DOCK=true; shift ;;
        --force)
            FORCE=true; shift ;;
        -h|--help)
            usage ;;
        --)
            shift; while [[ $# -gt 0 ]]; do FOLDERS+=("$1"); shift; done; break ;;
        -*)
            echo "Error: Unknown option '$1'. Use -h for help."; exit 1 ;;
        *)
            FOLDERS+=("$1"); shift ;;
    esac
done

# Validate CLI inputs
if [[ "$TILE_MODE" != "folder" && "$TILE_MODE" != "launcher" ]]; then
    echo "Error: Invalid --mode '$TILE_MODE'. Must be 'folder' or 'launcher'."
    exit 1
fi

if [[ "$SORT_MODE" != "name" && "$SORT_MODE" != "recent" && "$SORT_MODE" != "kind" && "$SORT_MODE" != "date" && "$SORT_MODE" != "modified" && "$SORT_MODE" != "type" ]]; then
    echo "Error: Invalid --sort '$SORT_MODE'. Must be 'name', 'recent', or 'kind'."
    exit 1
fi

if ! [[ "$MAX_DEPTH" =~ ^[0-9]+$ ]] || [[ "$MAX_DEPTH" -lt 0 ]] || [[ "$MAX_DEPTH" -gt 10 ]]; then
    echo "Error: --max-depth must be an integer between 0 and 10."
    exit 1
fi

if [[ -n "$IMAGE_PATH" && ! -f "$IMAGE_PATH" ]]; then
    echo "Error: Custom image file '$IMAGE_PATH' does not exist."
    exit 1
fi

# Ensure swiftc compiler is available
if ! command -v swiftc &>/dev/null; then
    echo "Error: 'swiftc' compiler not found. Please install Xcode Command Line Tools: xcode-select --install"
    exit 1
fi

# Validate SF Symbol if provided
if [[ -n "$SYMBOL_NAME" ]]; then
    if ! swift -e 'import Cocoa; exit(NSImage(systemSymbolName: CommandLine.arguments[1], accessibilityDescription: nil) != nil ? 0 : 1)' "$SYMBOL_NAME" 2>/dev/null; then
        echo "Error: SF Symbol '$SYMBOL_NAME' not found in macOS system symbols."
        exit 1
    fi
fi

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
    PARENT_DIR="$(cd "$PARENT_DIR" && pwd)"
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

# ─── Compile Universal Runtime Binary (Cached) ────────────────────────────────
RUNTIME_BIN="$SCRIPT_DIR/src/DockFolderRuntime"
if [[ ! -f "$RUNTIME_BIN" || "$SCRIPT_DIR/src/runtime.swift" -nt "$RUNTIME_BIN" ]]; then
    echo "⚙ Compiling universal DockFolderRuntime..."
    swiftc -O -o "$RUNTIME_BIN" "$SCRIPT_DIR/src/runtime.swift"
fi

# ─── XML & JSON Helpers ───────────────────────────────────────────────────────
escape_xml() {
    local str="$1"
    str="${str//&/&amp;}"
    str="${str//</&lt;}"
    str="${str//>/&gt;}"
    str="${str//\"/&quot;}"
    str="${str//\'/&apos;}"
    echo "$str"
}

get_existing_target() {
    local cfg_file="$1"
    python3 -c "import json, sys; print(json.load(open(sys.argv[1])).get('targetPath', ''))" "$cfg_file" 2>/dev/null || echo ""
}

# Creates a 1024x1024 .icns file from SF Symbol, Emoji, Image, or Folder Icon
create_icns() {
    local folder_path="$1"
    local icns_path="$2"
    local custom_symbol="$3"
    local custom_color="$4"
    local custom_image="$5"
    
    local png_path="${icns_path%.icns}.png"
    local iconset_dir="${icns_path%.icns}.iconset"

    if [[ -n "$custom_image" && -f "$custom_image" ]]; then
        sips -s format png "$custom_image" --out "$png_path" >/dev/null 2>&1 || cp "$custom_image" "$png_path"
    else
        local emoji=""
        local xattr_data
        xattr_data=$(xattr -p com.apple.icon.folder#S "$folder_path" 2>/dev/null) || true
        if [[ -n "$xattr_data" ]]; then
            emoji=$(echo "$xattr_data" | python3 -c "import sys,json; print(json.load(sys.stdin).get('emoji',''))" 2>/dev/null) || true
        fi

        local render_swift
        render_swift=$(cat <<'SWIFT'
import Cocoa

func parseColor(_ str: String) -> NSColor {
    let lower = str.lowercased()
    switch lower {
    case "blue": return NSColor(calibratedRed: 0.0, green: 0.478, blue: 1.0, alpha: 1.0)
    case "purple": return NSColor(calibratedRed: 0.686, green: 0.322, blue: 0.871, alpha: 1.0)
    case "pink": return NSColor(calibratedRed: 1.0, green: 0.176, blue: 0.333, alpha: 1.0)
    case "red": return NSColor(calibratedRed: 1.0, green: 0.231, blue: 0.188, alpha: 1.0)
    case "orange": return NSColor(calibratedRed: 1.0, green: 0.584, blue: 0.0, alpha: 1.0)
    case "yellow": return NSColor(calibratedRed: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
    case "green": return NSColor(calibratedRed: 0.204, green: 0.780, blue: 0.349, alpha: 1.0)
    case "teal": return NSColor(calibratedRed: 0.353, green: 0.784, blue: 0.980, alpha: 1.0)
    case "indigo": return NSColor(calibratedRed: 0.345, green: 0.337, blue: 0.839, alpha: 1.0)
    case "gray": return NSColor(calibratedRed: 0.557, green: 0.557, blue: 0.576, alpha: 1.0)
    case "dark": return NSColor(calibratedRed: 0.227, green: 0.227, blue: 0.235, alpha: 1.0)
    default:
        var hex = str.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        if hex.count == 6 {
            let r = CGFloat((int >> 16) & 0xFF) / 255.0
            let g = CGFloat((int >> 8) & 0xFF) / 255.0
            let b = CGFloat(int & 0xFF) / 255.0
            return NSColor(calibratedRed: r, green: g, blue: b, alpha: 1.0)
        }
        return NSColor(calibratedRed: 0.227, green: 0.227, blue: 0.235, alpha: 1.0)
    }
}

let args = CommandLine.arguments
let outPath = args[1]
let symbolName = args.count > 2 && !args[2].isEmpty ? args[2] : nil
let colorStr = args.count > 3 && !args[3].isEmpty ? args[3] : "dark"
let emojiStr = args.count > 4 && !args[4].isEmpty ? args[4] : nil
let folderPath = args.count > 5 ? args[5] : ""

let size: CGFloat = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size),
    pixelsHigh: Int(size),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .calibratedRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
    exit(1)
}

NSGraphicsContext.current = ctx

if symbolName != nil || emojiStr != nil {
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let path = NSBezierPath(roundedRect: rect, xRadius: 220, yRadius: 220)
    parseColor(colorStr).setFill()
    path.fill()

    if let sym = symbolName, let symImage = NSImage(systemSymbolName: sym, accessibilityDescription: nil) {
        let config = NSImage.SymbolConfiguration(pointSize: 520, weight: .medium)
            .applying(.init(paletteColors: [.white]))
        let configured = symImage.withSymbolConfiguration(config) ?? symImage
        let symSize = configured.size
        let drawRect = NSRect(x: (size - symSize.width) / 2, y: (size - symSize.height) / 2, width: symSize.width, height: symSize.height)
        configured.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    } else if let em = emojiStr {
        let font = NSFont.systemFont(ofSize: 600)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let attrStr = NSAttributedString(string: em, attributes: attrs)
        let strSize = attrStr.size()
        let drawX = (size - strSize.width) / 2
        let drawY = (size - strSize.height) / 2
        attrStr.draw(at: NSPoint(x: drawX, y: drawY))
    }
} else {
    let ws = NSWorkspace.shared
    let theIcon = ws.icon(forFile: folderPath)
    theIcon.size = NSSize(width: size, height: size)
    theIcon.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
}

NSGraphicsContext.current = nil

if let pngData = rep.representation(using: .png, properties: [:]) {
    try? pngData.write(to: URL(fileURLWithPath: outPath))
}
SWIFT
)
        swift -e "$render_swift" "$png_path" "$custom_symbol" "$custom_color" "$emoji" "$folder_path" 2>/dev/null || return 1
    fi

    if [[ ! -f "$png_path" || ! -s "$png_path" ]]; then
        return 1
    fi

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

    iconutil -c icns "$iconset_dir" -o "$icns_path" 2>/dev/null
    local res=$?
    rm -rf "$iconset_dir" "$png_path"
    return $res
}

# ─── Dock Pinning Helper (Idempotent & Truthful) ─────────────────────────────
pin_to_dock() {
    local app_bundle="$1"
    if command -v dockutil &>/dev/null; then
        if ! dockutil --find "$app_bundle" &>/dev/null; then
            if dockutil --add "$app_bundle" --no-restart >/dev/null 2>&1; then
                DOCK_RESTART_NEEDED=true
            else
                echo "  ⚠ Launcher created successfully, but automatic Dock pinning failed."
            fi
        fi
    else
        if ! defaults read com.apple.dock persistent-apps 2>/dev/null | grep -Fq "$app_bundle"; then
            local escaped_bundle
            escaped_bundle=$(escape_xml "$app_bundle")
            local tile_data="<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$escaped_bundle</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
            if defaults write com.apple.dock persistent-apps -array-add "$tile_data" 2>/dev/null; then
                DOCK_RESTART_NEEDED=true
            else
                echo "  ⚠ Launcher created successfully, but automatic Dock pinning failed."
            fi
        fi
    fi
}

DOCK_RESTART_NEEDED=false

# ─── Main Generator Loop ──────────────────────────────────────────────────────
echo "🚀  macOS Dock Folders 2.1 Generator"
echo "    Output Directory: $OUTPUT_DIR"
echo ""

BUILD_SUCCESS_COUNT=0

for folder_arg in "${FOLDERS[@]}"; do
    if [[ ! -d "$folder_arg" ]]; then
        echo "⚠ Skipping '$folder_arg' — directory not found"
        continue
    fi

    folder="$(cd "$folder_arg" && pwd)"
    folder_name="$(basename "$folder")"
    parent_name="$(basename "$(dirname "$folder")")"

    # Deterministic hash of canonical path for bundle ID and collision avoidance
    folder_hash=$(echo -n "$folder" | shasum -a 256 | head -c 12)
    short_hash=$(echo -n "$folder" | shasum -a 256 | head -c 6)
    bundle_id="com.macosdockfolders.tile.$folder_hash"

    # Multi-collision resolution:
    # 1. Try "Folder.app"
    # 2. If taken by different target -> "Folder (Parent).app"
    # 3. If that's also taken by different target -> "Folder [hash].app"
    app_name="${folder_name}.app"
    app_path="$OUTPUT_DIR/$app_name"

    if [[ -d "$app_path" ]]; then
        existing_cfg="$app_path/Contents/Resources/config.json"
        existing_target=""
        [[ -f "$existing_cfg" ]] && existing_target=$(get_existing_target "$existing_cfg")
        
        if [[ -n "$existing_target" && "$existing_target" != "$folder" ]]; then
            # Level 2 candidate
            app_name="${folder_name} (${parent_name}).app"
            app_path="$OUTPUT_DIR/$app_name"
            
            if [[ -d "$app_path" ]]; then
                existing_cfg="$app_path/Contents/Resources/config.json"
                existing_target=""
                [[ -f "$existing_cfg" ]] && existing_target=$(get_existing_target "$existing_cfg")
                if [[ -n "$existing_target" && "$existing_target" != "$folder" ]]; then
                    # Level 3 candidate: unique hash
                    app_name="${folder_name} [${short_hash}].app"
                    app_path="$OUTPUT_DIR/$app_name"
                fi
            fi
        fi
    fi

    echo "📁 Building: $folder_name -> $app_name"

    # Safety check: Verify overwrite permission if app already exists
    if [[ -d "$app_path" && "$FORCE" != "true" ]]; then
        is_dock_folder=$(/usr/libexec/PlistBuddy -c "Print :DockFoldersGenerated" "$app_path/Contents/Info.plist" 2>/dev/null || echo "false")
        if [[ "$is_dock_folder" != "true" && "$is_dock_folder" != "YES" ]]; then
            echo "  ❌ Error: '$app_path' exists and was not created by Dock Folders."
            echo "     Use --force to overwrite non-Dock-Folders apps."
            continue
        fi
    fi

    # Transactional Staging Directory inside $OUTPUT_DIR (guarantees same volume for rename)
    staging_base="$OUTPUT_DIR/.staging_$$"
    staging_app="$staging_base/$app_name"
    mkdir -p "$staging_app/Contents/MacOS" "$staging_app/Contents/Resources"

    # 1. Copy universal runtime binary
    cp "$RUNTIME_BIN" "$staging_app/Contents/MacOS/DockFolderRuntime"
    chmod +x "$staging_app/Contents/MacOS/DockFolderRuntime"

    # 2. Generate Base64 URL Bookmark for persistent self-healing tracking
    bookmark_b64=$(swift -e '
import Foundation
let u = URL(fileURLWithPath: CommandLine.arguments[1])
if let b = try? u.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil) {
    print(b.base64EncodedString())
}
' "$folder" 2>/dev/null || echo "")

    # 3. Create config.json safely
    python3 -c "
import json, sys
data = {
    'targetPath': sys.argv[1],
    'targetBookmarkBase64': sys.argv[2] if sys.argv[2] else None,
    'displayName': sys.argv[3],
    'sortMode': sys.argv[4],
    'maxDepth': int(sys.argv[5]),
    'tileMode': sys.argv[6]
}
with open(sys.argv[7], 'w') as f:
    json.dump(data, f, indent=2)
" "$folder" "$bookmark_b64" "$folder_name" "$SORT_MODE" "$MAX_DEPTH" "$TILE_MODE" "$staging_app/Contents/Resources/config.json"

    # 4. Generate applet.icns
    icns_path="$staging_app/Contents/Resources/applet.icns"
    if create_icns "$folder" "$icns_path" "$SYMBOL_NAME" "$COLOR_ARG" "$IMAGE_PATH"; then
        echo "  🎨 Custom icon applied"
    else
        echo "  🎨 Standard folder icon applied"
    fi

    # 5. Create Info.plist safely with LSHandlerRank = None
    escaped_title=$(escape_xml "$folder_name")
    cat <<PLIST > "$staging_app/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>DockFolderRuntime</string>
    <key>CFBundleIdentifier</key>
    <string>$bundle_id</string>
    <key>CFBundleName</key>
    <string>$escaped_title</string>
    <key>CFBundleDisplayName</key>
    <string>$escaped_title</string>
    <key>CFBundleIconFile</key>
    <string>applet.icns</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.1</string>
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
    <key>NSAppleEventsUsageDescription</key>
    <string>This app needs access to show folder contents and open files.</string>
    <key>NSDesktopFolderUsageDescription</key>
    <string>This app needs access to show your Desktop items.</string>
    <key>NSDocumentsFolderUsageDescription</key>
    <string>This app needs access to show your Documents items.</string>
    <key>NSDownloadsFolderUsageDescription</key>
    <string>This app needs access to show your Downloads items.</string>
</dict>
</plist>
PLIST

    # 6. Validate Info.plist
    if ! plutil -lint "$staging_app/Contents/Info.plist" >/dev/null 2>&1; then
        echo "  ❌ Plist validation failed for $folder_name"
        rm -rf "$staging_base"
        continue
    fi

    # 7. Ad-hoc code sign and strict validation
    xattr -cr "$staging_app" 2>/dev/null || true
    if ! codesign --force --sign - "$staging_app" >/dev/null 2>&1; then
        echo "  ❌ Code signing failed for $folder_name"
        rm -rf "$staging_base"
        continue
    fi

    if ! codesign --verify --strict "$staging_app" >/dev/null 2>&1; then
        echo "  ❌ Strict codesign verification failed for $folder_name"
        rm -rf "$staging_base"
        continue
    fi

    # 8. Transactional Install with Backup & Rollback
    backup_path="$OUTPUT_DIR/.backup_${app_name}_$$"
    if [[ -d "$app_path" ]]; then
        mv "$app_path" "$backup_path"
    fi

    if mv "$staging_app" "$app_path"; then
        rm -rf "$backup_path" "$staging_base"
        touch "$app_path"
    else
        echo "  ❌ Install failed, rolling back..."
        [[ -d "$backup_path" ]] && mv "$backup_path" "$app_path"
        rm -rf "$staging_base"
        continue
    fi

    # 9. Optional idempotent Dock Pinning
    if $ADD_TO_DOCK; then
        echo "  📌 Pinning to macOS Dock..."
        pin_to_dock "$app_path"
    fi

    echo "  🎉 Successfully created: $app_path"
    echo ""
    BUILD_SUCCESS_COUNT=$((BUILD_SUCCESS_COUNT + 1))
done

if $DOCK_RESTART_NEEDED; then
    killall Dock 2>/dev/null || true
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✨ Build Complete ($BUILD_SUCCESS_COUNT created)"
echo "📍 Location: $OUTPUT_DIR"
if ! $ADD_TO_DOCK && [[ $BUILD_SUCCESS_COUNT -gt 0 ]]; then
    echo "💡 Drag the generated .app files into your macOS Dock."
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
