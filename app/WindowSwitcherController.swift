import AppKit
import ApplicationServices
import SwiftUI

@_silgen_name("_AXUIElementGetWindow")
private func getWindowID(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

@_silgen_name("GetProcessForPID")
private func getProcessForPID(_ processIdentifier: pid_t,
                              _ processSerialNumber: UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus

@_silgen_name("_SLPSSetFrontProcessWithOptions")
private func setFrontProcessWindow(_ processSerialNumber: UnsafeMutablePointer<ProcessSerialNumber>,
                                   _ windowID: CGWindowID, _ mode: UInt32) -> CGError

enum WindowSwitcherSelection {
    static func next(current: Int?, count: Int, backwards: Bool) -> Int? {
        guard count > 0 else { return nil }
        guard let current else { return backwards ? count - 1 : min(1, count - 1) }
        return backwards ? (current - 1 + count) % count : (current + 1) % count
    }
}

private struct WindowSwitcherItem: Identifiable {
    let id = UUID()
    let title: String
    let appName: String
    let icon: NSImage
    let isMinimized: Bool
    let application: NSRunningApplication
    let element: AXUIElement
    let windowID: CGWindowID
}

private final class WindowSwitcherModel: ObservableObject {
    @Published var items: [WindowSwitcherItem] = []
    @Published var selectedIndex: Int?
}

private struct WindowSwitcherOverlay: View {
    @ObservedObject var model: WindowSwitcherModel
    let select: (Int) -> Void

    private var columnCount: Int {
        let count = max(model.items.count, 1)
        return min(5, max(1, Int(ceil(sqrt(Double(count) * 1.6)))))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Windows")
                    .font(.title2.weight(.semibold))
                Spacer()
                Text("⌘Tab to move · release ⌘ to open")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columnCount),
                          spacing: 12) {
                    ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                        windowTile(item, selected: model.selectedIndex == index)
                            .onTapGesture { select(index) }
                    }
                }
            }
        }
        .padding(22)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.3), radius: 24, y: 10)
        .padding(28)
    }

    private func windowTile(_ item: WindowSwitcherItem, selected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(nsImage: item.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.appName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    if item.isMinimized {
                        Text("Minimized")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }

            Text(item.title)
                .font(.body.weight(.medium))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
        .background(selected ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.055))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(selected ? Color.accentColor : Color.primary.opacity(0.1),
                        lineWidth: selected ? 3 : 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
    }
}

final class WindowSwitcherController {
    private static let userGeneratedFocusMode: UInt32 = 0x200
    private static let tabKeyCode: CGKeyCode = 48
    private static let escapeKeyCode: CGKeyCode = 53
    private static let leftKeyCode: CGKeyCode = 123
    private static let rightKeyCode: CGKeyCode = 124
    private static let downKeyCode: CGKeyCode = 125
    private static let upKeyCode: CGKeyCode = 126

    private let model = WindowSwitcherModel()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isVisible = false
    private lazy var panel: NSPanel = makePanel()

    var isRunning: Bool { eventTap != nil }

    func start() {
        guard eventTap == nil else { return }
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let types: [CGEventType] = [.keyDown, .keyUp, .flagsChanged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let controller = Unmanaged<WindowSwitcherController>.fromOpaque(context).takeUnretainedValue()
                return controller.handle(type: type, event: event)
            },
            userInfo: context
        ) else {
            NSLog("BestWinMac: could not start window switcher event tap")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
        NSLog("BestWinMac: window switcher event tap started")
    }

    func stop() {
        cancel()
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return nil
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let commandPressed = event.flags.contains(.maskCommand)

        if type == .flagsChanged, isVisible, !commandPressed {
            DispatchQueue.main.async { [weak self] in self?.commitSelection() }
            return Unmanaged.passUnretained(event)
        }

        if keyCode == Self.tabKeyCode, (commandPressed || isVisible) {
            if type == .keyDown,
               event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                let backwards = event.flags.contains(.maskShift)
                DispatchQueue.main.async { [weak self] in self?.advance(backwards: backwards) }
            }
            return nil
        }

        guard isVisible, type == .keyDown else { return Unmanaged.passUnretained(event) }
        if keyCode == Self.escapeKeyCode {
            DispatchQueue.main.async { [weak self] in self?.cancel() }
            return nil
        }
        if [Self.leftKeyCode, Self.upKeyCode, Self.rightKeyCode, Self.downKeyCode].contains(keyCode) {
            let backwards = keyCode == Self.leftKeyCode || keyCode == Self.upKeyCode
            DispatchQueue.main.async { [weak self] in self?.advance(backwards: backwards) }
            return nil
        }
        return Unmanaged.passUnretained(event)
    }

    private func advance(backwards: Bool) {
        if !isVisible {
            model.items = collectWindows()
            guard !model.items.isEmpty else { return }
            isVisible = true
            resizePanel(itemCount: model.items.count)
            panel.orderFrontRegardless()
        }
        model.selectedIndex = WindowSwitcherSelection.next(
            current: model.selectedIndex,
            count: model.items.count,
            backwards: backwards
        )
    }

    private func commitSelection() {
        guard isVisible,
              let index = model.selectedIndex,
              model.items.indices.contains(index) else {
            cancel()
            return
        }
        let item = model.items[index]
        dismiss()
        if item.isMinimized {
            _ = AXUIElementSetAttributeValue(item.element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        var processSerialNumber = ProcessSerialNumber()
        let processStatus = getProcessForPID(item.application.processIdentifier, &processSerialNumber)
        let frontStatus = processStatus == noErr
            ? setFrontProcessWindow(&processSerialNumber, item.windowID, Self.userGeneratedFocusMode)
            : .failure
        if frontStatus != .success {
            NSLog("BestWinMac: window-level focus failed for window %u: %d",
                  item.windowID, frontStatus.rawValue)
            item.application.activate()
        }
        let appElement = AXUIElementCreateApplication(item.application.processIdentifier)
        _ = AXUIElementSetAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, item.element)
        _ = AXUIElementSetAttributeValue(item.element, kAXMainAttribute as CFString, kCFBooleanTrue)
        _ = AXUIElementPerformAction(item.element, kAXRaiseAction as CFString)
    }

    private func select(index: Int) {
        guard model.items.indices.contains(index) else { return }
        model.selectedIndex = index
        commitSelection()
    }

    private func cancel() {
        guard isVisible else { return }
        dismiss()
    }

    private func dismiss() {
        panel.orderOut(nil)
        isVisible = false
        model.items = []
        model.selectedIndex = nil
    }

    private func collectWindows() -> [WindowSwitcherItem] {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated && $0.processIdentifier != ownPID
        }
        let appsByPID = Dictionary(uniqueKeysWithValues: runningApps.map { ($0.processIdentifier, $0) })
        let windowInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        var orderedPIDs: [pid_t] = []
        for info in windowInfo {
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  appsByPID[pid] != nil, !orderedPIDs.contains(pid) else { continue }
            orderedPIDs.append(pid)
        }
        for app in runningApps where !orderedPIDs.contains(app.processIdentifier) {
            orderedPIDs.append(app.processIdentifier)
        }

        return orderedPIDs.flatMap { pid -> [WindowSwitcherItem] in
            guard let application = appsByPID[pid] else { return [] }
            let appElement = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(appElement, 0.35)
            var rawWindows: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &rawWindows) == .success,
                  var windows = rawWindows as? [AXUIElement] else { return [] }

            var rawFocused: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &rawFocused) == .success,
               let focused = rawFocused as! AXUIElement? {
                windows.sort { CFEqual($0, focused) && !CFEqual($1, focused) }
            }

            let appName = application.localizedName ?? "Application"
            let icon = application.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: appName) ?? NSImage()
            return windows.compactMap { window in
                guard axString(window, attribute: kAXRoleAttribute) == kAXWindowRole,
                      let size = axSize(window), size.width >= 80, size.height >= 50 else { return nil }
                var windowID = CGWindowID.zero
                guard getWindowID(window, &windowID) == .success, windowID != 0 else { return nil }
                let title = axString(window, attribute: kAXTitleAttribute)
                let minimized = axBool(window, attribute: kAXMinimizedAttribute) ?? false
                return WindowSwitcherItem(
                    title: title?.isEmpty == false ? title! : "Untitled Window",
                    appName: appName,
                    icon: icon,
                    isMinimized: minimized,
                    application: application,
                    element: window,
                    windowID: windowID
                )
            }
        }
    }

    private func axString(_ element: AXUIElement, attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func axBool(_ element: AXUIElement, attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? Bool
    }

    private func axSize(_ element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value) == .success,
              let axValue = value as! AXValue? else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(axValue, .cgSize, &size) ? size : nil
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.contentViewController = NSHostingController(
            rootView: WindowSwitcherOverlay(model: model) { [weak self] index in
                self?.select(index: index)
            }
        )
        return panel
    }

    private func resizePanel(itemCount: Int) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let columns = min(5, max(1, Int(ceil(sqrt(Double(itemCount) * 1.6)))))
        let rows = Int(ceil(Double(itemCount) / Double(columns)))
        let width = min(screen.visibleFrame.width - 40, max(480, CGFloat(columns) * 230 + 80))
        let height = min(screen.visibleFrame.height - 40, max(240, CGFloat(rows) * 140 + 100))
        panel.setFrame(NSRect(
            x: screen.visibleFrame.midX - width / 2,
            y: screen.visibleFrame.midY - height / 2,
            width: width,
            height: height
        ), display: true)
    }
}
