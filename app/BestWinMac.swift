import AppKit
import ApplicationServices
import Carbon

private struct SavedWindow {
    let element: AXUIElement
}

final class DesktopController: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let finderCut = FinderCutInterceptor()
    private var savedWindows: [SavedWindow] = []
    private var previousFrontmost: NSRunningApplication?
    private var isDesktopShown = false
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "BestWinMac")
            button.toolTip = "BestWinMac: ⌘D 显示桌面，Finder ⌘X 剪切"
        }
        refreshMenu()

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        updateHotKey()
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.updateHotKey()
        }
    }

    private func updateHotKey() {
        guard AXIsProcessTrusted() else {
            refreshMenu()
            return
        }
        finderCut.start()
        guard hotKey == nil else { return }

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let handler: EventHandlerUPP = { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let controller = Unmanaged<DesktopController>.fromOpaque(context).takeUnretainedValue()
            controller.toggleDesktop()
            return noErr
        }
        let installStatus = InstallEventHandler(GetApplicationEventTarget(), handler, 1, &spec, context, &eventHandler)
        guard installStatus == noErr else {
            NSLog("BestWinMac: InstallEventHandler failed: %d", installStatus)
            return
        }

        let identifier = EventHotKeyID(signature: 0x5744534B, id: 1) // WDSK
        let registerStatus = RegisterEventHotKey(2, UInt32(cmdKey), identifier,
                                                GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &hotKey)
        if registerStatus != noErr {
            NSLog("BestWinMac: RegisterEventHotKey failed: %d", registerStatus)
            if let eventHandler { RemoveEventHandler(eventHandler) }
            eventHandler = nil
        } else {
            NSLog("BestWinMac: Command-D hotkey registered")
        }
        refreshMenu()
    }

    private func refreshMenu() {
        let menu = NSMenu()
        if AXIsProcessTrusted() {
            let title = isDesktopShown ? "恢复窗口" : "显示桌面"
            let action = NSMenuItem(title: title, action: #selector(toggleFromMenu), keyEquivalent: "")
            action.target = self
            menu.addItem(action)
            menu.addItem(NSMenuItem(title: finderCut.isRunning ? "Finder ⌘X 剪切：已启用" : "Finder ⌘X 剪切：未启用",
                                    action: nil, keyEquivalent: ""))
            if hotKey == nil {
                menu.addItem(NSMenuItem(title: "⌘D 快捷键注册失败", action: nil, keyEquivalent: ""))
            }
        } else {
            let permission = NSMenuItem(title: "开启辅助功能权限…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
            permission.target = self
            menu.addItem(permission)
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出 BestWinMac", action: #selector(quitApp), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    @objc private func toggleFromMenu() {
        toggleDesktop()
    }

    private func toggleDesktop() {
        guard AXIsProcessTrusted() else { return }
        if isDesktopShown {
            restoreWindows()
        } else {
            showDesktop()
        }
        refreshMenu()
    }

    private func showDesktop() {
        // On-screen owners limit the action to apps present on the current desktop.
        let windowInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        let visiblePIDs = Set(windowInfo.compactMap { info -> pid_t? in
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t else { return nil }
            return pid
        })

        previousFrontmost = NSWorkspace.shared.frontmostApplication
        savedWindows = []
        for pid in visiblePIDs where pid != ProcessInfo.processInfo.processIdentifier {
            let app = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(app, 0.5)
            var rawWindows: CFTypeRef?
            guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &rawWindows) == .success,
                  let windows = rawWindows as? [AXUIElement] else { continue }
            for window in windows {
                var rawMinimized: CFTypeRef?
                guard AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &rawMinimized) == .success,
                      let minimized = rawMinimized as? Bool, !minimized else { continue }
                if AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue) == .success {
                    savedWindows.append(SavedWindow(element: window))
                }
            }
        }
        isDesktopShown = !savedWindows.isEmpty
    }

    private func restoreWindows() {
        for saved in savedWindows.reversed() {
            _ = AXUIElementSetAttributeValue(saved.element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        savedWindows = []
        isDesktopShown = false
        previousFrontmost?.activate()
        previousFrontmost = nil
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func quitApp() {
        if isDesktopShown { restoreWindows() }
        NSApplication.shared.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if isDesktopShown { restoreWindows() }
    }
}

@main
enum BestWinMacMain {
    static func main() {
        if CommandLine.arguments.contains("--diagnose") {
            print("accessibility=\(AXIsProcessTrusted())")
            return
        }
        let app = NSApplication.shared
        let controller = DesktopController()
        app.delegate = controller
        app.run()
    }
}
