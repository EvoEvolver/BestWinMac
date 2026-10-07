import AppKit
import ApplicationServices
import Carbon
import SwiftUI

private struct SavedWindow {
    let element: AXUIElement
}

final class DesktopController: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let finderCut = FinderCutInterceptor()
    private lazy var hotCorner = HotCornerController { [weak self] in
        self?.toggleDesktopFromHotCorner()
    }
    private lazy var settingsModel = SettingsModel(settings: FeatureSettingsStore.load()) { [weak self] in
        self?.syncFeatures()
    }
    private var settingsWindow: NSWindow?
    private var savedWindows: [SavedWindow] = []
    private var previousFrontmost: NSRunningApplication?
    private var isDesktopShown = false
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let button = statusItem.button {
            if let path = Bundle.main.path(forResource: "BestWinMacMenuBar", ofType: "png"),
               let image = NSImage(contentsOfFile: path) {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = true
                button.image = image
            } else {
                button.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "BestWinMac")
            }
            button.toolTip = "BestWinMac"
        }
        if settingsModel.settings.showDesktop || settingsModel.settings.showDesktopHotCorner
            || settingsModel.settings.finderCut {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        syncFeatures()
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.syncFeatures()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    private func syncFeatures() {
        let settings = settingsModel.settings
        let trusted = AXIsProcessTrusted()
        if settingsModel.accessibilityGranted != trusted {
            settingsModel.accessibilityGranted = trusted
        }
        if settings.finderCut && trusted {
            finderCut.start()
        } else {
            finderCut.stop()
        }
        if settings.showDesktopHotCorner && trusted {
            hotCorner.start()
        } else {
            hotCorner.stop()
        }
        if settings.showDesktop && trusted {
            registerHotKey()
        } else {
            unregisterHotKey()
        }
        if !settings.showDesktop && !settings.showDesktopHotCorner && isDesktopShown { restoreWindows() }
        refreshMenu()
    }

    private func registerHotKey() {
        guard hotKey == nil else { return }

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let handler: EventHandlerUPP = { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let controller = Unmanaged<DesktopController>.fromOpaque(context).takeUnretainedValue()
            controller.toggleDesktopFromShortcut()
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
    }

    private func unregisterHotKey() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
        if let eventHandler { RemoveEventHandler(eventHandler) }
        eventHandler = nil
    }

    private func refreshMenu() {
        let menu = NSMenu()
        let settings = settingsModel.settings
        let trusted = AXIsProcessTrusted()
        let desktopFeatureEnabled = settings.showDesktop || settings.showDesktopHotCorner
        if desktopFeatureEnabled && trusted {
            let title = isDesktopShown ? "Restore Windows" : "Show Desktop"
            let action = NSMenuItem(title: title, action: #selector(toggleFromMenu), keyEquivalent: "")
            action.target = self
            menu.addItem(action)
        }
        if settings.finderCut && trusted {
            menu.addItem(NSMenuItem(title: finderCut.isRunning ? "Finder Cut: Enabled" : "Finder Cut: Unavailable",
                                    action: nil, keyEquivalent: ""))
        }
        if settings.showDesktop && trusted && hotKey == nil {
            menu.addItem(NSMenuItem(title: "Command-D Shortcut Unavailable", action: nil, keyEquivalent: ""))
        }
        if (desktopFeatureEnabled || settings.finderCut) && !trusted {
            let permission = NSMenuItem(title: "Grant Accessibility Access…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
            permission.target = self
            menu.addItem(permission)
        }
        if !menu.items.isEmpty { menu.addItem(.separator()) }
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit BestWinMac", action: #selector(quitApp), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    @objc private func toggleFromMenu() {
        toggleDesktop()
    }

    private func toggleDesktopFromShortcut() {
        guard settingsModel.settings.showDesktop else { return }
        toggleDesktop()
    }

    private func toggleDesktopFromHotCorner() {
        guard settingsModel.settings.showDesktopHotCorner else { return }
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

    @objc private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsPanel(
                model: settingsModel,
                openAccessibilitySettings: { [weak self] in self?.openAccessibilitySettings() }
            )))
            window.title = "BestWinMac"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        if isDesktopShown { restoreWindows() }
        NSApplication.shared.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if isDesktopShown { restoreWindows() }
        unregisterHotKey()
        hotCorner.stop()
        finderCut.stop()
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
