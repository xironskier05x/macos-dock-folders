# Changelog

All notable changes to **macOS Dock Folders** are documented in this file.

## [3.0.0-rc1] - 2026-08-28 (Release Candidate 1)

### 🖥️ Dock Folders Manager.app
- **Native SwiftUI Desktop App**: Built a modern macOS Manager application featuring `NavigationSplitView`, native sidebar, live presentation previews, custom icon pickers, and settings inspector.
- **Visual Creation Sheet**: Create new Launcher drawers and Folder browsers visually without opening Terminal.
- **Visual Launcher Item Editor**: Drag and drop apps, documents, folders, or scripts directly into launcher collections, reorder with drag-and-drop, and remove items without touching source files.
- **Discovery & 2.x Backwards Compatibility**: Automatically discovers existing 2.x and 3.0 tiles from `~/Applications/Dock Folders/`, applying safe defaults in memory without destructive migration.
- **Native Dock Integration**: Single-click "Add to Dock" and "Remove from Dock" operations with live status detection.
- **Zero CLI Dependencies for End Users**: Manager bundles a precompiled universal `DockFolderRuntime`, eliminating the need for Xcode Command Line Tools.

### 📱 Visual Grid Presentation Mode
- **Icon Grid Presentation (`--presentation grid`)**: Clicking a Dock tile opens a floating panel positioned beside the clicked Dock icon featuring real app icons, search filtering, and keyboard navigation.
- **Custom Item Ordering (`sortMode: custom`)**: Maintain custom item sequences across re-launches.
- **Keyboard Navigation & Type-to-Filter**: Arrow key selection, Return to launch, Esc / click-outside to dismiss, and instant search bar.

### 📦 Packaging & Distribution
- **Packaged App & Distribution Artifacts**: Created `script/build_and_run.sh` to package `dist/Dock Folders Manager.app` and `dist/Dock-Folders-Manager-v3.0.0.zip`.
- **Environment Configuration**: Added `.codex/environments/environment.toml` for standard runtime automation.

---

## [2.1.1] - 2026-08-27 (Stable Core Engine Baseline)

### ⚡ Performance & Core Architecture
- **Two-Phase Fast Loading**: Separated metadata harvesting from AppKit icon lookups. Capped each menu level at 100 entries, invoking `NSWorkspace.shared.icon(forFile:)` exclusively for visible items to maintain instant popup times on massive directories.
- **Submenu-Level Capping**: Extended 100-item safety limits across all submenu depths with nested-folder-specific `"Show All in Finder…"` actions.
- **Universal Precompiled Runtime**: Replaced per-folder Swift generation with cached native Swift binary (`DockFolderRuntime`).

### 🛡️ Safety & Integrity
- **Fail-Closed Configuration**: Missing or damaged bundle configurations exit immediately with an error rather than falling back to `$HOME`.
- **External State Isolation**: Mutable repaired folder paths and bookmarks are saved to `~/Library/Application Support/macOS Dock Folders/<bundle-id>/repaired_state.json`.
- **Rebuild Reconciliation**: Explicitly rebuilding a launcher clears stale repair states.
- **Multi-Collision Resolution**: Deterministic fallback naming (`Tools.app` → `Tools (Parent).app` → `Tools [hash].app`).
