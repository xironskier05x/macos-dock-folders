import Foundation
import AppKit

public struct LauncherItem: Identifiable, Equatable {
    public let id: String
    public var name: String
    public var path: String
    public var resolvedPath: String
    public var isDirectory: Bool
    public var isPackage: Bool
    public var isApp: Bool
    public var isBroken: Bool
    public var icon: NSImage

    public init(
        id: String = UUID().uuidString,
        name: String,
        path: String,
        resolvedPath: String,
        isDirectory: Bool,
        isPackage: Bool,
        isApp: Bool,
        isBroken: Bool = false,
        icon: NSImage
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.resolvedPath = resolvedPath
        self.isDirectory = isDirectory
        self.isPackage = isPackage
        self.isApp = isApp
        self.isBroken = isBroken
        self.icon = icon
    }

    public static func == (lhs: LauncherItem, rhs: LauncherItem) -> Bool {
        lhs.id == rhs.id && lhs.path == rhs.path && lhs.name == rhs.name
    }
}
