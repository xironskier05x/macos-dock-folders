# macOS Dock Folders 3.0 🚀

[![CI Tests](https://github.com/xironskier05x/macos-dock-folders/actions/workflows/test.yml/badge.svg)](https://github.com/xironskier05x/macos-dock-folders/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/badge/Release-v3.0.0-green.svg)](https://github.com/xironskier05x/macos-dock-folders/releases)

Transform any folder or collection into a **high-performance, clickable macOS Dock launcher** with native List Menus, visual App Grids, drag-and-drop management, persistent URL bookmark self-healing, SF Symbols styling, and an intuitive native desktop GUI.

---

## 🌟 What's New in 3.0

- 🖥️ **Dock Folders Manager.app**: Full native SwiftUI desktop application for creating, managing, editing, reordering, and pinning Dock Folders visually.
- 📱 **Visual Grid Presentation Mode**: Launchers can now open as a sleek floating app-grid beside your Dock with real app icons, type-to-filter search, and arrow key navigation.
- 📂 **Managed Launcher Collections**: Drag applications, documents, folders, or scripts directly into launcher collections in Manager. Originals remain safe and untouched in their original locations.
- 🎨 **Visual Icon & SF Symbol Editor**: Live preview thumbnail, SF Symbol search picker, Apple color palette, custom image support, and emoji integration.
- 🧭 **Zero-Terminal End-User Workflow**: Manager embeds a precompiled universal `DockFolderRuntime`, allowing users to create tiles without installing developer tools.
- 🔄 **2.x Backwards Compatibility**: Automatically discovers existing 2.x tiles in `~/Applications/Dock Folders/` and applies safe in-memory defaults.

---

## 🛠️ Architecture Overview

```text
DockFolders/
├── App/
│   ├── DockFoldersApp.swift       # SwiftUI App entry point
│   └── AppDelegate.swift          # AppKit regular activation policy
├── Models/
│   ├── DockTile.swift             # Main Tile model & state
│   ├── DockTileConfig.swift       # Backwards-compatible JSON config
│   ├── LauncherItem.swift         # Individual launcher item metadata
│   ├── TileMode.swift             # Folder vs Launcher mode
│   ├── PresentationMode.swift     # Menu vs Grid presentation
│   ├── SortMode.swift             # Name, Recent, Kind, Custom
│   └── IconConfiguration.swift    # Symbol, Color, Emoji, Image
├── Stores/
│   ├── TileStore.swift            # Observable tile collection & disk sync
│   ├── SelectionStore.swift       # Active selection and UI sheets
│   └── PreferencesStore.swift     # User defaults & directory paths
├── Services/
│   ├── TileDiscoveryService.swift # Scans & loads 2.x and 3.0 launchers
│   ├── TileGeneratorService.swift # Generates .app, Info.plist, codesigns
│   ├── DockService.swift          # Idempotent Dock pinning & status
│   ├── LauncherCollectionService.swift # Virtual collection management
│   ├── BookmarkService.swift      # URL bookmark generation/resolution
│   ├── IconRendererService.swift  # 1024x1024 .icns & preview rendering
│   └── RuntimeInstallerService.swift # Embedded universal runtime loader
├── Views/
│   ├── Sidebar/                   # Tile list & filter search
│   ├── Detail/                    # Large icon preview, metadata & actions
│   ├── Editor/                    # Creation sheet, items editor, icon picker
│   ├── Preview/                   # Live Menu & Grid presentation preview
│   └── Settings/                  # Preferences & defaults
└── Runtime/
    ├── DockFolderRuntime.swift    # Standalone lightweight tile engine
    ├── GridLauncherView.swift     # SwiftUI Grid launcher popup view
    └── GridLauncherWindow.swift   # Floating NSPanel positioned near Dock
```

---

## 📥 Tile & Presentation Modes

### 1. Tile Modes
- **Launcher Mode (`--mode launcher`)**: A virtual shortcut collection for apps, documents, scripts, and directories. Dropping items creates lightweight references without duplicating files.
- **Folder Mode (`--mode folder`)**: A directory browser. Dropping items copies them physically into the destination folder.

### 2. Presentation Modes
- **List Menu (`--presentation menu`)**: Native macOS hierarchical popup menu with instant subfolder navigation and two-phase icon loading.
- **Icon Grid (`--presentation grid`)**: Modern floating panel with search filter, keyboard navigation, configurable columns (4–7), and instant dismissal.

---

## ⌨️ Shortcuts & Keyboard Controls

### In Grid Presentation:
- **Arrow Keys**: Navigate items
- **Enter / Return**: Launch selected item
- **Escape**: Close panel
- **Type text**: Filter items instantly

### In Menu Presentation:
- **Click / Enter**: Open selected item
- **⌥ Option + Click**: Reveal in Finder
- **⌘1 – ⌘9**: Quick-launch top 9 items
- **⌘O**: Show root folder in Finder
- **⌘T**: Open root folder in Terminal

---

## 📦 Building & Running

### Using the Manager App:
Build, package, and launch `Dock Folders Manager.app`:
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

Run the 17-suite / 20-assertion test suite:
```bash
./tests/run_tests.sh
```

All tests run automatically on GitHub Actions on every push/PR on `macos-latest`.

---

## 📄 Attribution & License

- Original concept inspired by [`sil-so/macos-dock-folders`](https://github.com/sil-so/macos-dock-folders).
- 3.0 Native GUI Manager, Grid Launcher, Two-Phase Loading, and Security Hardening by Evan.
- Licensed under the [MIT License](LICENSE).
