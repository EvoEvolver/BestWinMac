import Foundation
import Darwin

enum NewFile {
    static func directory(for target: URL) throws -> URL {
        let resolved = try DesktopAlias.targetForOpening(target)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDirectory) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return isDirectory.boolValue ? resolved : resolved.deletingLastPathComponent()
    }

    static func createMarkdown(in directory: URL) throws -> URL {
        for number in 1...10_000 {
            let name = number == 1 ? "未命名.md" : "未命名 \(number).md"
            let destination = directory.appendingPathComponent(name)
            let descriptor = open(destination.path, O_WRONLY | O_CREAT | O_EXCL, 0o644)
            if descriptor >= 0 {
                _ = close(descriptor)
                return destination
            }
            if errno != EEXIST {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            }
        }
        throw CocoaError(.fileWriteFileExists)
    }
}
