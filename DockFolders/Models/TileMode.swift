import Foundation

public enum TileMode: String, Codable, CaseIterable, Identifiable {
    case folder = "folder"
    case launcher = "launcher"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .folder: return "Folder"
        case .launcher: return "Launcher"
        }
    }

    public var description: String {
        switch self {
        case .folder: return "Directly browse and drop files into an actual folder on your Mac."
        case .launcher: return "A virtual collection of apps, files, and folders without copying or moving the originals."
        }
    }

    public var systemImage: String {
        switch self {
        case .folder: return "folder.fill"
        case .launcher: return "square.grid.2x2.fill"
        }
    }
}
