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
    @FocusState private var isSearchFocused: Bool

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
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            return items
        }
        return items.filter { $0.name.localizedCaseInsensitiveContains(q) }
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
                    .focused($isSearchFocused)
                    .onChange(of: searchText) { _ in
                        selectedIndex = 0
                    }
                    .onSubmit {
                        launchCurrentSelection()
                    }

                if !searchText.isEmpty {
                    Button(action: { searchText = ""; selectedIndex = 0 }) {
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
            ScrollViewReader { proxy in
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
                                    onTap: {
                                        selectedIndex = index
                                        onLaunch(item)
                                    },
                                    onReveal: { onReveal(item) }
                                )
                                .id(index)
                            }
                        }
                        .padding(16)
                    }
                }
                .frame(maxHeight: 420)
                .onChange(of: selectedIndex) { newIndex in
                    withAnimation {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }

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
        .onAppear {
            isSearchFocused = true
        }
        .background(
            KeyboardNavReceiver(
                onLeft: { moveSelection(by: -1) },
                onRight: { moveSelection(by: 1) },
                onUp: { moveSelection(by: -columnsCount) },
                onDown: { moveSelection(by: columnsCount) },
                onReturn: { launchCurrentSelection() },
                onEscape: onClose
            )
        )
    }

    private func moveSelection(by delta: Int) {
        let count = filteredItems.count
        guard count > 0 else { return }
        var newIdx = selectedIndex + delta
        if newIdx < 0 { newIdx = 0 }
        if newIdx >= count { newIdx = count - 1 }
        selectedIndex = newIdx
    }

    private func launchCurrentSelection() {
        let count = filteredItems.count
        guard count > 0 else { return }
        let validIdx = max(0, min(selectedIndex, count - 1))
        onLaunch(filteredItems[validIdx])
    }
}

struct KeyboardNavReceiver: NSViewRepresentable {
    let onLeft: () -> Void
    let onRight: () -> Void
    let onUp: () -> Void
    let onDown: () -> Void
    let onReturn: () -> Void
    let onEscape: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyInterceptingView()
        view.onLeft = onLeft
        view.onRight = onRight
        view.onUp = onUp
        view.onDown = onDown
        view.onReturn = onReturn
        view.onEscape = onEscape
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    class KeyInterceptingView: NSView {
        var onLeft: (() -> Void)?
        var onRight: (() -> Void)?
        var onUp: (() -> Void)?
        var onDown: (() -> Void)?
        var onReturn: (() -> Void)?
        var onEscape: (() -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil && monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    guard let self = self else { return event }
                    switch event.keyCode {
                    case 123: // Left
                        self.onLeft?(); return nil
                    case 124: // Right
                        self.onRight?(); return nil
                    case 126: // Up
                        self.onUp?(); return nil
                    case 125: // Down
                        self.onDown?(); return nil
                    case 36, 76: // Return / Enter
                        self.onReturn?(); return nil
                    case 53: // Escape
                        self.onEscape?(); return nil
                    default:
                        return event
                    }
                }
            }
        }

        deinit {
            if let m = monitor {
                NSEvent.removeMonitor(m)
            }
        }
    }
}

struct GridItemCell: View {
    let item: LauncherItem
    let showLabel: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onReveal: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Image(nsImage: item.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)

                    if item.isBroken {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                            .background(Circle().fill(Color.white).frame(width: 10, height: 10))
                    }
                }

                if showLabel {
                    Text(item.name)
                        .font(.system(size: 11))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(item.isBroken ? .secondary : .primary)
                        .frame(maxWidth: 72)
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered || isSelected ? Color.accentColor.opacity(0.25) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Open") { onTap() }
            Button("Reveal in Finder") { onReveal() }
        }
    }
}
