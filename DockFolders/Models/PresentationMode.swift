import Foundation

public enum PresentationMode: String, Codable, CaseIterable, Identifiable {
    case menu = "menu"
    case grid = "grid"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .menu: return "List Menu"
        case .grid: return "Icon Grid"
        }
    }

    public var description: String {
        switch self {
        case .menu: return "Native hierarchical macOS popup menu with instant subfolder navigation."
        case .grid: return "Visual app-launcher grid with app icons, search filtering, and keyboard navigation."
        }
    }

    public var systemImage: String {
        switch self {
        case .menu: return "list.bullet"
        case .grid: return "square.grid.3x3.fill"
        }
    }
}
