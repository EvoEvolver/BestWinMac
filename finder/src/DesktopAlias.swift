import Foundation
import Darwin

enum DesktopAlias {
    static func targetForOpening(_ url: URL) throws -> URL {
        let values = try url.resourceValues(forKeys: [.isAliasFileKey])
        guard values.isAliasFile == true else { return url }
        return try URL(resolvingAliasFileAt: url, options: .withoutUI)
    }

    // Sandboxed Foundation home/desktop URLs point inside the app container.
    // Use the account's actual home so aliases appear on the user's desktop.
    static func desktopURL() throws -> URL {
        guard let home = getpwuid(getuid())?.pointee.pw_dir else {
            throw CocoaError(.fileNoSuchFile)
        }
        return URL(fileURLWithPath: String(cString: home), isDirectory: true)
            .appendingPathComponent("Desktop", isDirectory: true)
    }

    @discardableResult
    static func create(for source: URL, in directory: URL) throws -> URL {
        let manager = FileManager.default
        let bookmark = try source.bookmarkData(
            options: .suitableForBookmarkFile,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        // Finish the alias before publishing it; never overwrite an existing item.
        let staging = directory.appendingPathComponent(".bestwinmac-alias-\(UUID().uuidString)")
        try manager.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? manager.removeItem(at: staging) }
        let prepared = staging.appendingPathComponent("alias")
        try URL.writeBookmarkData(bookmark, to: prepared)

        var baseName = source.lastPathComponent
        while baseName.utf8.count > 200 { baseName.removeLast() }
        for number in 1...10_000 {
            let suffix = number == 1 ? " Shortcut" : " Shortcut \(number)"
            let destination = directory.appendingPathComponent(baseName + suffix)
            do {
                try manager.moveItem(at: prepared, to: destination)
                return destination
            } catch let error as NSError {
                guard error.domain == NSCocoaErrorDomain,
                      error.code == NSFileWriteFileExistsError else { throw error }
            }
        }
        throw CocoaError(.fileWriteFileExists)
    }
}
