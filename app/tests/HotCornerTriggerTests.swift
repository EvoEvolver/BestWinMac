import Foundation

@main
enum HotCornerTriggerTests {
    static func main() {
        var trigger = HotCornerTrigger(dwellTime: 0.3)
        precondition(!trigger.update(isInside: false, now: 0))
        precondition(!trigger.update(isInside: true, now: 1.0))
        precondition(!trigger.update(isInside: true, now: 1.29))
        precondition(trigger.update(isInside: true, now: 1.3))
        precondition(!trigger.update(isInside: true, now: 2.0), "Must fire only once while the pointer remains in the corner")
        precondition(!trigger.update(isInside: false, now: 2.1))
        precondition(!trigger.update(isInside: true, now: 3.0))
        precondition(trigger.update(isInside: true, now: 3.31), "Leaving the corner must rearm it")

        let primary = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        precondition(HotCornerGeometry.contains(CGPoint(x: 1727, y: 0), in: primary))
        precondition(!HotCornerGeometry.contains(CGPoint(x: 1700, y: 0), in: primary))
        let lowerDisplay = CGRect(x: -1920, y: -1080, width: 1920, height: 1080)
        precondition(HotCornerGeometry.contains(CGPoint(x: -1, y: -1079), in: lowerDisplay))
        precondition(!HotCornerGeometry.contains(CGPoint(x: -1, y: -1000), in: lowerDisplay))
        print("PASS: dwell, single activation, rearming, and screen coordinates")
    }
}
