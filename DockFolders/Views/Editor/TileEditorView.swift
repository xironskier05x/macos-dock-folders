import SwiftUI

public struct TileEditorView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var tileStore: TileStore
    @EnvironmentObject var selectionStore: SelectionStore

    let existingTile: DockTile?

    @State private var name: String = ""
    @State private var tileMode: TileMode = .launcher
    @State private var targetPath: String = ""
    @State private var presentationMode: PresentationMode = .grid
    @State private var sortMode: SortMode = .name
    @State private var maxDepth: Int = 3
    @State private var gridColumns: Int = 5
    @State private var showLabels: Bool = true
    @State private var iconConfig: IconConfiguration = IconConfiguration()
    @State private var items: [LauncherItem] = []
    @State private var customOrder: [String]? = nil
    @State private var addToDock: Bool = true
    @State private var draftTileID: String = UUID().uuidString

    public init(existingTile: DockTile? = nil) {
        self.existingTile = existingTile
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(existingTile == nil ? "Create Dock Folder" : "Edit Dock Folder")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(existingTile == nil ? "Create" : "Save") {
                    saveTile()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Tile Mode Selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tile Mode")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Picker("Mode", selection: $tileMode) {
                            ForEach(TileMode.allCases) { mode in
                                Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(tileMode.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Basic Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tile Name")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("e.g. AI Apps, Coding Projects, Utilities", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Mode Specific Configuration
                    if tileMode == .folder {
                        FolderSettingsEditor(targetPath: $targetPath, maxDepth: $maxDepth)
                    } else {
                        LauncherItemsEditor(tileID: draftTileID, items: $items, customOrder: $customOrder)
                    }

                    // Presentation & Layout
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Presentation & Layout")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Picker("Presentation", selection: $presentationMode) {
                            ForEach(PresentationMode.allCases) { pres in
                                Label(pres.displayName, systemImage: pres.systemImage).tag(pres)
                            }
                        }
                        .pickerStyle(.segmented)

                        if presentationMode == .grid {
                            HStack {
                                Text("Grid Columns:")
                                Spacer()
                                Stepper("\(gridColumns) columns", value: $gridColumns, in: 4...7)
                            }

                            Toggle("Show Item Text Labels", isOn: $showLabels)
                        }

                        Picker("Sort Order", selection: $sortMode) {
                            ForEach(SortMode.allCases) { sm in
                                Label(sm.displayName, systemImage: sm.systemImage).tag(sm)
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(10)

                    // Icon Configuration
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Icon Appearance")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        IconPickerView(iconConfig: $iconConfig, fallbackFolder: tileMode == .folder ? targetPath : nil)
                    }

                    // Dock Pinning
                    Toggle("Add to macOS Dock automatically", isOn: $addToDock)
                        .padding(.top, 4)
                }
                .padding(20)
            }
        }
        .frame(width: 580, height: 640)
        .onAppear {
            if let tile = existingTile {
                name = tile.name
                tileMode = tile.config.resolvedTileMode
                targetPath = tile.config.targetPath
                presentationMode = tile.config.resolvedPresentationMode
                sortMode = tile.config.resolvedSortMode
                maxDepth = tile.config.resolvedMaxDepth
                gridColumns = tile.config.resolvedGridColumns
                showLabels = tile.config.resolvedShowLabels
                iconConfig = tile.config.iconConfig ?? IconConfiguration()
                customOrder = tile.config.customOrder
                draftTileID = FileHelpers.deterministicHash(for: tile.config.targetPath)
                items = tile.items
                addToDock = tile.isDockPinned
            } else {
                draftTileID = UUID().uuidString
            }
        }
    }

    private func saveTile() {
        guard let runtimeURL = RuntimeInstallerService.getOrCreateRuntime() else { return }

        var resolvedTarget = targetPath
        if tileMode == .launcher {
            let collectionDir = LauncherCollectionService.collectionDirectory(for: draftTileID)
            resolvedTarget = collectionDir.path
        }

        let res = tileStore.createTile(
            name: name,
            targetPath: resolvedTarget,
            mode: tileMode,
            presentation: presentationMode,
            sort: sortMode,
            maxDepth: maxDepth,
            gridColumns: gridColumns,
            showLabels: showLabels,
            iconConfig: iconConfig,
            customOrder: customOrder,
            addToDock: addToDock,
            runtimeURL: runtimeURL
        )

        if let tile = res.tile {
            selectionStore.selectedTileId = tile.id
        }
        dismiss()
    }
}
