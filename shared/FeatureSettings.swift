import Foundation
import Darwin

struct FeatureSettings: Codable, Equatable {
    var showDesktop = true
    var finderCut = true
    var openVSCode = true
    var copyPath = true
    var desktopAlias = true
}

enum FeatureSettingsStore {
    static func defaultURL() -> URL {
        let home = getpwuid(getuid()).map { String(cString: $0.pointee.pw_dir) } ?? NSHomeDirectory()
        return URL(fileURLWithPath: home, isDirectory: true)
            .appendingPathComponent("Library/Application Support/BestWinMac", isDirectory: true)
            .appendingPathComponent("settings.plist")
    }

    static func load(from url: URL = defaultURL()) -> FeatureSettings {
        guard let data = try? Data(contentsOf: url) else { return FeatureSettings() }
        do {
            return try PropertyListDecoder().decode(FeatureSettings.self, from: data)
        } catch {
            NSLog("BestWinMac: could not read feature settings: %@", error.localizedDescription)
            return FeatureSettings()
        }
    }

    static func save(_ settings: FeatureSettings, to url: URL = defaultURL()) throws {
        let data = try PropertyListEncoder().encode(settings)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
