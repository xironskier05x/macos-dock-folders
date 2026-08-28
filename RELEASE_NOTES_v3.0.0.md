# macOS Dock Folders 3.0.0 — Dock Folders Manager & Visual Grid

**macOS Dock Folders 3.0.0** is a major release introducing **Dock Folders Manager.app** — a full native SwiftUI desktop application for creating, customizing, and organizing interactive macOS Dock launcher drawers and folder browsers without Terminal — alongside a **Visual Grid Presentation Mode** and **Managed Launcher Collections**.

---

## 🌟 Highlights

### 🖥️ Dock Folders Manager.app
- **Modern Desktop GUI**: Clean `NavigationSplitView` interface featuring tile lists, live menu/grid presentation previews, customizable SF Symbols/colors/folder icon rendering, and settings inspector.
- **Visual Launcher Creation & Editing**: Create new launcher drawers and folder browsers visually. Drag and drop apps, documents, folders, or scripts directly into launcher collections, reorder with drag-and-drop, and manage items safely.
- **Transactional Lifecycle & Renaming**: In-place edits, renames, and Dock pinning execute transactionally with automatic rollback on any failure.
- **P0 Overwrite Protection**: Foreign applications (without `DockFoldersGenerated = true`) are never overwritten; naming collisions trigger deterministic disambiguation or safe collision warnings.
- **Zero CLI Dependencies for End Users**: Bundles a precompiled universal `DockFolderRuntime`, eliminating the need for Xcode Command Line Tools.

### 📱 Visual Grid Presentation Mode
- **Dock-Adjacent Floating App Grid**: Launchers can open as an app grid beside your Dock with real high-resolution application icons.
- **Bounded Large-Directory Performance**: High-performance loading maps directories with 1,000+ files in milliseconds without synchronous disk I/O freezes.
- **Full Keyboard Navigation**: Full arrow-key selection, Escape dismissal, Return launch, and automatic dismissal on click-outside.

### 📁 Managed Virtual Launcher Collections & 2.x Migration
- **Managed Collections**: Virtual collections stored safely under `~/Library/Application Support/macOS Dock Folders/Collections/` as symlinks. Removing items from a collection never deletes original applications or files.
- **Legacy 2.x Discovery & Safe Migration**: Discovers existing 2.x launchers from `~/Applications/Dock Folders/` in read-only mode, providing one-click transactional conversion into managed collections.

---

## 📦 Compatibility & Technical Specifications

| Specification | Detail |
| :--- | :--- |
| **Minimum OS** | macOS 13.0+ (Ventura, Sonoma, Sequoia) |
| **Architectures** | Universal Fat Binaries (`arm64` Apple Silicon + `x86_64` Intel) |
| **Runtime CI Status** | Apple Silicon execution fully tested and green on CI; `x86_64` slice is build-verified via `lipo` |
| **Code Signing** | Ad-hoc codesigned (`codesign --verify --deep --strict` passing) |
| **Privacy & Security** | 100% Offline, Zero Telemetry, Sandboxed URL bookmarks |
| **Asset SHA-256** | `d14f8fcd7c011a37003cbc7cc1ebe9036f0e1258035a46aa8a3a93b6e8f66325` |

---

## 📥 Installation

1. Download **`Dock-Folders-Manager-v3.0.0.zip`** from the release assets below.
2. Unzip the archive and move **`Dock Folders Manager.app`** to `/Applications` or `~/Applications`.
3. Launch **Dock Folders Manager** to visually create and pin your first Dock launcher!
