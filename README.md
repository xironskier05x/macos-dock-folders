# macOS Dock Folders 🚀

[![CI Tests](https://github.com/xironskier05x/macos-dock-folders/actions/workflows/test.yml/badge.svg)](https://github.com/xironskier05x/macos-dock-folders/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/badge/Release-v2.1.1-green.svg)](https://github.com/xironskier05x/macos-dock-folders/releases/tag/v2.1.1)

Turn any folder into a **high-performance, clickable Dock launcher** with native popup menus, lazy-loaded submenus, persistent URL bookmark self-healing, macOS document package recognition, drag-and-drop support, SF Symbols styling, and modifier-key actions.

---

## 🌟 Core Architecture & Key Features

- ⚡ **Universal Native Swift Engine**: Uses a single cached native runtime binary (`DockFolderRuntime`). Zero per-folder Swift source generation or code injection risks.
- 📂 **Two-Phase Fast Loading & Lazy Submenus**: Metadata is harvested and sorted instantly; AppKit icons are rendered *only* for visible entries (capped at 100 per level). Deep subdirectories populate on-demand via `NSMenuDelegate` when hovered.
- 🧭 **Persistent URL Bookmark Self-Healing**: Target directories are tracked via macOS Base64 URL Bookmarks stored in `config.json` with mutable state in `~/Library/Application Support/macOS Dock Folders/`. If you rename or move the folder, the launcher re-resolves automatically.
- 📦 **macOS Document Package Recognition**: Respects `.isPackage` flags. Complex document bundles (`.pages`, `.numbers`, `.key`, `.rtfd`) open as single files rather than expanding into directory submenus.
- 🔗 **Finder Alias & Symlink Resolution**: Resolves target icons, file types, and applications for `.alias` files.
- 📥 **Two Dedicated Tile Modes**:
  - **Folder Mode (`--mode folder`)**: Standard directory browser. Dropping files copies them into the target folder with collision-safe naming (`file 1.ext`).
  - **Launcher Mode (`--mode launcher`)**: Virtual shortcut drawer. Dropping any item (applications, folders, PDFs, scripts, documents) creates a lightweight symbolic reference without duplicating physical files.
- 🛡️ **Safe Overwrites & Multi-Collision Protection**:
  - Validates `DockFoldersGenerated` marker before replacing existing `.app` bundles to avoid overwriting unrelated applications (unless `--force` is passed).
  - Deterministic unique bundle identifiers (`com.macosdockfolders.tile.<hash>`) and multi-level naming fallback (`Tools.app` → `Tools (Parent).app` → `Tools [hash].app`).
- ⌥ **Modifier Key Shortcuts**:
  - **Click / Enter**: Open selected item.
  - **⌥ Option + Click**: Reveal selected item in Finder.
  - **⌘1 – ⌘9**: Quick-launch top 9 items via keyboard.
  - **⌘O**: Show root folder in Finder.
  - **⌘T**: Open root folder in Terminal.
- 🎨 **SF Symbols & Custom Icons**: Generate custom icons on-the-fly using any Apple SF Symbol (`--symbol <name>`) and color palette (`--color <hex/preset>`).
- 🔕 **Clean System Integration**: `LSHandlerRank` is set to `None` so generated tiles do not pollute macOS "Open With" contextual menus.
- 🔒 **100% Offline & Private**: Zero telemetry, zero analytics, zero network requests.

---

## 📋 Requirements & Compatibility

- **Operating System**: macOS 12.0 (Monterey) or later (Apple Silicon & Intel).
- **Compiler**: Xcode Command Line Tools (`swiftc`). Install with:
  ```bash
  xcode-select --install
  ```

---

## 📦 Installation & Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/xironskier05x/macos-dock-folders.git
   cd macos-dock-folders
   ```

2. **Make the script executable:**
   ```bash
   chmod +x dock-folders.sh tests/run_tests.sh
   ```

---

## 🚀 Usage Guide

### 1. Basic Folder Launcher
```bash
./dock-folders.sh ~/Documents/Coding
```
*Generated apps default to `~/Applications/Dock Folders/`.*

### 2. Virtual App Drawer (Launcher Mode)
Create a virtual drawer for your favorite tools without moving their original locations:
```bash
./dock-folders.sh --mode launcher --symbol "sparkles" --color purple ~/Applications/AI_Apps
```

### 3. Custom SF Symbols & Colors
```bash
./dock-folders.sh --symbol "terminal.fill" --color dark ~/Developer/Projects
./dock-folders.sh --symbol "music.note" --color blue ~/Music
./dock-folders.sh --symbol "wrench.and.screwdriver" --color orange ~/Utilities
```

### 4. Batch Mode & Auto-Pin to Dock
```bash
./dock-folders.sh --all ~/Documents/DockFolders --add-to-dock
```

---

## 🛠️ CLI Options Reference

| Option | Description | Default |
|---|---|---|
| `--output-dir <path>` | Directory where `.app` bundles are placed | `~/Applications/Dock Folders` |
| `--all <dir>` | Process all immediate subdirectories in `<dir>` | — |
| `--mode <folder\|launcher>` | Tile mode: directory browser (`folder`) or shortcut drawer (`launcher`) | `folder` |
| `--symbol <name>` | Apple SF Symbol name (e.g. `folder.badge.gear`, `terminal.fill`) | Folder icon |
| `--color <color>` | Background color: preset (`blue`, `purple`, `green`, `orange`, `red`, `dark`, etc.) or hex (`#007AFF`) | `dark` |
| `--image <path>` | Custom PNG/JPEG/ICNS file to use as icon | — |
| `--sort <mode>` | Sorting order: `name` (A–Z), `recent` (Date Modified), `kind` (Apps > Folders > Files) | `name` |
| `--max-depth <n>` | Submenu nesting depth limit [0..10] | `3` |
| `--add-to-dock` | Automatically pin the generated `.app` to your macOS Dock (idempotent) | `false` |
| `--force` | Allow overwriting existing apps not created by Dock Folders | `false` |
| `-h, --help` | Show help message | — |

---

## 🧪 Automated Testing & CI

The repository contains a comprehensive regression test suite in [`tests/run_tests.sh`](tests/run_tests.sh) with **13 test suites / 16 assertions**:
- Special character names (quotes, ampersands, angle brackets, emojis).
- 3-way same-named folder collisions across hierarchies.
- Safe overwrite blocking & `--force`.
- CLI argument validation.
- `LSHandlerRank = None` verification.
- Fail-closed behavior on corrupted configuration.
- Two-phase icon loading & submenu-level capping (500 items).
- True LaunchServices drop verification for Launcher Mode (symlinks) and Folder Mode (file copies).
- Launcher-mode duplicate collision handling.
- Reconcile / clear stale repaired state on rebuild.
- Strict ad-hoc codesigning verification.

Run the test suite locally:
```bash
./tests/run_tests.sh
```

---

## 📄 Attribution & License

- Original concept and inspiration: [`sil-so/macos-dock-folders`](https://github.com/sil-so/macos-dock-folders).
- 2.x native Swift Cocoa engine, two-phase icon loading, lazy submenus, bookmark self-healing, and security hardening by Evan.
- Licensed under the [MIT License](LICENSE).
