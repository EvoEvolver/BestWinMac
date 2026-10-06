import Cocoa
import FinderSync

/// 一个右键菜单项：菜单标题 + 目标 App 路径 + 打开策略
private struct TargetApp {
    let title: String
    let appPath: String
    /// true 时，选中的若是文件就改用它所在的文件夹。
    /// 终端必须这样，否则会把文件本身当命令执行。
    let folderOnly: Bool
}

@objc(FinderExt)
class FinderExt: FIFinderSync {

    private let apps: [TargetApp] = [
        TargetApp(title: "用 VSCode 打开",
                  appPath: "/Applications/Visual Studio Code.app",
                  folderOnly: false),
    ]

    override init() {
        super.init()
        // 监控整个磁盘，菜单才能在任意路径下出现
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")
        for (index, app) in apps.enumerated() where FileManager.default.fileExists(atPath: app.appPath) {
            let item = menu.addItem(withTitle: app.title,
                                    action: #selector(open(_:)),
                                    keyEquivalent: "")
            item.tag = index
            item.image = icon(for: app.appPath)
        }
        if menuKind == .contextualMenuForItems || menuKind == .contextualMenuForContainer || menuKind == .contextualMenuForSidebar {
            let urls = targets()
            if !urls.isEmpty {
                let copyItem = menu.addItem(withTitle: "Copy Path",
                                            action: #selector(copyPath(_:)),
                                            keyEquivalent: "")
                copyItem.target = self
                copyItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)

                let item = menu.addItem(withTitle: "发送到桌面快捷方式",
                                        action: #selector(sendToDesktop(_:)),
                                        keyEquivalent: "")
                item.target = self
                item.image = NSImage(systemSymbolName: "arrowshape.turn.up.right", accessibilityDescription: nil)
            }
        }
        return menu
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
                    failures.append("\(url.lastPathComponent)：\(error.localizedDescription)")
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
        showError("无法创建桌面快捷方式", details: message)
    }

    private func showError(_ title: String, details: String) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = details
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
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
                failures.append("\(selected.lastPathComponent)：\(error.localizedDescription)")
            }
        }
        if !failures.isEmpty {
            showError("无法打开替身", details: failures.joined(separator: "\n"))
        }
        guard !urls.isEmpty else { return }

        NSWorkspace.shared.open(urls,
                                withApplicationAt: URL(fileURLWithPath: app.appPath),
                                configuration: NSWorkspace.OpenConfiguration())
    }

    /// 选中项优先；在窗口空白处右键时没有选中项，退回当前所在文件夹
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

    /// 直接取目标 App 自己的图标，省掉打包图片资源，换 App 也不用换图
    private func icon(for appPath: String) -> NSImage {
        let image = NSWorkspace.shared.icon(forFile: appPath)
        image.size = NSSize(width: 16, height: 16)
        return image
    }
}
