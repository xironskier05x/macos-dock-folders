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
    @State private var sortMode: SortMode = .custom
    @State private var maxDepth: Int = 3
    @State private var gridColumns: Int = 5
    @State private var showLabels: Bool = true
    @State private var iconConfig: IconConfiguration = IconConfiguration()
    @State private var items: [LauncherItem] = []
    @State private var customOrder: [String]? = nil
    @State private var addToDock: Bool = false
    @State private var draftCollectionID: String = UUID().uuidString
    @State private var isDraftCreated: Bool = false
    @State private var isLegacy: Bool = false

    @State private var errorMessage: String? = nil
    @State private var isShowingError: Bool = false

    public init(existingTile: DockTile? = nil) {
        self.existingTile = existingTile
    }

    var isFormValid: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.contains("/") || trimmed.contains(":") {
            return false
        }
        if tileMode == .folder {
            if targetPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !FileManager.default.fileExists(atPath: targetPath) {
                return false
            }
        }
        return true
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(existingTile == nil ? "Create Dock Folder" : "Edit Dock Folder")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    cancelAndCleanup()
                }
                .keyboardShortcut(.cancelAction)

                Button(existingTile == nil ? "Create" : "Save") {
                    saveTile()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!isFormValid)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Mode Selector (Disabled if editing existing tile)
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
                        .disabled(existingTile != nil)

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

                        if name.contains("/") || name.contains(":") {
                            Text("Name cannot contain / or : characters")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    // Mode Specific Configuration
                    if tileMode == .folder {
                        FolderSettingsEditor(targetPath: $targetPath, maxDepth: $maxDepth)
                    } else {
                        LauncherItemsEditor(
                            tileID: isLegacy ? "" : draftCollectionID,
                            isReadOnly: isLegacy,
                            items: $items,
                            customOrder: $customOrder
                        )
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

                    // Dock Pinning (Only for new tiles)
                    if existingTile == nil {
                        Toggle("Add to macOS Dock automatically", isOn: $addToDock)
                            .padding(.top, 4)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 580, height: 640)
        .alert(isPresented: $isShowingError) {
            Alert(
                title: Text("Could Not Save Tile"),
                message: Text(errorMessage ?? "An unknown error occurred."),
                dismissButton: .default(Text("OK"))
            )
        }
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
                isLegacy = tile.config.isLegacyLauncher
                draftCollectionID = tile.config.collectionID ?? ""
                items = tile.items
                addToDock = tile.isDockPinned
                isDraftCreated = false
            } else {
                let prefs = PreferencesStore.shared
                tileMode = prefs.defaultTileMode
                presentationMode = prefs.defaultPresentation
                gridColumns = prefs.defaultGridColumns
                showLabels = prefs.defaultShowLabels
                sortMode = prefs.defaultSortMode
                addToDock = prefs.autoAddToDock
                draftCollectionID = UUID().uuidString
                isDraftCreated = true
                isLegacy = false
            }
        }
    }

    private func cancelAndCleanup() {
        if existingTile == nil && isDraftCreated {
            // Clean up aborted draft collection
            try? LauncherCollectionService.deleteManagedCollection(collectionID: draftCollectionID)
        }
        dismiss()
    }

    private func saveTile() {
        guard let runtimeURL = RuntimeInstallerService.getOrCreateRuntime() else {
            errorMessage = "Could not locate precompiled DockFolderRuntime binary."
            isShowingError = true
            return
        }

        do {
            if let existing = existingTile {
                var resolvedTarget = targetPath
                if existing.config.resolvedTileMode == .launcher {
                    if let cid = existing.config.collectionID, let colURL = LauncherCollectionService.collectionURL(for: cid, createIfMissing: true) {
                        resolvedTarget = colURL.path
                    }
                }

                _ = try tileStore.updateTile(
                    existingTile: existing,
                    newName: name,
                    targetPath: resolvedTarget,
                    mode: tileMode,
                    presentation: presentationMode,
                    sort: sortMode,
                    maxDepth: maxDepth,
                    gridColumns: gridColumns,
                    showLabels: showLabels,
                    iconConfig: iconConfig,
                    customOrder: customOrder,
                    runtimeURL: runtimeURL
                )
            } else {
                var resolvedTarget = targetPath
                var cid: String? = nil
                if tileMode == .launcher {
                    let (_, colURL) = try LauncherCollectionService.createManagedCollection(collectionID: draftCollectionID)
                    resolvedTarget = colURL.path
                    cid = draftCollectionID
                } else {
                    // Mode is Folder: clean up draft collection if one was initialized
                    if isDraftCreated {
                        try? LauncherCollectionService.deleteManagedCollection(collectionID: draftCollectionID)
                    }
                }

                let newTile = try tileStore.createTile(
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
                    collectionID: cid,
                    addToDock: addToDock,
                    runtimeURL: runtimeURL
                )
                selectionStore.selectedTileId = newTile.id
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isShowingError = true
        }
    }
}
