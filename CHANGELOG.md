# Changelog

All notable changes to **macOS Dock Folders** are documented in this file.

## [2.1.1] - 2026-08-27 (Stable Engine Release)

### ⚡ Performance & Core Architecture
- **Two-Phase Fast Loading**: Separated metadata harvesting from AppKit icon lookups. Capped each menu level at 100 entries, invoking `NSWorkspace.shared.icon(forFile:)` exclusively for visible items to maintain instant popup times on massive directories (e.g. 5,000+ item folders).
- **Submenu-Level Capping**: Extended 100-item safety limits across all submenu depths, adding a nested-folder-specific `"Show All in Finder… (N items)"` action.
- **Universal Precompiled Runtime**: Replaced per-folder Swift source generation with a single cached native Swift binary (`DockFolderRuntime`).

### 🛡️ Safety & Integrity
- **Fail-Closed Configuration**: Missing or damaged bundle configurations exit immediately with an error rather than falling back to `$HOME`.
- **External State Isolation**: Mutable repaired folder paths and bookmarks are saved to `~/Library/Application Support/macOS Dock Folders/<bundle-id>/repaired_state.json`, preserving application code signatures.
- **Rebuild Reconciliation**: Explicitly rebuilding a launcher clears stale repair states, preventing old self-healed locations from overriding fresh builds.
- **Multi-Collision Resolution**: Deterministic fallback naming (`Tools.app` → `Tools (Parent).app` → `Tools [hash].app`) and unique bundle identifiers (`com.macosdockfolders.tile.<hash>`).
- **Safe Overwrites**: Validates `DockFoldersGenerated` marker before replacing existing `.app` bundles, preventing accidental deletion of unrelated apps without `--force`.

### 📥 Tiles & Modes
- **Virtual Launcher Mode (`--mode launcher`)**: Dropping any item (applications, folders, PDFs, scripts, documents) creates a lightweight symbolic reference without duplicating physical files.
- **Folder Mode (`--mode folder`)**: Standard physical copy behavior with duplicate collision handling (`filename 1.ext`).
- **Document Package Protection**: Respects `.isPackage` to ensure document bundles (`.pages`, `.numbers`, `.key`, `.rtfd`) open as single files rather than expanding as directory submenus.
- **Finder Alias Resolution**: Resolves target icons and types for `.alias` files.

### 🧪 CI & Testing
- **13 Test Suites / 16 Assertions**: Comprehensive regression suite testing LaunchServices drops, multi-collision handling, bookmarks, fail-closed handling, and codesigning.
- **GitHub Actions**: Automated CI workflow on `macos-latest`.
