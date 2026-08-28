import SwiftUI
import UniformTypeIdentifiers

public struct LauncherItemsEditor: View {
    let tileID: String
    var isReadOnly: Bool = false
    @Binding var items: [LauncherItem]
    @Binding var customOrder: [String]?
    @State private var selectedItemIds = Set<String>()
    @State private var isDropTargeted: Bool = false

    public init(
        tileID: String,
        isReadOnly: Bool = false,
        items: Binding<[LauncherItem]>,
        customOrder: Binding<[String]?>
    ) {
        self.tileID = tileID
        self.isReadOnly = isReadOnly
        self._items = items
        self._customOrder = customOrder
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Launcher Items (\(items.count))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if !isReadOnly {
                    Button(action: addItemsViaPanel) {
                        Label("Add Items…", systemImage: "plus")
                    }
                    .controlSize(.small)
                }
            }

            if isReadOnly {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.orange)
                    Text("Legacy Unmanaged Launcher — Items are read-only from source folder. Convert to a Managed Collection to add or edit items.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }

            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text(isReadOnly ? "No items found in source folder" : "Drag applications, documents, or folders here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if !isReadOnly {
                        Text("Original files are not moved or copied")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 140)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6]))
                )
            } else {
                List(selection: $selectedItemIds) {
                    ForEach(items) { item in
                        HStack(spacing: 10) {
                            Image(nsImage: item.icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.name)
                                    .font(.system(size: 13, weight: .medium))
                                Text(item.resolvedPath)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            if !isReadOnly {
                                Button(action: { removeItem(item) }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .padding(.vertical, 2)
                        .contextMenu {
                            Button("Open Original") {
                                NSWorkspace.shared.open(URL(fileURLWithPath: item.resolvedPath))
                            }
                            Button("Reveal Original in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.resolvedPath)])
                            }
                            if !isReadOnly {
                                Divider()
                                Button("Remove from Launcher", role: .destructive) {
                                    removeItem(item)
                                }
                            }
                        }
                    }
                    .onMove(perform: isReadOnly ? nil : moveItems)
                }
                .frame(minHeight: 160, maxHeight: 220)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                .cornerRadius(8)
                .onDeleteCommand {
                    if !isReadOnly {
                        deleteSelected()
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            if isReadOnly { return false }
            return handleDrop(providers)
        }
    }

    private func addItemsViaPanel() {
        guard !isReadOnly else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Add to Launcher"
        if panel.runModal() == .OK {
            for url in panel.urls {
                _ = LauncherCollectionService.addItem(sourceURL: url, to: tileID)
            }
            refreshItems()
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard !isReadOnly else { return false }
        var didAdd = false
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let u = url {
                    DispatchQueue.main.async {
                        _ = LauncherCollectionService.addItem(sourceURL: u, to: tileID)
                        self.refreshItems()
                    }
                }
            }
            didAdd = true
        }
        return didAdd
    }

    private func removeItem(_ item: LauncherItem) {
        guard !isReadOnly else { return }
        _ = LauncherCollectionService.removeItem(at: URL(fileURLWithPath: item.path))
        refreshItems()
    }

    private func deleteSelected() {
        guard !isReadOnly else { return }
        for id in selectedItemIds {
            if let item = items.first(where: { $0.id == id }) {
                _ = LauncherCollectionService.removeItem(at: URL(fileURLWithPath: item.path))
            }
        }
        selectedItemIds.removeAll()
        refreshItems()
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        guard !isReadOnly else { return }
        items.move(fromOffsets: source, toOffset: destination)
        customOrder = items.map { $0.id }
    }

    private func refreshItems() {
        guard !isReadOnly else { return }
        if let colURL = LauncherCollectionService.collectionURL(for: tileID, createIfMissing: false) {
            items = LauncherCollectionService.fetchItems(for: colURL, customOrder: customOrder)
            customOrder = items.map { $0.id }
        }
    }
}
