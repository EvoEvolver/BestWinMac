struct CutPasteboardState {
    private var expectedChangeCount: Int?

    mutating func begin(currentChangeCount: Int) {
        expectedChangeCount = currentChangeCount &+ 1
    }

    mutating func cancel() {
        expectedChangeCount = nil
    }

    mutating func consume(currentChangeCount: Int) -> Bool {
        defer { cancel() }
        return expectedChangeCount == currentChangeCount
    }
}
