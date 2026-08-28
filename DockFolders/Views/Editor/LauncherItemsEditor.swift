import SwiftUI
import UniformTypeIdentifiers

public struct LauncherItemsEditor: View {
    let tileID: String
    @Binding var items: [LauncherItem]
    @Binding var customOrder: [String]?
    @State private var isDropTargeted: Bool = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Launcher Items (\(items.count))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Button(action: addItemsViaPanel) {
                    Label("Add Items…", systemImage: "plus")
                }
                .controlSize(.small)
            }

            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text("Drag applications, documents, or folders here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Original files are not moved or copied")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 140)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6]))
                )
            } else {
                List {
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

                            Button(action: { removeItem(item) }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 2)
                    }
                    .onMove(perform: moveItems)
                }
                .frame(minHeight: 160, maxHeight: 220)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
    }

    private func addItemsViaPanel() {
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
        _ = LauncherCollectionService.removeItem(at: URL(fileURLWithPath: item.path))
        refreshItems()
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        customOrder = items.map { $0.name }
    }

    private func refreshItems() {
        items = LauncherCollectionService.fetchItems(for: tileID, customOrder: customOrder)
        customOrder = items.map { $0.name }
    }
}
