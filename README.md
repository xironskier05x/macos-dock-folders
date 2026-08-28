# macOS Dock Folders 2.0 🚀

Turn any folder into a **high-performance, clickable Dock launcher** with native popup menus, hierarchical submenus, drag-and-drop file moving, SF Symbols icon styling, modifier-key actions, and 0ms startup lag.

---

## 🌟 What's New in 2.0

- ⚡ **Native Swift Cocoa Engine**: Replaces slow AppleScript with native compiled binaries for instantaneous (<10ms) menu popups.
- 📂 **Hierarchical Submenus**: Multi-level navigation for nested subfolders directly within the Dock popup.
- 📥 **Drag-and-Drop Drop Target**: Drag any file or folder onto the Dock icon to move/copy it straight into that directory.
- ⌥ **Modifier Key Shortcuts**:
  - **Click / Enter**: Open item.
  - **⌥ Option + Click**: Reveal item in Finder.
  - **⌘1 – ⌘9**: Quick-launch top items instantly from keyboard.
  - **⌘O**: Open root folder in Finder.
  - **⌘T**: Open root folder in Terminal.
- 🎨 **SF Symbols & Custom Icons**: Generate custom icons on-the-fly using any Apple SF Symbol, custom background colors, or existing folder emojis/icons.
- 🗂️ **Smart Sorting**: Sort alphabetically (`name`), by Date Modified (`recent`), or by Kind (`kind`: Apps > Folders > Files).
- 🧭 **Adaptive Dock Position**: Automatically detects whether your Dock is at the **Bottom**, **Left**, or **Right** of your screen and positions the menu properly.
- 📌 **Automatic Dock Pinning**: Optional `--add-to-dock` flag to automatically pin generated apps to your macOS Dock.
- 🔒 **100% Offline & Private**: Zero telemetry, zero analytics, zero phoning home.

---

## 📦 Quick Start

### 1. Basic Generation
Generate a Dock app for a single folder:
```bash
./dock-folders.sh ~/Documents/Coding
```

### 2. Batch Mode
Process **all** sub-folders in a directory:
```bash
./dock-folders.sh --all ~/Documents/DockFolders
```

### 3. Custom SF Symbols & Colors
Generate a custom branded icon with an SF Symbol and color palette:
```bash
./dock-folders.sh --symbol "terminal.fill" --color dark ~/Developer/Projects
./dock-folders.sh --symbol "music.note" --color purple ~/Music
./dock-folders.sh --symbol "wrench.and.screwdriver" --color orange ~/Utilities
```

### 4. Smart Sorting & Auto Dock Pinning
Sort items by most recently modified and pin directly to the Dock:
```bash
./dock-folders.sh --sort recent --add-to-dock ~/Downloads
```

---

## 🛠️ CLI Options

| Option | Description | Default |
|---|---|---|
| `--output-dir <path>` | Destination directory for `.app` bundles | `./build` |
| `--all <dir>` | Process all immediate subdirectories in `<dir>` | — |
| `--symbol <name>` | Apple SF Symbol name (e.g. `folder.badge.gear`, `terminal.fill`) | Folder icon |
| `--color <color>` | Background color: preset (`blue`, `purple`, `pink`, `red`, `orange`, `green`, `teal`, `dark`, etc.) or hex (`#007AFF`) | `dark` |
| `--image <path>` | Custom PNG/JPEG/ICNS file to use as icon | — |
| `--sort <mode>` | Sorting order: `name` (A–Z), `recent` (Date Modified), `kind` (Apps > Folders > Files) | `name` |
| `--max-depth <n>` | Maximum submenu nesting depth | `3` |
| `--add-to-dock` | Automatically pin the generated `.app` to your macOS Dock | `false` |
| `-h, --help` | Show help message | — |

---

## ⌨️ Keyboard & Mouse Controls

| Action | Result |
|---|---|
| **Left Click** / **Return** | Open file, app, or folder |
| **⌥ Option + Click** | Reveal selected item in Finder |
| **⌘1 – ⌘9** | Instant keyboard launch for items 1 through 9 |
| **⌘O** | Show root folder in Finder |
| **⌘T** | Open root folder in Terminal |
| **Drag & Drop** | Drag file(s) onto Dock icon to copy them into the folder |

---

## 🔒 Privacy & Security

This project contains **zero network calls, telemetry, or analytics**. Everything is compiled and run entirely on your local machine using macOS native tooling.

## 📄 License

[MIT](LICENSE)
