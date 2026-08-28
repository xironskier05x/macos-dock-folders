#!/bin/bash
# dock-folders 2.0 — High-performance native macOS Dock folder generator
#
# Generates fast, native .app wrappers for folders that display rich popup menus
# when clicked in the macOS Dock, with hierarchical submenus, drag-and-drop file
# moving, modifier-key actions, SF Symbols, and custom icons.
#
# Usage:
#   ./dock-folders.sh /path/to/folder
#   ./dock-folders.sh --all /path/to/parent-directory
#   ./dock-folders.sh --symbol "folder.badge.gear" --color purple /path/to/folder
#   ./dock-folders.sh --sort recent --add-to-dock /path/to/folder

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_OUTPUT_DIR="$SCRIPT_DIR/build"
OUTPUT_DIR=""
ALL_MODE=false
SYMBOL_NAME=""
COLOR_ARG="dark"
IMAGE_PATH=""
SORT_MODE="name"
MAX_DEPTH=3
ADD_TO_DOCK=false
FOLDERS=()

# ─── Usage / Help ─────────────────────────────────────────────────────────────
usage() {
    cat <<EOHELP
Usage: $(basename "$0") [OPTIONS] FOLDER [FOLDER ...]

Generate ultra-fast native .app wrappers for folders with rich Dock popup menus.

Options:
  --output-dir DIR      Where to place generated .app bundles (default: ./build)
  --all DIR             Process all subdirectories within DIR
  --symbol NAME         SF Symbol name for icon (e.g. folder.badge.gear, terminal.fill)
  --color COLOR         Icon color: preset (blue, purple, green, orange, red, dark, etc.)
                        or hex code (e.g. #007AFF)
  --image PATH          Custom PNG/JPEG/ICNS file to use as icon
  --sort MODE           Sort order: 'name' (A-Z), 'recent' (modified date), 'kind' (Apps/Folders/Files)
                        (default: name)
  --max-depth N         Nested subfolder menu depth limit (default: 3)
  --add-to-dock         Automatically pin the generated .app to your macOS Dock
  -h, --help            Show this help

Keyboard & Mouse Shortcuts in Generated App:
  Click / ↵             Open selected item
  ⌥ Option + Click       Reveal selected item in Finder
  ⌘1 ... ⌘9             Quick-launch top 9 items
  ⌘O                    Open root folder in Finder
  ⌘T                    Open root folder in Terminal
  Drag & Drop           Drag files onto Dock icon to move them into the folder

Examples:
  $(basename "$0") ~/Documents/Coding
  $(basename "$0") --symbol "terminal.fill" --color dark ~/Developer/Projects
  $(basename "$0") --symbol "music.note" --color purple --sort recent ~/Music
  $(basename "$0") --all ~/Documents/DockFolders --add-to-dock
EOHELP
    exit 0
}

# ─── Argument parsing ─────────────────────────────────────────────────────────
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
        --symbol)
            SYMBOL_NAME="$2"
            shift 2
            ;;
        --color)
            COLOR_ARG="$2"
            shift 2
            ;;
        --image)
            IMAGE_PATH="$2"
            shift 2
            ;;
        --sort)
            SORT_MODE="$2"
            shift 2
            ;;
        --max-depth)
            MAX_DEPTH="$2"
            shift 2
            ;;
        --add-to-dock)
            ADD_TO_DOCK=true
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

# Ensure swiftc compiler is available
if ! command -v swiftc &>/dev/null; then
    echo "Error: 'swiftc' compiler not found. Please install Xcode Command Line Tools: xcode-select --install"
    exit 1
fi

# ─── Icon Generation Helpers ──────────────────────────────────────────────────
# Creates a 1024x1024 .icns file from SF Symbol, Emoji, Image, or Folder Icon
create_icns() {
    local folder_path="$1"
    local icns_path="$2"
    local custom_symbol="$3"
    local custom_color="$4"
    local custom_image="$5"
    
    local png_path="${icns_path%.icns}.png"
    local iconset_dir="${icns_path%.icns}.iconset"

    # Option 1: Custom Image File
    if [[ -n "$custom_image" && -f "$custom_image" ]]; then
        sips -s format png "$custom_image" --out "$png_path" >/dev/null 2>&1 || cp "$custom_image" "$png_path"
    else
        # Check for folder emoji xattr (from "Customize Folder")
        local emoji=""
        local xattr_data
        xattr_data=$(xattr -p com.apple.icon.folder#S "$folder_path" 2>/dev/null) || true
        if [[ -n "$xattr_data" ]]; then
            emoji=$(echo "$xattr_data" | python3 -c "import sys,json; print(json.load(sys.stdin).get('emoji',''))" 2>/dev/null) || true
        fi

        # Swift helper to render icon
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
    // Draw rounded background squircle
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
    // Standard folder icon
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

    # Create iconset with all required macOS sizes
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

# ─── Swift Application Source Template ────────────────────────────────────────
generate_swift_source() {
    local target_folder="$1"
    local folder_title="$2"
    local sort_mode="$3"
    local max_depth="$4"

    cat <<SWIFT
import Cocoa
import UniformTypeIdentifiers

class AppDelegate: NSObject, NSApplicationDelegate {
    let folderPath: String = "$target_folder"
    let folderName: String = "$folder_title"
    let sortMode: String = "$sort_mode"
    let maxDepth: Int = $max_depth
    var menuOpened = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            if !self.menuOpened {
                self.showMenu()
            }
        }
    }

    // Drag-and-drop handler: Copies dropped files directly into the target folder
    func application(_ app: NSApplication, openFiles filenames: [String]) {
        self.menuOpened = true
        let targetURL = URL(fileURLWithPath: folderPath)
        let fm = FileManager.default
        var copiedCount = 0

        for file in filenames {
            let sourceURL = URL(fileURLWithPath: file)
            let destURL = targetURL.appendingPathComponent(sourceURL.lastPathComponent)
            do {
                var finalDestURL = destURL
                var counter = 1
                let baseName = destURL.deletingPathExtension().lastPathComponent
                let ext = destURL.pathExtension
                while fm.fileExists(atPath: finalDestURL.path) {
                    let newName = ext.isEmpty ? "\\(baseName) \\(counter)" : "\\(baseName) \\(counter).\\(ext)"
                    finalDestURL = targetURL.appendingPathComponent(newName)
                    counter += 1
                }
                try fm.copyItem(at: sourceURL, to: finalDestURL)
                copiedCount += 1
            } catch {
                NSLog("Failed to copy \\(file): \\(error)")
            }
        }

        if copiedCount > 0 {
            NSSound.beep()
        }
        NSApp.terminate(nil)
    }

    func calculatePopupPoint() -> NSPoint {
        let mouseLoc = NSEvent.mouseLocation
        let screens = NSScreen.screens
        let currentScreen = screens.first(where: { NSMouseInRect(mouseLoc, \$0.frame, false) }) ?? NSScreen.main ?? (screens.isEmpty ? nil : screens[0])
        let screenFrame = currentScreen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let dockOrientation = (UserDefaults(suiteName: "com.apple.dock")?.string(forKey: "orientation") ?? "bottom").lowercased()

        var popupX = mouseLoc.x
        var popupY = mouseLoc.y

        switch dockOrientation {
        case "left":
            popupX = screenFrame.minX + 45
            popupY = mouseLoc.y
        case "right":
            popupX = screenFrame.maxX - 45
            popupY = mouseLoc.y
        case "bottom":
            popupX = mouseLoc.x
            popupY = screenFrame.minY + 45
        default:
            popupY = screenFrame.minY + 45
        }

        return NSPoint(x: popupX, y: popupY)
    }

    func buildMenu(for folderURL: URL, depth: Int) -> NSMenu {
        let menu = NSMenu(title: folderURL.lastPathComponent)
        menu.minimumWidth = 240
        menu.autoenablesItems = false

        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey, .isAliasFileKey, .isApplicationKey], options: [.skipsHiddenFiles]) else {
            let emptyItem = NSMenuItem(title: "(Inaccessible folder)", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
            return menu
        }

        if depth == 0 {
            let headerItem = NSMenuItem(title: folderName, action: nil, keyEquivalent: "")
            let headerFont = NSFont.boldSystemFont(ofSize: 13)
            let headerAttrs: [NSAttributedString.Key: Any] = [.font: headerFont]
            headerItem.attributedTitle = NSAttributedString(string: folderName, attributes: headerAttrs)
            headerItem.isEnabled = false
            menu.addItem(headerItem)
            menu.addItem(NSMenuItem.separator())
        }

        let sortedURLs = sortItems(contents)
        var keyIndex = 1

        for url in sortedURLs {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let isApp = url.pathExtension.lowercased() == "app" || ((try? url.resourceValues(forKeys: [.isApplicationKey]).isApplication) ?? false)

            var displayName = url.deletingPathExtension().lastPathComponent
            if !isApp && !url.pathExtension.isEmpty {
                displayName = url.lastPathComponent
            }

            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 18, height: 18)

            let keyEq = (depth == 0 && keyIndex <= 9) ? "\\(keyIndex)" : ""
            let item = NSMenuItem(title: displayName, action: #selector(itemClicked(_:)), keyEquivalent: keyEq)
            if depth == 0 && keyIndex <= 9 {
                item.keyEquivalentModifierMask = [.command]
                keyIndex += 1
            }
            item.target = self
            item.image = icon
            item.representedObject = url.path

            if isDir && !isApp && depth < maxDepth {
                let submenu = buildMenu(for: url, depth: depth + 1)
                item.submenu = submenu
                item.action = nil
            }

            menu.addItem(item)

            // ⌥ Option modifier: Reveal in Finder
            if !isDir || isApp || depth >= maxDepth {
                let altItem = NSMenuItem(title: "Reveal in Finder: \\(displayName)", action: #selector(revealInFinder(_:)), keyEquivalent: keyEq)
                altItem.keyEquivalentModifierMask = keyEq.isEmpty ? [.option] : [.option, .command]
                altItem.isAlternate = true
                altItem.image = icon
                altItem.target = self
                altItem.representedObject = url.path
                menu.addItem(altItem)
            }
        }

        if sortedURLs.isEmpty {
            let emptyItem = NSMenuItem(title: "(Folder is empty)", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        }

        if depth == 0 {
            menu.addItem(NSMenuItem.separator())

            let finderItem = NSMenuItem(title: "Show in Finder", action: #selector(openFolderInFinder), keyEquivalent: "o")
            finderItem.keyEquivalentModifierMask = [.command]
            if let finderIcon = NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app") as NSImage? {
                finderIcon.size = NSSize(width: 18, height: 18)
                finderItem.image = finderIcon
            }
            finderItem.target = self
            menu.addItem(finderItem)

            let termItem = NSMenuItem(title: "Open in Terminal", action: #selector(openFolderInTerminal), keyEquivalent: "t")
            termItem.keyEquivalentModifierMask = [.command]
            if let termIcon = NSWorkspace.shared.icon(forFile: "/System/Applications/Utilities/Terminal.app") as NSImage? {
                termIcon.size = NSSize(width: 18, height: 18)
                termItem.image = termIcon
            }
            termItem.target = self
            menu.addItem(termItem)
        }

        return menu
    }

    func sortItems(_ items: [URL]) -> [URL] {
        switch sortMode.lowercased() {
        case "recent", "date", "modified":
            return items.sorted {
                let d1 = (try? \$0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                let d2 = (try? \$1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                return d1 > d2
            }
        case "kind", "type":
            return items.sorted {
                let isApp1 = \$0.pathExtension.lowercased() == "app"
                let isApp2 = \$1.pathExtension.lowercased() == "app"
                let isDir1 = (try? \$0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let isDir2 = (try? \$1.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

                let p1 = isApp1 ? 0 : (isDir1 ? 1 : 2)
                let p2 = isApp2 ? 0 : (isDir2 ? 1 : 2)
                if p1 != p2 { return p1 < p2 }
                return \$0.lastPathComponent.localizedCaseInsensitiveCompare(\$1.lastPathComponent) == .orderedAscending
            }
        default:
            return items.sorted {
                \$0.lastPathComponent.localizedCaseInsensitiveCompare(\$1.lastPathComponent) == .orderedAscending
            }
        }
    }

    @objc func itemClicked(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }

    @objc func revealInFinder(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc func openFolderInFinder() {
        let url = URL(fileURLWithPath: folderPath)
        NSWorkspace.shared.open(url)
    }

    @objc func openFolderInTerminal() {
        let termURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        let targetURL = URL(fileURLWithPath: folderPath)
        NSWorkspace.shared.open([targetURL], withApplicationAt: termURL, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
    }

    func showMenu() {
        self.menuOpened = true
        let menu = buildMenu(for: URL(fileURLWithPath: folderPath), depth: 0)
        let point = calculatePopupPoint()

        menu.popUp(positioning: nil, at: point, in: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.terminate(nil)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
SWIFT
}

# ─── Dock Pinning Helper ──────────────────────────────────────────────────────
pin_to_dock() {
    local app_bundle="$1"
    if command -v dockutil &>/dev/null; then
        dockutil --add "$app_bundle" --no-restart >/dev/null 2>&1 || true
    else
        # Add to persistent-apps via defaults
        local tile_data="<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$app_bundle</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
        defaults write com.apple.dock persistent-apps -array-add "$tile_data"
    fi
}

# ─── Main Build Loop ──────────────────────────────────────────────────────────
echo "🚀  macOS Dock Folders 2.0 Generator"
echo "    Output Directory: $OUTPUT_DIR"
echo ""

for folder in "${FOLDERS[@]}"; do
    folder="$(cd "$folder" 2>/dev/null && pwd)"

    if [[ ! -d "$folder" ]]; then
        echo "⚠ Skipping '$folder' — not a directory"
        continue
    fi

    folder_name="$(basename "$folder")"
    app_name="${folder_name}.app"
    app_path="$OUTPUT_DIR/$app_name"
    macos_dir="$app_path/Contents/MacOS"
    resources_dir="$app_path/Contents/Resources"

    echo "📁 Building: $folder_name"

    # Remove previous build if present
    rm -rf "$app_path"
    mkdir -p "$macos_dir" "$resources_dir"

    # 1. Compile native Swift executable
    echo "  ⚙ Compiling native Swift binary..."
    tmp_swift="$OUTPUT_DIR/.tmp_${folder_name}.swift"
    generate_swift_source "$folder" "$folder_name" "$SORT_MODE" "$MAX_DEPTH" > "$tmp_swift"
    swiftc -O -o "$macos_dir/DockFolder" "$tmp_swift"
    rm -f "$tmp_swift"

    # 2. Generate and apply custom icon (.icns)
    echo "  🎨 Generating app icon..."
    icns_path="$resources_dir/applet.icns"
    if create_icns "$folder" "$icns_path" "$SYMBOL_NAME" "$COLOR_ARG" "$IMAGE_PATH"; then
        echo "  ✅ Custom icon applied"
    else
        echo "  ⚠ Standard icon used"
    fi

    # 3. Create Info.plist with Drag-and-Drop and LSUIElement support
    bundle_id="com.dock-folders.$(echo "$folder_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
    cat <<PLIST > "$app_path/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>DockFolder</string>
    <key>CFBundleIdentifier</key>
    <string>$bundle_id</string>
    <key>CFBundleName</key>
    <string>$folder_name</string>
    <key>CFBundleDisplayName</key>
    <string>$folder_name</string>
    <key>CFBundleIconFile</key>
    <string>applet.icns</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0</string>
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
            <string>Alternate</string>
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

    # 4. Ad-hoc code sign for macOS TCC
    echo "  🔏 Code-signing application bundle..."
    xattr -cr "$app_path" 2>/dev/null || true
    codesign --force --sign - "$app_path" 2>&1 >/dev/null || true
    touch "$app_path"

    # 5. Optional Dock pinning
    if $ADD_TO_DOCK; then
        echo "  📌 Pinning to macOS Dock..."
        pin_to_dock "$app_path"
    fi

    echo "  🎉 Successfully created: $app_path"
    echo ""
done

if $ADD_TO_DOCK; then
    killall Dock 2>/dev/null || true
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✨ Build Complete!"
echo "📍 Location: $OUTPUT_DIR"
if ! $ADD_TO_DOCK; then
    echo "💡 Drag the generated .app files into your macOS Dock."
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
