import Foundation

@main
enum DesktopAliasTests {
    static func main() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("RightOpen-tests-\(UUID().uuidString)")
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: root) }
        let destination = root.appendingPathComponent("Desktop")
        try manager.createDirectory(at: destination, withIntermediateDirectories: false)

        let folder = root.appendingPathComponent("文件夹 ' \" $() 空格")
        try manager.createDirectory(at: folder, withIntermediateDirectories: false)
        let file = folder.appendingPathComponent("hello.txt")
        let original = Data("original file contents".utf8)
        try original.write(to: file)

        // Finder must recognize real aliases and resolve both files and folders.
        for source in [folder, file] {
            let alias = try DesktopAlias.create(for: source, in: destination)
            precondition(tryValue { try alias.resourceValues(forKeys: [.isAliasFileKey]).isAliasFile } == true)
            let resolved = try URL(resolvingAliasFileAt: alias, options: .withoutUI)
            precondition(resolved.resolvingSymlinksInPath() == source.resolvingSymlinksInPath())
            let openTarget = try DesktopAlias.targetForOpening(alias)
            precondition(openTarget.resolvingSymlinksInPath() == source.resolvingSymlinksInPath())
        }
        let normalFolder = try DesktopAlias.targetForOpening(folder)
        let normalFile = try DesktopAlias.targetForOpening(file)
        precondition(normalFolder == folder)
        precondition(normalFile == file)

        // Repeated requests preserve the first alias and pick a distinct name.
        let repeated = try DesktopAlias.create(for: file, in: destination)
        precondition(repeated.lastPathComponent == "hello.txt 快捷方式 2")
        let nextName = destination.appendingPathComponent("hello.txt 快捷方式 3")
        try original.write(to: nextName)
        let next = try DesktopAlias.create(for: file, in: destination)
        precondition(next.lastPathComponent == "hello.txt 快捷方式 4")
        precondition(tryValue { try Data(contentsOf: nextName) } == original)

        // A dangling symlink also occupies a name and must never be replaced.
        let dangling = destination.appendingPathComponent("hello.txt 快捷方式 5")
        try manager.createSymbolicLink(at: dangling, withDestinationURL: root.appendingPathComponent("missing"))
        let afterLink = try DesktopAlias.create(for: file, in: destination)
        precondition(afterLink.lastPathComponent == "hello.txt 快捷方式 6")
        precondition(tryValue { try manager.destinationOfSymbolicLink(atPath: dangling.path) }.hasSuffix("missing"))

        precondition(tryValue { try Data(contentsOf: file) } == original)
        precondition(tryValue { try manager.contentsOfDirectory(atPath: destination.path) }.allSatisfy { !$0.hasPrefix(".rightopen-alias-") })
        print("PASS: file/folder aliases, special characters, duplicate names, existing files, dangling symlinks, source preservation and cleanup")
        print("Desktop destination: \(try DesktopAlias.desktopURL().path)")
        if CommandLine.arguments.contains("--desktop") {
            let alias = try DesktopAlias.create(for: root, in: DesktopAlias.desktopURL())
            defer { try? manager.removeItem(at: alias) }
            let resolved = try URL(resolvingAliasFileAt: alias, options: .withoutUI)
            precondition(resolved.resolvingSymlinksInPath() == root.resolvingSymlinksInPath())
            precondition(tryValue { try alias.resourceValues(forKeys: [.isAliasFileKey]).isAliasFile } == true)
            print("PASS: created and resolved a real desktop alias; temporary alias removed on exit")
        }
    }

    private static func tryValue<T>(_ operation: () throws -> T) -> T {
        do { return try operation() } catch { fatalError("Unexpected error: \(error)") }
    }
}
