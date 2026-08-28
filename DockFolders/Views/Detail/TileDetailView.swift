import SwiftUI

public struct TileDetailView: View {
    @ObservedObject var tile: DockTile
    @EnvironmentObject var tileStore: TileStore
    @EnvironmentObject var selectionStore: SelectionStore
    @ObservedObject var prefs = PreferencesStore.shared

    @State private var isShowingDeleteConfirm: Bool = false
    @State private var isShowingMigrationConfirm: Bool = false

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Legacy Migration Banner if applicable
                if tile.config.isLegacyLauncher {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Legacy 2.x Unmanaged Launcher")
                                .font(.headline)
                            Text("This launcher points to an external directory. Convert to a 3.0 Managed Collection to enable visual drag-and-drop item management.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button("Convert to Managed Collection…") {
                            isShowingMigrationConfirm = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(10)
                }

                // Header Area
                HStack(spacing: 18) {
                    if let img = tile.iconImage {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 72, height: 72)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(tile.name)
                                .font(.title2)
                                .fontWeight(.bold)

                            Text(tile.config.resolvedTileMode.displayName)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundColor(.accentColor)
                                .cornerRadius(6)
                        }

                        Text(tile.appPath)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        HStack(spacing: 12) {
                            Label(tile.config.resolvedPresentationMode.displayName, systemImage: tile.config.resolvedPresentationMode.systemImage)
                            Label(tile.config.resolvedSortMode.displayName, systemImage: tile.config.resolvedSortMode.systemImage)
                            if tile.isDockPinned {
                                Label("In macOS Dock", systemImage: "pin.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                    }

                    Spacer()

                    // Quick Actions
                    VStack(spacing: 8) {
                        Button(action: { selectionStore.editingTile = tile }) {
                            Label("Edit", systemImage: "pencil")
                                .frame(width: 100)
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: {
                            tileStore.toggleDockPin(for: tile)
                        }) {
                            Label(tile.isDockPinned ? "Remove Dock" : "Add to Dock", systemImage: tile.isDockPinned ? "pin.slash" : "pin")
                                .frame(width: 100)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)

                // Main Content / Preview Split
                HStack(alignment: .top, spacing: 20) {
                    // Left Column: Tile Details & Items
                    VStack(alignment: .leading, spacing: 16) {
                        if tile.config.resolvedTileMode == .launcher {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Launcher Items (\(tile.items.count))")
                                        .font(.headline)
                                    Spacer()
                                    Button("Edit Items…") {
                                        selectionStore.editingTile = tile
                                    }
                                    .controlSize(.small)
                                }

                                if tile.items.isEmpty {
                                    Text("This launcher drawer is empty.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding(.vertical, 8)
                                } else {
                                    LazyVStack(spacing: 4) {
                                        ForEach(tile.items) { item in
                                            HStack(spacing: 8) {
                                                Image(nsImage: item.icon)
                                                    .resizable()
                                                    .frame(width: 20, height: 20)
                                                Text(item.name)
                                                    .font(.system(size: 12))
                                                Spacer()
                                                Text(item.isApp ? "App" : (item.isDirectory ? "Folder" : "File"))
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(6)
                                            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                                            .cornerRadius(6)
                                        }
                                    }
                                }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Folder Browser Target")
                                    .font(.headline)
                                Text(tile.config.targetPath)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Divider()

                        // Management Actions
                        HStack(spacing: 12) {
                            Button(action: {
                                if let runtimeURL = RuntimeInstallerService.getOrCreateRuntime() {
                                    _ = try? tileStore.rebuildTile(tile, runtimeURL: runtimeURL)
                                }
                            }) {
                                Label("Rebuild Launcher", systemImage: "arrow.clockwise")
                            }

                            Button(action: {
                                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: tile.appPath)])
                            }) {
                                Label("Reveal .app", systemImage: "folder")
                            }

                            Spacer()

                            Button(role: .destructive, action: {
                                if prefs.confirmDeletion {
                                    isShowingDeleteConfirm = true
                                } else {
                                    performDelete()
                                }
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()

                    // Right Column: Live Presentation Preview
                    VStack {
                        TilePreviewView(tile: tile)
                    }
                    .frame(width: 260)
                }
            }
            .padding(20)
        }
        .navigationTitle(tile.name)
        .confirmationDialog(
            "Delete '\(tile.name)'?",
            isPresented: $isShowingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Launcher (.app and collection)", role: .destructive) {
                performDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the generated .app from your Mac and Dock. Original applications and files will NOT be deleted.")
        }
        .confirmationDialog(
            "Convert to Managed Collection?",
            isPresented: $isShowingMigrationConfirm,
            titleVisibility: .visible
        ) {
            Button("Convert", role: .none) {
                if let runtimeURL = RuntimeInstallerService.getOrCreateRuntime() {
                    do {
                        _ = try tileStore.migrateLegacyTile(tile, runtimeURL: runtimeURL)
                    } catch {
                        tileStore.errorMessage = "Failed to convert legacy launcher: \(error.localizedDescription)"
                    }
                } else {
                    tileStore.errorMessage = "Could not locate DockFolderRuntime binary."
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This creates a managed collection in Application Support and copies references from the legacy directory. Your original folder and files remain untouched.")
        }
    }

    private func performDelete() {
        tileStore.deleteTile(tile, deleteCollection: true)
        selectionStore.selectedTileId = nil
    }
}
