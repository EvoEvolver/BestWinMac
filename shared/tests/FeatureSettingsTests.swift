import Foundation

@main
enum FeatureSettingsTests {
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BestWinMac-settings-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("settings.plist")

        precondition(FeatureSettingsStore.load(from: file) == FeatureSettings())
        var settings = FeatureSettings()
        settings.showDesktop = false
        settings.copyPath = false
        try FeatureSettingsStore.save(settings, to: file)
        precondition(FeatureSettingsStore.load(from: file) == settings)
        precondition(FeatureSettingsStore.load(from: file).finderCut)
        precondition(FeatureSettingsStore.load(from: file).openVSCode)
        precondition(FeatureSettingsStore.load(from: file).desktopAlias)
        precondition(FeatureSettingsStore.load(from: file).newMarkdown)

        let previousVersion: [String: Bool] = [
            "showDesktop": false, "finderCut": true, "openVSCode": true,
            "copyPath": false, "desktopAlias": true
        ]
        let oldData = try PropertyListSerialization.data(fromPropertyList: previousVersion,
                                                         format: .xml, options: 0)
        try oldData.write(to: file)
        let migrated = FeatureSettingsStore.load(from: file)
        precondition(!migrated.showDesktop && !migrated.copyPath)
        precondition(migrated.newMarkdown)
        print("PASS: defaults, independent settings, and older settings migration")
    }
}
