import Foundation
import SwiftUI

public class PreferencesStore: ObservableObject {
    public static let shared = PreferencesStore()

    @AppStorage("defaultOutputDirectory") public var defaultOutputDirectoryPath: String = TileDiscoveryService.defaultOutputDirectory.path
    @AppStorage("defaultTileMode") public var defaultTileModeRaw: String = TileMode.launcher.rawValue
    @AppStorage("defaultPresentation") public var defaultPresentationRaw: String = PresentationMode.grid.rawValue
    @AppStorage("defaultGridColumns") public var defaultGridColumns: Int = 5
    @AppStorage("defaultShowLabels") public var defaultShowLabels: Bool = true
    @AppStorage("defaultSortMode") public var defaultSortModeRaw: String = SortMode.custom.rawValue
    @AppStorage("autoAddToDock") public var autoAddToDock: Bool = false
    @AppStorage("confirmDeletion") public var confirmDeletion: Bool = true

    public var defaultOutputDirectory: URL {
        URL(fileURLWithPath: defaultOutputDirectoryPath)
    }

    public var defaultTileMode: TileMode {
        TileMode(rawValue: defaultTileModeRaw) ?? .launcher
    }

    public var defaultPresentation: PresentationMode {
        PresentationMode(rawValue: defaultPresentationRaw) ?? .grid
    }

    public var defaultSortMode: SortMode {
        SortMode(rawValue: defaultSortModeRaw) ?? .custom
    }
}
