import SwiftUI
import AppKit

public struct GridLauncherView: View {
    public let title: String
    public let targetURL: URL
    public let items: [LauncherItem]
    public let columnsCount: Int
    public let showLabels: Bool
    public let onLaunch: (LauncherItem) -> Void
    public let onReveal: (LauncherItem) -> Void
    public let onOpenFolder: () -> Void
    public let onOpenTerminal: () -> Void
    public let onClose: () -> Void

    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0

    public init(
        title: String,
        targetURL: URL,
        items: [LauncherItem],
        columnsCount: Int = 5,
        showLabels: Bool = true,
        onLaunch: @escaping (LauncherItem) -> Void,
        onReveal: @escaping (LauncherItem) -> Void,
        onOpenFolder: @escaping () -> Void,
        onOpenTerminal: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.title = title
        self.targetURL = targetURL
        self.items = items
        self.columnsCount = max(3, min(columnsCount, 8))
        self.showLabels = showLabels
        self.onLaunch = onLaunch
        self.onReveal = onReveal
        self.onOpenFolder = onOpenFolder
        self.onOpenTerminal = onOpenTerminal
        self.onClose = onClose
    }

    var filteredItems: [LauncherItem] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return items
        }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 14), count: columnsCount)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(filteredItems.count) item\(filteredItems.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Search Filter
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Divider()

            // Main Grid Scroll Area
            ScrollView(.vertical, showsIndicators: true) {
                if filteredItems.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text(items.isEmpty ? "Folder is empty" : "No matching items")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                } else {
                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                            GridItemCell(
                                item: item,
                                showLabel: showLabels,
                                isSelected: index == selectedIndex,
                                onDoubleTap: { onLaunch(item) },
                                onReveal: { onReveal(item) }
                            )
                        }
                    }
                    .padding(16)
                }
            }
            .frame(maxHeight: 400)

            Divider()

            // Footer Bar
            HStack(spacing: 12) {
                Button(action: onOpenFolder) {
                    Label("Show in Finder", systemImage: "folder")
                }
                .buttonStyle(.borderless)
                .font(.system(size: 12))

                Button(action: onOpenTerminal) {
                    Label("Terminal", systemImage: "terminal")
                }
                .buttonStyle(.borderless)
                .font(.system(size: 12))

                Spacer()

                Button("Done", action: onClose)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.4))
        }
        .frame(width: CGFloat(columnsCount * 80 + 40))
        .background(.ultraThinMaterial)
    }
}

struct GridItemCell: View {
    let item: LauncherItem
    let showLabel: Bool
    let isSelected: Bool
    let onDoubleTap: () -> Void
    let onReveal: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onDoubleTap) {
            VStack(spacing: 6) {
                Image(nsImage: item.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)

                if showLabel {
                    Text(item.name)
                        .font(.system(size: 11))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                        .frame(maxWidth: 72)
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered || isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Open") { onDoubleTap() }
            Button("Reveal in Finder") { onReveal() }
        }
    }
}
