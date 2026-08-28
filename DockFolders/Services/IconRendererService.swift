import Foundation
import AppKit

public struct IconRendererService {
    public static func parseColor(_ hexOrPreset: String) -> NSColor {
        let lower = hexOrPreset.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch lower {
        case "blue": return NSColor(calibratedRed: 0.0, green: 0.478, blue: 1.0, alpha: 1.0)
        case "purple": return NSColor(calibratedRed: 0.686, green: 0.322, blue: 0.871, alpha: 1.0)
        case "pink": return NSColor(calibratedRed: 1.0, green: 0.176, blue: 0.333, alpha: 1.0)
        case "red": return NSColor(calibratedRed: 1.0, green: 0.231, blue: 0.188, alpha: 1.0)
        case "orange": return NSColor(calibratedRed: 1.0, green: 0.584, blue: 0.0, alpha: 1.0)
        case "yellow": return NSColor(calibratedRed: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
        case "green": return NSColor(calibratedRed: 0.204, green: 0.780, blue: 0.349, alpha: 1.0)
        case "teal": return NSColor(calibratedRed: 0.353, green: 0.784, blue: 0.980, alpha: 1.0)
        case "indigo": return NSColor(calibratedRed: 0.345, green: 0.337, blue: 0.839, alpha: 1.0)
        case "gray": return NSColor(calibratedRed: 0.557, green: 0.557, blue: 0.576, alpha: 1.0)
        case "dark": return NSColor(calibratedRed: 0.227, green: 0.227, blue: 0.235, alpha: 1.0)
        default:
            let hex = hexOrPreset.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            var int: UInt64 = 0
            Scanner(string: hex).scanHexInt64(&int)
            if hex.count == 6 {
                let r = CGFloat((int >> 16) & 0xFF) / 255.0
                let g = CGFloat((int >> 8) & 0xFF) / 255.0
                let b = CGFloat(int & 0xFF) / 255.0
                return NSColor(calibratedRed: r, green: g, blue: b, alpha: 1.0)
            }
            return NSColor(calibratedRed: 0.227, green: 0.227, blue: 0.235, alpha: 1.0)
        }
    }

    public static func renderImage(config: IconConfiguration, fallbackFolder: String? = nil, size: CGFloat = 512) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        if config.type == .customImage, let path = config.imagePath, let customImg = NSImage(contentsOfFile: path) {
            customImg.draw(in: NSRect(x: 0, y: 0, width: size, height: size), from: .zero, operation: .sourceOver, fraction: 1.0)
        } else if config.type == .defaultFolder, let folder = fallbackFolder {
            let wsIcon = NSWorkspace.shared.icon(forFile: folder)
            wsIcon.draw(in: NSRect(x: 0, y: 0, width: size, height: size), from: .zero, operation: .sourceOver, fraction: 1.0)
        } else {
            // Squircle background
            let rect = NSRect(x: 0, y: 0, width: size, height: size)
            let path = NSBezierPath(roundedRect: rect, xRadius: size * 0.22, yRadius: size * 0.22)
            parseColor(config.colorHex).setFill()
            path.fill()

            if config.type == .emoji, let em = config.emoji, !em.isEmpty {
                let fontSize = size * 0.58
                let font = NSFont.systemFont(ofSize: fontSize)
                let attrStr = NSAttributedString(string: em, attributes: [.font: font])
                let strSize = attrStr.size()
                let drawX = (size - strSize.width) / 2
                let drawY = (size - strSize.height) / 2
                attrStr.draw(at: NSPoint(x: drawX, y: drawY))
            } else {
                let symbol = config.symbolName ?? "folder.badge.gear"
                if let symImage = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
                    let pointSize = size * 0.52
                    let conf = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
                        .applying(.init(paletteColors: [.white]))
                    let configured = symImage.withSymbolConfiguration(conf) ?? symImage
                    let symSize = configured.size
                    let drawRect = NSRect(x: (size - symSize.width) / 2, y: (size - symSize.height) / 2, width: symSize.width, height: symSize.height)
                    configured.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
                }
            }
        }

        image.unlockFocus()
        return image
    }

    public static func generateIcns(config: IconConfiguration, folderPath: String?, destinationPath: String) -> Bool {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("dock_icon_\(UUID().uuidString)")
        let iconsetDir = tempDir.appendingPathComponent("app.iconset")
        let pngPath = tempDir.appendingPathComponent("render_1024.png")

        defer { try? fm.removeItem(at: tempDir) }

        do {
            try fm.createDirectory(at: iconsetDir, withIntermediateDirectories: true)
            let masterImage = renderImage(config: config, fallbackFolder: folderPath, size: 1024)
            guard let tiffData = masterImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                return false
            }
            try pngData.write(to: pngPath)

            let sizes: [(size: Int, scale: Int, name: String)] = [
                (16, 1, "icon_16x16.png"),
                (16, 2, "icon_16x16@2x.png"),
                (32, 1, "icon_32x32.png"),
                (32, 2, "icon_32x32@2x.png"),
                (128, 1, "icon_128x128.png"),
                (128, 2, "icon_128x128@2x.png"),
                (256, 1, "icon_256x256.png"),
                (256, 2, "icon_256x256@2x.png"),
                (512, 1, "icon_512x512.png"),
                (512, 2, "icon_512x512@2x.png")
            ]

            for s in sizes {
                let px = s.size * s.scale
                let outURL = iconsetDir.appendingPathComponent(s.name)
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
                process.arguments = ["-z", "\(px)", "\(px)", pngPath.path, "--out", outURL.path]
                try? process.run()
                process.waitUntilExit()
            }

            let iconutil = Process()
            iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
            iconutil.arguments = ["-c", "icns", iconsetDir.path, "-o", destinationPath]
            try iconutil.run()
            iconutil.waitUntilExit()
            return iconutil.terminationStatus == 0
        } catch {
            return false
        }
    }
}
