@main
enum CutPasteboardStateTests {
    static func main() {
        var state = CutPasteboardState()
        state.begin(currentChangeCount: 10)
        precondition(state.consume(currentChangeCount: 11))
        precondition(!state.consume(currentChangeCount: 11), "A second paste must be ordinary paste")

        state.begin(currentChangeCount: 11)
        precondition(!state.consume(currentChangeCount: 13), "A changed clipboard must not move old files")

        state.begin(currentChangeCount: 20)
        state.cancel()
        precondition(!state.consume(currentChangeCount: 21), "Finder Copy must cancel a pending cut")
        print("PASS: one-shot move, changed clipboard, and cancelled cut")
    }
}
