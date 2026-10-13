import Foundation

enum OpenTarget {
    static func resolve(_ url: URL, folderOnly: Bool,
                        fileManager: FileManager = .default) -> URL {
        guard folderOnly else { return url }
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return isDirectory.boolValue ? url : url.deletingLastPathComponent()
    }
}
