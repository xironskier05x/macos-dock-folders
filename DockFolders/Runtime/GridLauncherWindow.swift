import Cocoa
import SwiftUI

public class GridLauncherWindow: NSPanel, NSWindowDelegate {
    public var onDismiss: (() -> Void)? = nil

    public init(
        title: String,
        targetURL: URL,
        items: [LauncherItem],
        columnsCount: Int,
        showLabels: Bool,
        anchorPoint: NSPoint
    ) {
        // Calculate dynamic dimensions
        let count = max(1, items.count)
        let effectiveCols = max(1, min(columnsCount, count))
        let rows = Int(ceil(Double(count) / Double(effectiveCols)))

        let cellWidth: CGFloat = 72
        let cellHeight: CGFloat = showLabels ? 76 : 54
        let spacing: CGFloat = 10
        let padding: CGFloat = 12

        let calculatedWidth = CGFloat(effectiveCols) * cellWidth + CGFloat(max(0, effectiveCols - 1)) * spacing + (padding * 2)
        let calculatedHeight = CGFloat(rows) * cellHeight + CGFloat(max(0, rows - 1)) * spacing + (padding * 2)

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: calculatedWidth, height: calculatedHeight),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.title = title
        self.isOpaque = false
        self.backgroundColor = .clear
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.level = .popUpMenu
        self.hasShadow = true
        self.delegate = self

        let rootView = GridLauncherView(
            title: title,
            targetURL: targetURL,
            items: items,
            columnsCount: columnsCount,
            showLabels: showLabels,
            onLaunch: { [weak self] item in
                if !item.isBroken {
                    NSWorkspace.shared.open(URL(fileURLWithPath: item.resolvedPath))
                } else {
                    NSSound.beep()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let handler = self?.onDismiss {
                        handler()
                    } else {
                        NSApp.terminate(nil)
                    }
                }
            },
            onReveal: { [weak self] item in
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.resolvedPath)])
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let handler = self?.onDismiss {
                        handler()
                    } else {
                        NSApp.terminate(nil)
                    }
                }
            },
            onOpenFolder: { [weak self] in
                NSWorkspace.shared.open(targetURL)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let handler = self?.onDismiss {
                        handler()
                    } else {
                        NSApp.terminate(nil)
                    }
                }
            },
            onOpenTerminal: { [weak self] in
                let termURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
                NSWorkspace.shared.open([targetURL], withApplicationAt: termURL, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let handler = self?.onDismiss {
                        handler()
                    } else {
                        NSApp.terminate(nil)
                    }
                }
            },
            onClose: { [weak self] in
                if let handler = self?.onDismiss {
                    handler()
                } else {
                    NSApp.terminate(nil)
                }
            }
        )

        let hostingView = NSHostingView(rootView: rootView)
        let fitting = hostingView.fittingSize
        let finalWidth = max(calculatedWidth, fitting.width > 0 ? fitting.width : calculatedWidth)
        let finalHeight = max(calculatedHeight, fitting.height > 0 ? fitting.height : calculatedHeight)
        self.setContentSize(NSSize(width: finalWidth, height: finalHeight))
        self.contentView = hostingView

        positionNearAnchor(anchorPoint)
    }

    private func positionNearAnchor(_ anchor: NSPoint) {
        let screens = NSScreen.screens
        let screen = screens.first(where: { NSMouseInRect(anchor, $0.frame, false) }) ?? NSScreen.main ?? screens.first
        guard let s = screen else { return }

        let visibleFrame = s.visibleFrame
        let winSize = self.frame.size

        var posX = max(visibleFrame.minX + 16, min(anchor.x - winSize.width / 2, visibleFrame.maxX - winSize.width - 16))
        var posY = max(visibleFrame.minY + 24, anchor.y + 24)

        let dockOrientation = (UserDefaults(suiteName: "com.apple.dock")?.string(forKey: "orientation") ?? "bottom").lowercased()
        switch dockOrientation {
        case "left":
            posX = max(visibleFrame.minX + 24, anchor.x + 24)
            posY = max(visibleFrame.minY + 16, min(anchor.y - winSize.height / 2, visibleFrame.maxY - winSize.height - 16))
        case "right":
            posX = min(visibleFrame.maxX - winSize.width - 24, anchor.x - winSize.width - 24)
            posY = max(visibleFrame.minY + 16, min(anchor.y - winSize.height / 2, visibleFrame.maxY - winSize.height - 16))
        default:
            // Bottom Dock: float comfortably above the Dock
            posY = max(visibleFrame.minY + 24, anchor.y + 24)
        }

        if posY + winSize.height > visibleFrame.maxY - 16 {
            posY = visibleFrame.maxY - winSize.height - 16
        }

        self.setFrame(NSRect(x: posX, y: posY, width: winSize.width, height: winSize.height), display: true)
    }

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }

    public override func cancelOperation(_ sender: Any?) {
        if let handler = onDismiss {
            handler()
        } else {
            NSApp.terminate(nil)
        }
    }

    // Dismissal / Click-Outside lifecycle
    public func windowDidResignKey(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if !self.isKeyWindow {
                if let handler = self.onDismiss {
                    handler()
                } else {
                    NSApp.terminate(nil)
                }
            }
        }
    }
}
