import Foundation
import CoreGraphics

@main
enum WindowSwitcherSelectionTests {
    static func main() {
        precondition(WindowSwitcherSelection.next(current: nil, count: 0, backwards: false) == nil)
        precondition(WindowSwitcherSelection.next(current: nil, count: 1, backwards: false) == 0)
        precondition(WindowSwitcherSelection.next(current: nil, count: 4, backwards: false) == 1)
        precondition(WindowSwitcherSelection.next(current: nil, count: 4, backwards: true) == 3)
        precondition(WindowSwitcherSelection.next(current: 3, count: 4, backwards: false) == 0)
        precondition(WindowSwitcherSelection.next(current: 0, count: 4, backwards: true) == 3)

        let windowID: CGWindowID = 0x1234_5678
        let event = WindowFocusEvent.makeKey(windowID: windowID)
        precondition(event.count == 0x100)
        precondition(event[0x04] == 0xf8)
        precondition(event[0x08] == UInt8(CGEventType.leftMouseDown.rawValue))
        precondition(event[0x3a] == 0x10)
        var decodedWindowID = CGWindowID.zero
        withUnsafeMutableBytes(of: &decodedWindowID) { destination in
            event.withUnsafeBytes { source in
                destination.copyBytes(from: source[0x3c..<0x40])
            }
        }
        precondition(decodedWindowID == windowID)
        print("PASS: selection wrapping and targeted key-window event")
    }
}
