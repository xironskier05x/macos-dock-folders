# macOS Dock Folders 3.0 🚀

[![CI Tests](https://github.com/xironskier05x/macos-dock-folders/actions/workflows/test.yml/badge.svg)](https://github.com/xironskier05x/macos-dock-folders/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-v3.0.0--RC-orange.svg)](https://github.com/xironskier05x/macos-dock-folders)
[![Platform](https://img.shields.io/badge/macOS-13.0%2B%20%28Universal%20arm64%20%2B%20x86__64%29-brightgreen.svg)]()

Transform any folder or collection into a **high-performance, clickable macOS Dock launcher** with native List Menus, visual App Grids, drag-and-drop management, persistent URL bookmark self-healing, SF Symbols styling, and an intuitive native desktop GUI.

---

## 🌟 What's New in 3.0

- 🖥️ **Dock Folders Manager.app**: Full native SwiftUI desktop application for creating, managing, editing, reordering, and pinning Dock Folders visually without Terminal.
- 📱 **Visual Grid Presentation Mode**: Launchers can open as a floating app-grid beside your Dock with real app icons, type-to-filter search, full arrow key navigation, and automatic dismissal on click-outside.
- 📂 **True Managed Launcher Collections**: Stable `collectionID` architecture storing virtual references under `~/Library/Application Support/macOS Dock Folders/Collections/<collectionID>/`. Original source files and applications are never moved, modified, or deleted.
- 🎨 **Visual Icon & SF Symbol Editor**: Live preview thumbnail, SF Symbol search filter and validation, Apple preset/hex color palettes, custom image support, and emoji integration.
- 🔄 **Safe 2.x Legacy Discovery & Explicit Conversion**: Discovers existing 2.x tiles without creating extraneous collections, providing an explicit non-destructive "Convert to Managed Collection…" migration action.
- ⚡ **Universal Binary Architecture**: Both `Dock Folders Manager.app` and `DockFolderRuntime` are compiled as fat universal binaries supporting Apple Silicon (`arm64`) and Intel (`x86_64`) on macOS 13.0+.
- 🛡️ **Hardened Safety & Strict Code Signing**: Full overwrite verification (`DockFoldersGenerated` checking), 3-level deterministic collision disambiguation, path containment checking, and transactional staging/backup/rollback.

---

## 🛠️ Architecture Overview

```text
DockFolders/
├── App/
│   ├── DockFoldersApp.swift            # SwiftUI @main App scene with Menu commands & shortcuts
│   └── AppDelegate.swift               # AppKit NSApplicationDelegate regular activation policy
├── Models/
│   ├── DockTile.swift                  # Observable Tile model, memory state & publication
│   ├── DockTileConfig.swift            # Backwards-compatible JSON config with collectionID
│   ├── LauncherItem.swift              # Lightweight individual item metadata & icons
│   ├── TileMode.swift                  # TileMode enum (.folder, .launcher)
│   ├── PresentationMode.swift          # PresentationMode enum (.menu, .grid)
│   ├── SortMode.swift                  # SortMode enum (.name, .recent, .kind, .custom)
│   └── IconConfiguration.swift         # Icon styling (Symbol, Color, Emoji, Image, Folder)
├── Stores/
│   ├── TileStore.swift                 # Reactive collection store managing CRUD & update transactions
│   ├── SelectionStore.swift            # Active sidebar selection and sheet state
│   └── PreferencesStore.swift          # AppStorage persistent user defaults & directory paths
├── Services/
│   ├── TileDiscoveryService.swift      # Scans ~/Applications/Dock Folders/ for 2.x & 3.0 tiles
│   ├── TileGeneratorService.swift      # Generates, signs, and replaces .app bundles safely
│   ├── DockService.swift               # Exact canonical Dock pinning, removal, and live status
│   ├── LauncherCollectionService.swift # Manages virtual collections & symbolic references
│   ├── BookmarkService.swift           # Base64 URL security-scoped / minimal bookmarks
│   ├── IconRendererService.swift       # 1024x1024 .icns iconset generator & live renderer
│   └── RuntimeInstallerService.swift   # Embedded universal runtime binary resolver
├── Views/
│   ├── Sidebar/                        # Tile list & filter search
│   ├── Detail/                         # Large icon preview, metadata, actions, items list
│   ├── Editor/                         # Visual Creation & Edit sheet with mode switchers
│   ├── Preview/                        # Live Menu & Grid presentation preview
│   └── Settings/                       # Preferences & defaults
└── Runtime/
    ├── DockFolderRuntime.swift         # Universal one-shot runtime supporting Menu & Grid
    ├── GridLauncherView.swift          # Native SwiftUI Grid popup view with keyboard navigation
    └── GridLauncherWindow.swift        # Floating NSPanel positioned near Dock with dismissal lifecycle
```

---

## ⌨️ Shortcuts & Keyboard Controls

### In Grid Presentation:
- **Arrow Keys (Left/Right/Up/Down)**: Navigate items across grid columns
- **Enter / Return**: Launch selected item
- **Escape / Click Outside**: Close panel and terminate runtime
- **Type text**: Instant type-to-filter search (search field focused automatically)
- **Right-Click / Context Menu**: Open or Reveal original item in Finder

### In Menu Presentation:
- **Click / Enter**: Open selected item
- **⌥ Option + Click**: Reveal selected item in Finder
- **⌘1 – ⌘9**: Quick-launch top 9 items
- **⌘O**: Show root folder in Finder
- **⌘T**: Open root folder in Terminal

---

## 📦 Building & Running

### Using the Manager App:
Build, package, and launch `Dock Folders Manager.app` as a universal binary:
```bash
./script/build_and_run.sh
```

### Using the CLI (`dock-folders.sh`):
The command line tool remains fully supported:
```bash
# Create a Grid Launcher for AI Apps with custom symbol and color
./dock-folders.sh --mode launcher --presentation grid --symbol "sparkles" --color purple ~/Applications/AI_Apps

# Create a Menu Folder launcher for developer projects
./dock-folders.sh --symbol "terminal.fill" --color dark ~/Developer/Projects --add-to-dock
```

---

## 🧪 Testing & Validation

Run the 20-suite comprehensive verification test suite:
```bash
./tests/run_tests.sh
```

All tests run automatically on GitHub Actions on every push/PR on `macos-latest`.

---

## 📄 Attribution & License

- Original concept inspired by [`sil-so/macos-dock-folders`](https://github.com/sil-so/macos-dock-folders).
- 3.0 Native GUI Manager, Grid Launcher, Two-Phase Loading, and Security Hardening by Evan.
- Licensed under the [MIT License](LICENSE).
