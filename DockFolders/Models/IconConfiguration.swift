import Foundation
import AppKit

public struct IconConfiguration: Codable, Equatable {
    public enum IconType: String, Codable {
        case symbol
        case emoji
        case customImage
        case defaultFolder
    }

    public var type: IconType
    public var symbolName: String?
    public var colorHex: String
    public var imagePath: String?
    public var emoji: String?

    public init(
        type: IconType = .symbol,
        symbolName: String? = "folder.badge.gear",
        colorHex: String = "#3A3A3C",
        imagePath: String? = nil,
        emoji: String? = nil
    ) {
        self.type = type
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.imagePath = imagePath
        self.emoji = emoji
    }

    public static let presetColors: [(name: String, hex: String, color: NSColor)] = [
        ("Dark", "#3A3A3C", NSColor(calibratedRed: 0.227, green: 0.227, blue: 0.235, alpha: 1.0)),
        ("Blue", "#007AFF", NSColor(calibratedRed: 0.0, green: 0.478, blue: 1.0, alpha: 1.0)),
        ("Purple", "#AF52DE", NSColor(calibratedRed: 0.686, green: 0.322, blue: 0.871, alpha: 1.0)),
        ("Pink", "#FF2D55", NSColor(calibratedRed: 1.0, green: 0.176, blue: 0.333, alpha: 1.0)),
        ("Red", "#FF3B30", NSColor(calibratedRed: 1.0, green: 0.231, blue: 0.188, alpha: 1.0)),
        ("Orange", "#FF9500", NSColor(calibratedRed: 1.0, green: 0.584, blue: 0.0, alpha: 1.0)),
        ("Yellow", "#FFCC00", NSColor(calibratedRed: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)),
        ("Green", "#34C759", NSColor(calibratedRed: 0.204, green: 0.780, blue: 0.349, alpha: 1.0)),
        ("Teal", "#5AC8FA", NSColor(calibratedRed: 0.353, green: 0.784, blue: 0.980, alpha: 1.0)),
        ("Indigo", "#5856D6", NSColor(calibratedRed: 0.345, green: 0.337, blue: 0.839, alpha: 1.0)),
        ("Gray", "#8E8E93", NSColor(calibratedRed: 0.557, green: 0.557, blue: 0.576, alpha: 1.0))
    ]
}
