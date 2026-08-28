import Foundation

public struct RuntimeInstallerService {
    public static var bundledRuntimeURL: URL? {
        if let url = Bundle.main.url(forResource: "DockFolderRuntime", withExtension: nil) {
            return url
        }
        // Fallback check in current executable directory or source folder
        let execDir = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS")
        let sibling = execDir.appendingPathComponent("DockFolderRuntime")
        if FileManager.default.fileExists(atPath: sibling.path) {
            return sibling
        }
        return nil
    }

    public static func getOrCreateRuntime() -> URL? {
        if let url = bundledRuntimeURL, FileManager.default.isExecutableFile(atPath: url.path) {
            return url
        }

        // Check cache in Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let runtimePath = appSupport.appendingPathComponent("macOS Dock Folders/Runtime/DockFolderRuntime")
        if FileManager.default.isExecutableFile(atPath: runtimePath.path) {
            return runtimePath
        }

        return nil
    }
}
