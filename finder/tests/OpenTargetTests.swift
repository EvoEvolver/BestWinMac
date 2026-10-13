import Foundation

@main
enum OpenTargetTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BestWinMac open target \(UUID().uuidString)", isDirectory: true)
        let folder = root.appendingPathComponent("Folder With Spaces", isDirectory: true)
        let file = folder.appendingPathComponent("notes.md")
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data().write(to: file)

        precondition(OpenTarget.resolve(folder, folderOnly: true) == folder)
        precondition(OpenTarget.resolve(file, folderOnly: true) == folder)
        precondition(OpenTarget.resolve(file, folderOnly: false) == file)
        print("PASS: folders, files, spaces, and direct targets")
    }
}
