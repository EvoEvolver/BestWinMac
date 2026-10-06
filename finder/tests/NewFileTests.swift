import Foundation

@main
enum NewFileTests {
    static func main() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("BestWinMac-new-file-\(UUID().uuidString)")
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: root) }

        let folder = root.appendingPathComponent("folder")
        try manager.createDirectory(at: folder, withIntermediateDirectories: false)
        let folderDestination = try NewFile.directory(for: folder)
        precondition(folderDestination.path == folder.path)

        let existing = folder.appendingPathComponent("example.txt")
        try Data("existing".utf8).write(to: existing)
        let fileDestination = try NewFile.directory(for: existing)
        precondition(fileDestination.path == folder.path)

        let first = try NewFile.createMarkdown(in: folder)
        precondition(first.lastPathComponent == "Untitled.md")
        let firstContents = try Data(contentsOf: first)
        precondition(firstContents.isEmpty)
        let second = try NewFile.createMarkdown(in: folder)
        precondition(second.lastPathComponent == "Untitled 2.md")

        let third = folder.appendingPathComponent("Untitled 3.md")
        try Data("keep".utf8).write(to: third)
        let fourth = try NewFile.createMarkdown(in: folder)
        precondition(fourth.lastPathComponent == "Untitled 4.md")
        let thirdContents = try String(contentsOf: third, encoding: .utf8)
        let existingContents = try String(contentsOf: existing, encoding: .utf8)
        precondition(thirdContents == "keep")
        precondition(existingContents == "existing")

        let alias = try DesktopAlias.create(for: folder, in: root)
        let aliasDestination = try NewFile.directory(for: alias)
        precondition(aliasDestination.resolvingSymlinksInPath() == folder.resolvingSymlinksInPath())
        print("PASS: folder, file, alias, empty Markdown, and collision-safe numbering")
    }
}
