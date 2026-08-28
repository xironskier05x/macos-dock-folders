import Foundation

public enum SortMode: String, Codable, CaseIterable, Identifiable {
    case name = "name"
    case recent = "recent"
    case kind = "kind"
    case custom = "custom"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .name: return "Name (A–Z)"
        case .recent: return "Recently Modified"
        case .kind: return "Kind (Apps, Folders, Files)"
        case .custom: return "Custom Order"
        }
    }

    public var systemImage: String {
        switch self {
        case .name: return "textformat.abc"
        case .recent: return "clock.arrow.circlepath"
        case .kind: return "square.stack.3d.down.right"
        case .custom: return "arrow.up.arrow.down"
        }
    }
}
