import AppKit
import ApplicationServices

// Finder cut behavior follows cmdX's MIT-licensed approach: Cmd-X sends
// Finder Cmd-C, then the next Cmd-V sends Finder Cmd-Option-V if the clipboard
// has not changed. See third_party/cmdX-LICENSE.
final class FinderCutInterceptor {
    private static let syntheticMarker: Int64 = 0x4257_4D43
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var cutState = CutPasteboardState()

    var isRunning: Bool { eventTap != nil }

    func start() {
        guard eventTap == nil else { return }
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                           place: .headInsertEventTap,
                                           options: .defaultTap,
                                           eventsOfInterest: mask,
                                           callback: { _, type, event, context in
                                               guard let context else { return Unmanaged.passUnretained(event) }
                                               let interceptor = Unmanaged<FinderCutInterceptor>.fromOpaque(context).takeUnretainedValue()
                                               return interceptor.handle(type: type, event: event)
                                           },
                                           userInfo: context) else {
            NSLog("BestWinMac: could not start Finder cut event tap")
            return
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
        NSLog("BestWinMac: Finder cut event tap started")
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return nil
        }
        guard type == .keyDown,
              event.getIntegerValueField(.eventSourceUserData) != Self.syntheticMarker,
              NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder" else {
            return Unmanaged.passUnretained(event)
        }

        let flags = event.flags
        guard flags.contains(.maskCommand),
              !flags.contains(.maskAlternate),
              !flags.contains(.maskControl),
              !flags.contains(.maskShift) else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        guard keyCode == 7 || keyCode == 8 || keyCode == 9 else {
            return Unmanaged.passUnretained(event)
        }
        if finderIsEditingText() {
            return Unmanaged.passUnretained(event)
        }

        switch keyCode {
        case 7: // X
            cutState.begin(currentChangeCount: NSPasteboard.general.changeCount)
            postShortcut(keyCode: 8, flags: .maskCommand) // Finder Copy
            return nil
        case 8: // C
            cutState.cancel()
            return Unmanaged.passUnretained(event)
        case 9: // V
            let shouldMove = cutState.consume(currentChangeCount: NSPasteboard.general.changeCount)
            guard shouldMove else { return Unmanaged.passUnretained(event) }
            postShortcut(keyCode: 9, flags: [.maskCommand, .maskAlternate]) // Finder Move
            return nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func finderIsEditingText() -> Bool {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused else { return false }
        let element = focused as! AXUIElement
        var rawRole: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &rawRole) == .success,
              let role = rawRole as? String else { return false }
        return ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"].contains(role)
    }

    private func postShortcut(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else { return }
        for event in [down, up] {
            event.flags = flags
            event.setIntegerValueField(.eventSourceUserData, value: Self.syntheticMarker)
        }
        down.post(tap: .cgAnnotatedSessionEventTap)
        up.post(tap: .cgAnnotatedSessionEventTap)
    }
}
