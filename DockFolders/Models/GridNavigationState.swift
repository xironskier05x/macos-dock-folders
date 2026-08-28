import Foundation

public struct GridNavigationState: Equatable {
    public var selectedIndex: Int
    public var columnsCount: Int
    public var totalItems: Int

    public init(selectedIndex: Int = 0, columnsCount: Int = 5, totalItems: Int = 0) {
        self.columnsCount = max(1, columnsCount)
        self.totalItems = max(0, totalItems)
        if self.totalItems == 0 {
            self.selectedIndex = 0
        } else {
            self.selectedIndex = max(0, min(selectedIndex, self.totalItems - 1))
        }
    }

    public mutating func moveLeft() {
        move(by: -1)
    }

    public mutating func moveRight() {
        move(by: 1)
    }

    public mutating func moveUp() {
        move(by: -columnsCount)
    }

    public mutating func moveDown() {
        move(by: columnsCount)
    }

    public mutating func move(by delta: Int) {
        guard totalItems > 0 else {
            selectedIndex = 0
            return
        }
        var newIdx = selectedIndex + delta
        if newIdx < 0 { newIdx = 0 }
        if newIdx >= totalItems { newIdx = totalItems - 1 }
        selectedIndex = newIdx
    }
}
