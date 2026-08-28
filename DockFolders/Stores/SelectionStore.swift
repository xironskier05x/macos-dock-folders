import Foundation
import SwiftUI

public class SelectionStore: ObservableObject {
    @Published public var selectedTileId: String?
    @Published public var searchText: String = ""
    @Published public var isShowingNewTileSheet: Bool = false
    @Published public var isShowingSettings: Bool = false
    @Published public var editingTile: DockTile?

    public init(selectedTileId: String? = nil) {
        self.selectedTileId = selectedTileId
    }
}
