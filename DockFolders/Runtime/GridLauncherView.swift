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
        self.columnsCount = max(2, min(columnsCount, 8))
        self.showLabels = showLabels
        self.onLaunch = onLaunch
        self.onReveal = onReveal
        self.onOpenFolder = onOpenFolder
        self.onOpenTerminal = onOpenTerminal
        self.onClose = onClose
    }

    var effectiveCols: Int {
        let count = max(1, items.count)
        return max(1, min(columnsCount, count))
    }

    var gridColumns: [GridItem] {
        Array(repeating: GridItem(.fixed(72), spacing: 10), count: effectiveCols)
    }

    public var body: some View {
        ZStack {
            KeyHandlingView(
                onLeft: { moveSelection(by: -1) },
                onRight: { moveSelection(by: 1) },
                onUp: { moveSelection(by: -effectiveCols) },
                onDown: { moveSelection(by: effectiveCols) },
                onReturn: { launchCurrentSelection() },
                onEscape: { onClose() }
            )
            .frame(width: 0, height: 0)

            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text("Folder is empty")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(24)
            } else {
                LazyVGrid(columns: gridColumns, spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
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
                .padding(12)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    private func moveSelection(by delta: Int) {
        guard !items.isEmpty else { return }
        var state = GridNavigationState(selectedIndex: selectedIndex, columnsCount: effectiveCols, totalItems: items.count)
        if delta == 1 { state.moveRight() }
        else if delta == -1 { state.moveLeft() }
        else if delta > 1 { state.moveDown() }
        else if delta < -1 { state.moveUp() }
        selectedIndex = state.selectedIndex
    }

    private func launchCurrentSelection() {
        guard selectedIndex >= 0 && selectedIndex < items.count else { return }
        onLaunch(items[selectedIndex])
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Keyboard Event Monitor Helper
// ─────────────────────────────────────────────────────────────────────────────
struct KeyHandlingView: NSViewRepresentable {
    var onLeft: () -> Void
    var onRight: () -> Void
    var onUp: () -> Void
    var onDown: () -> Void
    var onReturn: () -> Void
    var onEscape: () -> Void

    func makeNSView(context: Context) -> KeyView {
        let view = KeyView()
        view.onLeft = onLeft
        view.onRight = onRight
        view.onUp = onUp
        view.onDown = onDown
        view.onReturn = onReturn
        view.onEscape = onEscape
        return view
    }

    func updateNSView(_ nsView: KeyView, context: Context) {
        nsView.onLeft = onLeft
        nsView.onRight = onRight
        nsView.onUp = onUp
        nsView.onDown = onDown
        nsView.onReturn = onReturn
        nsView.onEscape = onEscape
    }

    class KeyView: NSView {
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

// ─────────────────────────────────────────────────────────────────────────────
// Grid Item Cell Component
// ─────────────────────────────────────────────────────────────────────────────
struct GridItemCell: View {
    let item: LauncherItem
    let showLabel: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onReveal: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Image(nsImage: item.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 46, height: 46)
                        .shadow(color: .black.opacity(0.18), radius: 2, y: 1)

                    if item.isBroken {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.orange)
                            .background(Circle().fill(Color.white).frame(width: 8, height: 8))
                    }
                }

                if showLabel {
                    Text(item.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(item.isBroken ? .secondary : .primary)
                        .frame(maxWidth: 68)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovered || isSelected ? Color.white.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
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
