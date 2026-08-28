import Foundation

public struct DockTileConfig: Codable, Equatable {
    public var targetPath: String
    public var targetBookmarkBase64: String?
    public var displayName: String
    public var sortMode: String?
    public var maxDepth: Int?
    public var tileMode: String?
    public var presentation: String?
    public var gridColumns: Int?
    public var showLabels: Bool?
    public var customOrder: [String]?
    public var collectionID: String?
    public var iconConfig: IconConfiguration?

    public init(
        targetPath: String,
        targetBookmarkBase64: String? = nil,
        displayName: String,
        sortMode: String? = "name",
        maxDepth: Int? = 3,
        tileMode: String? = "folder",
        presentation: String? = "menu",
        gridColumns: Int? = 5,
        showLabels: Bool? = true,
        customOrder: [String]? = nil,
        collectionID: String? = nil,
        iconConfig: IconConfiguration? = nil
    ) {
        self.targetPath = targetPath
        self.targetBookmarkBase64 = targetBookmarkBase64
        self.displayName = displayName
        self.sortMode = sortMode
        self.maxDepth = maxDepth
        self.tileMode = tileMode
        self.presentation = presentation
        self.gridColumns = gridColumns
        self.showLabels = showLabels
        self.customOrder = customOrder
        self.collectionID = collectionID
        self.iconConfig = iconConfig
    }

    public var isManagedLauncher: Bool {
        resolvedTileMode == .launcher && collectionID != nil
    }

    public var isLegacyLauncher: Bool {
        resolvedTileMode == .launcher && collectionID == nil
    }

    // Safe getters with backwards-compatible defaults
    public var resolvedTileMode: TileMode {
        TileMode(rawValue: tileMode ?? "folder") ?? .folder
    }

    public var resolvedPresentationMode: PresentationMode {
        PresentationMode(rawValue: presentation ?? "menu") ?? .menu
    }

    public var resolvedSortMode: SortMode {
        SortMode(rawValue: sortMode ?? "name") ?? .name
    }

    public var resolvedMaxDepth: Int {
        maxDepth ?? 3
    }

    public var resolvedGridColumns: Int {
        gridColumns ?? 5
    }

    public var resolvedShowLabels: Bool {
        showLabels ?? true
    }
}
