import Foundation

@main
enum WindowSwitcherSelectionTests {
    static func main() {
        precondition(WindowSwitcherSelection.next(current: nil, count: 0, backwards: false) == nil)
        precondition(WindowSwitcherSelection.next(current: nil, count: 1, backwards: false) == 0)
        precondition(WindowSwitcherSelection.next(current: nil, count: 4, backwards: false) == 1)
        precondition(WindowSwitcherSelection.next(current: nil, count: 4, backwards: true) == 3)
        precondition(WindowSwitcherSelection.next(current: 3, count: 4, backwards: false) == 0)
        precondition(WindowSwitcherSelection.next(current: 0, count: 4, backwards: true) == 3)
        print("PASS: initial selection, forward and backward wrapping")
    }
}
