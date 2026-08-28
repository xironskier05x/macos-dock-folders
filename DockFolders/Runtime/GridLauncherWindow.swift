import Cocoa
import SwiftUI

public class GridLauncherWindow: NSPanel, NSWindowDelegate {
    public init(
        title: String,
        targetURL: URL,
        items: [LauncherItem],
        columnsCount: Int,
        showLabels: Bool,
        anchorPoint: NSPoint
    ) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: CGFloat(columnsCount * 80 + 40), height: 350),
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
        self.level = .floating
        self.hasShadow = true
        self.delegate = self

        let rootView = GridLauncherView(
            title: title,
            targetURL: targetURL,
            items: items,
            columnsCount: columnsCount,
            showLabels: showLabels,
            onLaunch: { item in
                if !item.isBroken {
                    NSWorkspace.shared.open(URL(fileURLWithPath: item.resolvedPath))
                } else {
                    NSSound.beep()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NSApp.terminate(nil)
                }
            },
            onReveal: { item in
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.resolvedPath)])
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NSApp.terminate(nil)
                }
            },
            onOpenFolder: {
                NSWorkspace.shared.open(targetURL)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NSApp.terminate(nil)
                }
            },
            onOpenTerminal: {
                let termURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
                NSWorkspace.shared.open([targetURL], withApplicationAt: termURL, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NSApp.terminate(nil)
                }
            },
            onClose: {
                NSApp.terminate(nil)
            }
        )

        let hostingView = NSHostingView(rootView: rootView)
        self.contentView = hostingView

        positionNearAnchor(anchorPoint)
    }

    private func positionNearAnchor(_ anchor: NSPoint) {
        let screens = NSScreen.screens
        let screen = screens.first(where: { NSMouseInRect(anchor, $0.frame, false) }) ?? NSScreen.main ?? screens.first
        guard let s = screen else { return }

        let visibleFrame = s.visibleFrame
        let winSize = self.frame.size

        var posX = max(visibleFrame.minX + 10, min(anchor.x - winSize.width / 2, visibleFrame.maxX - winSize.width - 10))
        var posY = max(visibleFrame.minY + 10, min(anchor.y + 10, visibleFrame.maxY - winSize.height - 10))

        let dockOrientation = (UserDefaults(suiteName: "com.apple.dock")?.string(forKey: "orientation") ?? "bottom").lowercased()
        switch dockOrientation {
        case "left":
            posX = visibleFrame.minX + 10
            posY = max(visibleFrame.minY + 10, min(anchor.y - winSize.height / 2, visibleFrame.maxY - winSize.height - 10))
        case "right":
            posX = visibleFrame.maxX - winSize.width - 10
            posY = max(visibleFrame.minY + 10, min(anchor.y - winSize.height / 2, visibleFrame.maxY - winSize.height - 10))
        default:
            posY = visibleFrame.minY + 10
        }

        self.setFrameOrigin(NSPoint(x: posX, y: posY))
    }

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }

    public override func cancelOperation(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    // Dismissal / Click-Outside lifecycle
    public func windowDidResignKey(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if !self.isKeyWindow {
                NSApp.terminate(nil)
            }
        }
    }
}
