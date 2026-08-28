# macOS Dock Folders 2.1 🚀

Turn any folder into a **bulletproof, high-performance Dock launcher** with native popup menus, lazy-loaded submenus, persistent URL bookmark self-healing, package detection, drag-and-drop file moving, SF Symbols styling, modifier-key actions, and safe overwrite protection.

---

## 🌟 Architecture & Key Features

- ⚡ **Universal Native Swift Engine**: Compiles a single cached native runtime binary (`DockFolderRuntime`). No per-folder Swift source generation or code injection risks.
- 📂 **Instant Lazy-Loaded Submenus**: Enumerates top-level items immediately. Nested subdirectories are populated on-demand via `NSMenuDelegate` when hovered, preventing lag on huge directories (e.g. `node_modules`, deep repositories).
- 🧭 **Persistent URL Bookmark Self-Healing**: Target folders are tracked via macOS URL Bookmarks in addition to file paths. If you rename or move the target folder, the Dock launcher resolves its new location automatically.
- 📦 **macOS Document Package Protection**: Respects `.isPackage` flags. Complex document bundles (`.pages`, `.numbers`, `.key`, `.rtfd`) open as single files rather than expanding as directory submenus.
- 🔗 **Full Finder Alias & Symlink Resolution**: Resolves target icons, types, and apps for alias files seamlessly.
- 📥 **Two Tile Modes (`--mode folder` vs `--mode launcher`)**:
  - **Folder Mode** (default): Files dropped onto the Dock icon are copied into the folder.
  - **Launcher Mode**: Applications dropped onto the Dock icon create shortcuts/aliases without duplicating multi-gigabyte app bundles.
- 🛡️ **Safe Overwrite & Collision Protection**:
  - Validates `DockFoldersGenerated` marker before replacing existing `.app` bundles to avoid deleting unrelated apps (unless `--force` is passed).
  - Deterministic unique bundle identifiers (`com.macosdockfolders.tile.<hash>`) and name disambiguation for same-named folders (e.g. `Work/Tools` vs `Personal/Tools`).
- ⌥ **Modifier Key Shortcuts**:
  - **Click / Enter**: Open selected item.
  - **⌥ Option + Click**: Reveal selected item in Finder.
  - **⌘1 – ⌘9**: Quick-launch top 9 items via keyboard.
  - **⌘O**: Show root folder in Finder.
  - **⌘T**: Open root folder in Terminal.
- 🎨 **SF Symbols & Color Customizer**: Build custom branded icons using any Apple SF Symbol (`--symbol <name>`) and color palette (`--color <hex/preset>`).
- 🔕 **Clean System Integration**: `LSHandlerRank` is set to `None` so generated tiles do not pollute macOS "Open With" contextual menus.
- 🔒 **100% Offline & Private**: Zero telemetry, zero analytics, zero phoning home.

---

## 📋 Requirements

- **macOS**: 12.0 (Monterey) or later (Apple Silicon & Intel).
- **Xcode Command Line Tools** (for `swiftc`): Install with `xcode-select --install` if not already installed.

---

## 📦 Quick Start

### 1. Basic Folder Launcher
Generate a Dock app for a folder:
```bash
./dock-folders.sh ~/Documents/Coding
```
*Generated apps default to `~/Applications/Dock Folders/`.*

### 2. Virtual App Drawer (Launcher Mode)
Create a dedicated launcher for your favorite tools without moving their original files:
```bash
./dock-folders.sh --mode launcher --symbol "sparkles" --color purple ~/Applications/AI_Apps
```

### 3. Custom SF Symbols & Colors
```bash
./dock-folders.sh --symbol "terminal.fill" --color dark ~/Developer/Projects
./dock-folders.sh --symbol "music.note" --color blue ~/Music
./dock-folders.sh --symbol "wrench.and.screwdriver" --color orange ~/Utilities
```

### 4. Batch Mode
Generate launchers for **all** sub-folders in a directory:
```bash
./dock-folders.sh --all ~/Documents/DockFolders --add-to-dock
```

---

## 🛠️ CLI Options Reference

| Option | Description | Default |
|---|---|---|
| `--output-dir <path>` | Directory where `.app` bundles are saved | `~/Applications/Dock Folders` |
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

## 🧪 Automated Testing

A test suite is included in `tests/run_tests.sh` that validates:
- Special character handling in names (quotes, ampersands, angle brackets, emojis).
- Collision avoidance for identically named folders across different paths.
- Safe overwrite protection and `--force` behavior.
- Input validation on symbols, sort modes, and depth limits.
- `LSHandlerRank` configuration.
- URL Bookmark generation and config persistence.
- Strict ad-hoc codesign verification.

To run the suite:
```bash
./tests/run_tests.sh
```

---

## 📄 Attribution & License

- Original concept and inspiration: [`sil-so/macos-dock-folders`](https://github.com/sil-so/macos-dock-folders).
- 2.0+ architecture, Swift Cocoa engine, lazy-loading submenus, bookmark self-healing, and security hardening by Evan.
- Licensed under the [MIT License](LICENSE).
