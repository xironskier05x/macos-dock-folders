#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"
BUILD_DIR="$SCRIPT_DIR/build"
APP_NAME="Dock Folders Manager"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
ZIP_ARTIFACT="$DIST_DIR/Dock-Folders-Manager-v3.0.0.zip"
LOG_FILE="$BUILD_DIR/build.log"

VERIFY_ONLY=false
SHOW_LOGS=false
NO_LAUNCH=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --verify)
            VERIFY_ONLY=true; shift ;;
        --logs)
            SHOW_LOGS=true; shift ;;
        --no-launch)
            NO_LAUNCH=true; shift ;;
        -h|--help)
            echo "Usage: ./script/build_and_run.sh [--verify] [--logs] [--no-launch]"; exit 0 ;;
        *)
            echo "Error: Unknown option '$1'"; exit 1 ;;
    esac
done

mkdir -p "$DIST_DIR" "$BUILD_DIR"
exec 3>&1 4>&2
if $SHOW_LOGS; then
    exec 1> >(tee -a "$LOG_FILE") 2> >(tee -a "$LOG_FILE" >&2)
fi

echo "🔨 Building macOS Dock Folders 3.0 (Universal Binary: arm64 + x86_64, macOS 13.0+)"
echo "──────────────────────────────────────────────────────────────────────────────"

# 1. Terminate existing Manager process if running
killall "$APP_NAME" 2>/dev/null || true

# 2. Compile standalone universal DockFolderRuntime
echo "⚙ Compiling universal DockFolderRuntime 3.0..."
RUNTIME_SOURCES=(
    "$SCRIPT_DIR/DockFolders/Runtime/DockFolderRuntime.swift"
    "$SCRIPT_DIR/DockFolders/Runtime/GridLauncherView.swift"
    "$SCRIPT_DIR/DockFolders/Runtime/GridLauncherWindow.swift"
    "$SCRIPT_DIR/DockFolders/Models/LauncherItem.swift"
)

swiftc -target arm64-apple-macos13.0 -O -o "$BUILD_DIR/DockFolderRuntime_arm64" "${RUNTIME_SOURCES[@]}"
swiftc -target x86_64-apple-macos13.0 -O -o "$BUILD_DIR/DockFolderRuntime_x86_64" "${RUNTIME_SOURCES[@]}"
lipo -create "$BUILD_DIR/DockFolderRuntime_arm64" "$BUILD_DIR/DockFolderRuntime_x86_64" -output "$BUILD_DIR/DockFolderRuntime"

mkdir -p "$SCRIPT_DIR/src"
cp "$BUILD_DIR/DockFolderRuntime" "$SCRIPT_DIR/src/DockFolderRuntime"

# 3. Compile universal Dock Folders Manager App Binary
echo "⚙ Compiling universal $APP_NAME..."
SWIFT_SOURCES=(
    "$SCRIPT_DIR/DockFolders/Support/Logging.swift"
    "$SCRIPT_DIR/DockFolders/Support/FileHelpers.swift"
    "$SCRIPT_DIR/DockFolders/Models/TileMode.swift"
    "$SCRIPT_DIR/DockFolders/Models/PresentationMode.swift"
    "$SCRIPT_DIR/DockFolders/Models/SortMode.swift"
    "$SCRIPT_DIR/DockFolders/Models/IconConfiguration.swift"
    "$SCRIPT_DIR/DockFolders/Models/LauncherItem.swift"
    "$SCRIPT_DIR/DockFolders/Models/DockTileConfig.swift"
    "$SCRIPT_DIR/DockFolders/Models/DockTile.swift"
    "$SCRIPT_DIR/DockFolders/Services/BookmarkService.swift"
    "$SCRIPT_DIR/DockFolders/Services/IconRendererService.swift"
    "$SCRIPT_DIR/DockFolders/Services/LauncherCollectionService.swift"
    "$SCRIPT_DIR/DockFolders/Services/DockService.swift"
    "$SCRIPT_DIR/DockFolders/Services/RuntimeInstallerService.swift"
    "$SCRIPT_DIR/DockFolders/Services/TileDiscoveryService.swift"
    "$SCRIPT_DIR/DockFolders/Services/TileGeneratorService.swift"
    "$SCRIPT_DIR/DockFolders/Stores/PreferencesStore.swift"
    "$SCRIPT_DIR/DockFolders/Stores/SelectionStore.swift"
    "$SCRIPT_DIR/DockFolders/Stores/TileStore.swift"
    "$SCRIPT_DIR/DockFolders/Views/Sidebar/TileSidebarRow.swift"
    "$SCRIPT_DIR/DockFolders/Views/Sidebar/TileSidebarView.swift"
    "$SCRIPT_DIR/DockFolders/Views/Editor/ColorPickerSection.swift"
    "$SCRIPT_DIR/DockFolders/Views/Editor/SymbolPickerView.swift"
    "$SCRIPT_DIR/DockFolders/Views/Editor/IconPickerView.swift"
    "$SCRIPT_DIR/DockFolders/Views/Editor/FolderSettingsEditor.swift"
    "$SCRIPT_DIR/DockFolders/Views/Editor/LauncherItemsEditor.swift"
    "$SCRIPT_DIR/DockFolders/Views/Editor/TileEditorView.swift"
    "$SCRIPT_DIR/DockFolders/Views/Preview/GridLauncherPreview.swift"
    "$SCRIPT_DIR/DockFolders/Views/Preview/MenuLauncherPreview.swift"
    "$SCRIPT_DIR/DockFolders/Views/Preview/TilePreviewView.swift"
    "$SCRIPT_DIR/DockFolders/Views/Detail/TileEmptyStateView.swift"
    "$SCRIPT_DIR/DockFolders/Views/Detail/TileDetailView.swift"
    "$SCRIPT_DIR/DockFolders/Views/Settings/SettingsView.swift"
    "$SCRIPT_DIR/DockFolders/Views/ContentView.swift"
    "$SCRIPT_DIR/DockFolders/App/AppDelegate.swift"
    "$SCRIPT_DIR/DockFolders/App/DockFoldersApp.swift"
)

swiftc -target arm64-apple-macos13.0 -O -o "$BUILD_DIR/DockFoldersManager_arm64" "${SWIFT_SOURCES[@]}"
swiftc -target x86_64-apple-macos13.0 -O -o "$BUILD_DIR/DockFoldersManager_x86_64" "${SWIFT_SOURCES[@]}"
lipo -create "$BUILD_DIR/DockFoldersManager_arm64" "$BUILD_DIR/DockFoldersManager_x86_64" -output "$BUILD_DIR/DockFoldersManager"

# Verify universal architectures
echo "🔍 Verifying universal architectures with lipo..."
lipo -info "$BUILD_DIR/DockFolderRuntime"
lipo -info "$BUILD_DIR/DockFoldersManager"

# 4. Package .app bundle structure
echo "📦 Packaging $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/DockFoldersManager" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$BUILD_DIR/DockFolderRuntime" "$APP_BUNDLE/Contents/Resources/DockFolderRuntime"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME" "$APP_BUNDLE/Contents/Resources/DockFolderRuntime"

# Generate Manager app icon
swift -e '
import Cocoa
let size: CGFloat = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
), let ctx = NSGraphicsContext(bitmapImageRep: rep) else { exit(1) }
NSGraphicsContext.current = ctx

let rect = NSRect(x: 0, y: 0, width: size, height: size)
let path = NSBezierPath(roundedRect: rect, xRadius: 220, yRadius: 220)
NSColor(calibratedRed: 0.0, green: 0.478, blue: 1.0, alpha: 1.0).setFill()
path.fill()

if let sym = NSImage(systemSymbolName: "square.grid.2x2.fill", accessibilityDescription: nil) {
    let conf = NSImage.SymbolConfiguration(pointSize: 520, weight: .medium).applying(.init(paletteColors: [.white]))
    let configured = sym.withSymbolConfiguration(conf) ?? sym
    let symSize = configured.size
    let drawRect = NSRect(x: (size - symSize.width) / 2, y: (size - symSize.height) / 2, width: symSize.width, height: symSize.height)
    configured.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
}
NSGraphicsContext.current = nil
if let pngData = rep.representation(using: .png, properties: [:]) {
    try? pngData.write(to: URL(fileURLWithPath: "'"$BUILD_DIR"'/manager_icon.png"))
}
'

mkdir -p "$BUILD_DIR/manager.iconset"
sips -z 16 16     "$BUILD_DIR/manager_icon.png" --out "$BUILD_DIR/manager.iconset/icon_16x16.png"      >/dev/null 2>&1
sips -z 32 32     "$BUILD_DIR/manager_icon.png" --out "$BUILD_DIR/manager.iconset/icon_16x16@2x.png"   >/dev/null 2>&1
sips -z 32 32     "$BUILD_DIR/manager_icon.png" --out "$BUILD_DIR/manager.iconset/icon_32x32.png"      >/dev/null 2>&1
sips -z 64 64     "$BUILD_DIR/manager_icon.png" --out "$BUILD_DIR/manager.iconset/icon_32x32@2x.png"   >/dev/null 2>&1
sips -z 128 128   "$BUILD_DIR/manager_icon.png" --out "$BUILD_DIR/manager.iconset/icon_128x128.png"    >/dev/null 2>&1
sips -z 256 256   "$BUILD_DIR/manager_icon.png" --out "$BUILD_DIR/manager.iconset/icon_128x128@2x.png" >/dev/null 2>&1
sips -z 256 256   "$BUILD_DIR/manager_icon.png" --out "$BUILD_DIR/manager.iconset/icon_256x256.png"    >/dev/null 2>&1
sips -z 512 512   "$BUILD_DIR/manager_icon.png" --out "$BUILD_DIR/manager.iconset/icon_256x256@2x.png" >/dev/null 2>&1
sips -z 512 512   "$BUILD_DIR/manager_icon.png" --out "$BUILD_DIR/manager.iconset/icon_512x512.png"    >/dev/null 2>&1
sips -z 1024 1024 "$BUILD_DIR/manager_icon.png" --out "$BUILD_DIR/manager.iconset/icon_512x512@2x.png" >/dev/null 2>&1
iconutil -c icns "$BUILD_DIR/manager.iconset" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null || true

# Info.plist with macOS 13+ deployment requirement
cat << 'PLIST' > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Dock Folders Manager</string>
    <key>CFBundleIdentifier</key>
    <string>com.macosdockfolders.manager</string>
    <key>CFBundleName</key>
    <string>Dock Folders Manager</string>
    <key>CFBundleDisplayName</key>
    <string>Dock Folders Manager</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>3.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# 5. Ad-hoc codesign and strict verification
codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1
codesign --verify --deep --strict "$APP_BUNDLE"

# 6. Create Distribution ZIP Artifact
echo "🗜 Creating distributable ZIP: $ZIP_ARTIFACT..."
rm -f "$ZIP_ARTIFACT"
(cd "$DIST_DIR" && zip -q -r "$ZIP_ARTIFACT" "$APP_NAME.app")

echo "✅ Build Complete: $APP_BUNDLE"
echo "✅ Distributable ZIP: $ZIP_ARTIFACT"

if $VERIFY_ONLY; then
    exit 0
fi

if ! $NO_LAUNCH && [[ -z "${CI:-}" ]]; then
    echo "🚀 Launching $APP_NAME..."
    open "$APP_BUNDLE"
fi
