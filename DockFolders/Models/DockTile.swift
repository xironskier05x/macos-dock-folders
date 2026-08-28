import Foundation
import AppKit
import SwiftUI

public class DockTile: Identifiable, ObservableObject, Equatable {
    public let id: String
    @Published public var name: String
    @Published public var appPath: String
    @Published public var config: DockTileConfig
    @Published public var isDockPinned: Bool
    @Published public var iconImage: NSImage?
    @Published public var items: [LauncherItem]
    @Published public var lastModified: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        appPath: String,
        config: DockTileConfig,
        isDockPinned: Bool = false,
        iconImage: NSImage? = nil,
        items: [LauncherItem] = [],
        lastModified: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.appPath = appPath
        self.config = config
        self.isDockPinned = isDockPinned
        self.iconImage = iconImage
        self.items = items
        self.lastModified = lastModified
    }

    public static func == (lhs: DockTile, rhs: DockTile) -> Bool {
        lhs.id == rhs.id && lhs.appPath == rhs.appPath && lhs.config == rhs.config
    }
}
