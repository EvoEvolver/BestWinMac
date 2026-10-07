import AppKit

enum HotCornerGeometry {
    static func contains(_ point: CGPoint, in screenFrame: CGRect, cornerSize: CGFloat = 4) -> Bool {
        point.x >= screenFrame.maxX - cornerSize && point.x <= screenFrame.maxX
            && point.y >= screenFrame.minY && point.y <= screenFrame.minY + cornerSize
    }
}

struct HotCornerTrigger {
    let dwellTime: TimeInterval
    private var enteredAt: TimeInterval?
    private var hasTriggered = false

    init(dwellTime: TimeInterval = 0.3) {
        self.dwellTime = dwellTime
    }

    mutating func update(isInside: Bool, now: TimeInterval) -> Bool {
        guard isInside else {
            enteredAt = nil
            hasTriggered = false
            return false
        }
        guard !hasTriggered else { return false }
        guard let enteredAt else {
            self.enteredAt = now
            return false
        }
        guard now - enteredAt >= dwellTime else { return false }
        hasTriggered = true
        return true
    }
}

final class HotCornerController {
    private let action: () -> Void
    private var timer: Timer?
    private var trigger = HotCornerTrigger()
    private let cornerSize: CGFloat = 4

    var isRunning: Bool { timer != nil }

    init(action: @escaping () -> Void) {
        self.action = action
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        trigger = HotCornerTrigger()
    }

    private func poll() {
        guard let primaryScreen = NSScreen.screens.first else { return }
        let point = NSEvent.mouseLocation
        let isInside = HotCornerGeometry.contains(point, in: primaryScreen.frame, cornerSize: cornerSize)
        if trigger.update(isInside: isInside, now: ProcessInfo.processInfo.systemUptime) {
            action()
        }
    }
}
