import Foundation

public struct BookmarkService {
    public static func createBookmarkBase64(for path: String) -> String? {
        let url = URL(fileURLWithPath: path)
        guard let data = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil) else {
            return nil
        }
        return data.base64EncodedString()
    }

    public static func resolveBookmarkBase64(_ base64: String) -> (url: URL?, isStale: Bool) {
        guard let data = Data(base64Encoded: base64) else { return (nil, false) }
        var isStale = false
        if let resolved = try? URL(resolvingBookmarkData: data, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &isStale) {
            return (resolved, isStale)
        }
        return (nil, false)
    }
}
