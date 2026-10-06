import Cocoa
import FinderSync

/// A context-menu item with its title, target app, and opening behavior.
private struct TargetApp {
    let title: String
    let appPath: String
    /// When true, open a selected file's containing folder instead.
    let folderOnly: Bool
}

@objc(FinderExt)
class FinderExt: FIFinderSync {
    private static let selectedItemTag = 1
    private static let currentFolderTag = 2

    private let apps: [TargetApp] = [
        TargetApp(title: "Open with VS Code",
                  appPath: "/Applications/Visual Studio Code.app",
                  folderOnly: false),
    ]

    override init() {
        super.init()
        // Watch the whole disk so the menu appears in every Finder location.
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")
        let settings = FeatureSettingsStore.load()
        if settings.openVSCode {
            for (index, app) in apps.enumerated() where FileManager.default.fileExists(atPath: app.appPath) {
                let item = menu.addItem(withTitle: app.title,
                                        action: #selector(open(_:)),
                                        keyEquivalent: "")
                item.tag = index
                item.image = icon(for: app.appPath)
            }
        }
        if menuKind == .contextualMenuForItems || menuKind == .contextualMenuForContainer || menuKind == .contextualMenuForSidebar {
            let urls = targets()
            if settings.newMarkdown && creationTarget(for: menuKind) != nil {
                let item = menu.addItem(withTitle: "New Markdown File",
                                        action: #selector(createMarkdown(_:)),
                                        keyEquivalent: "")
                item.target = self
                item.tag = menuKind == .contextualMenuForItems ? Self.selectedItemTag : Self.currentFolderTag
                item.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: nil)
            }
            if !urls.isEmpty {
                if settings.copyPath {
                    let copyItem = menu.addItem(withTitle: "Copy Path",
                                                action: #selector(copyPath(_:)),
                                                keyEquivalent: "")
                    copyItem.target = self
                    copyItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
                }

                if settings.desktopAlias {
                    let item = menu.addItem(withTitle: "Create Desktop Shortcut",
                                            action: #selector(sendToDesktop(_:)),
                                            keyEquivalent: "")
                    item.target = self
                    item.image = NSImage(systemSymbolName: "arrowshape.turn.up.right", accessibilityDescription: nil)
                }
            }
        }
        return menu
    }

    @objc private func createMarkdown(_ sender: NSMenuItem) {
        let controller = FIFinderSyncController.default()
        let target: URL?
        if sender.tag == Self.selectedItemTag {
            let selected = controller.selectedItemURLs() ?? []
            target = selected.count == 1 ? selected.first : nil
        } else {
            target = controller.targetedURL()
        }
        guard let target else {
            showError("Could Not Create Markdown File", details: "The Finder location is no longer available.")
            return
        }
        do {
            let directory = try NewFile.directory(for: target)
            let file = try NewFile.createMarkdown(in: directory)
            NSWorkspace.shared.activateFileViewerSelecting([file])
        } catch {
            showError("Could Not Create Markdown File", details: error.localizedDescription)
        }
    }

    private func creationTarget(for menuKind: FIMenuKind) -> URL? {
        let controller = FIFinderSyncController.default()
        if menuKind == .contextualMenuForItems {
            let selected = controller.selectedItemURLs() ?? []
            return selected.count == 1 ? selected.first : nil
        }
        return controller.targetedURL()
    }

    @objc private func copyPath(_ sender: NSMenuItem) {
        let urls = targets()
        guard !urls.isEmpty else {
            NSLog("BestWinMac: Copy Path had no Finder target")
            return
        }
        let paths = urls.map(\.path).joined(separator: "\n")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if !pasteboard.setString(paths, forType: .string) {
            NSLog("BestWinMac: Copy Path failed to write %ld paths to pasteboard", urls.count)
            NSSound.beep()
        } else {
            NSLog("BestWinMac: Copy Path copied %ld paths", urls.count)
        }
    }

    @objc private func sendToDesktop(_ sender: NSMenuItem) {
        let urls = targets()
        guard !urls.isEmpty else { return }
        do {
            let desktop = try DesktopAlias.desktopURL()
            var failures: [String] = []
            for url in urls {
                do {
                    try DesktopAlias.create(for: url, in: desktop)
                } catch {
                    failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
            if !failures.isEmpty {
                showAliasError(failures.joined(separator: "\n"))
            }
        } catch {
            showAliasError(error.localizedDescription)
        }
    }

    private func showAliasError(_ message: String) {
        showError("Could Not Create Desktop Shortcut", details: message)
    }

    private func showError(_ title: String, details: String) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = details
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func open(_ sender: NSMenuItem) {
        guard apps.indices.contains(sender.tag) else { return }
        let app = apps[sender.tag]

        var urls: [URL] = []
        var failures: [String] = []
        for selected in targets() {
            do {
                let target = try DesktopAlias.targetForOpening(selected)
                urls.append(app.folderOnly ? enclosingDirectory(of: target) : target)
            } catch {
                failures.append("\(selected.lastPathComponent): \(error.localizedDescription)")
            }
        }
        if !failures.isEmpty {
            showError("Could Not Open Alias", details: failures.joined(separator: "\n"))
        }
        guard !urls.isEmpty else { return }

        NSWorkspace.shared.open(urls,
                                withApplicationAt: URL(fileURLWithPath: app.appPath),
                                configuration: NSWorkspace.OpenConfiguration())
    }

    /// Prefer selected items; use the current folder when nothing is selected.
    private func targets() -> [URL] {
        let controller = FIFinderSyncController.default()
        if let selected = controller.selectedItemURLs(), !selected.isEmpty {
            return selected
        }
        if let current = controller.targetedURL() {
            return [current]
        }
        return []
    }

    private func enclosingDirectory(of url: URL) -> URL {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return isDirectory.boolValue ? url : url.deletingLastPathComponent()
    }

    /// Use the target app's own icon so no separate icon asset is needed.
    private func icon(for appPath: String) -> NSImage {
        let image = NSWorkspace.shared.icon(forFile: appPath)
        image.size = NSSize(width: 16, height: 16)
        return image
    }
}
