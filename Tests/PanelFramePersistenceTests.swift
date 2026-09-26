import AppKit

@main
@MainActor
struct PanelFramePersistenceTests {
    static func main() {
        let main = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let secondary = NSRect(x: 1440, y: -200, width: 1920, height: 1080)
        let minimum = NSSize(width: 300, height: 320)
        let maximum = NSSize(width: 300, height: 1200)

        func restore(_ frame: NSRect, screens: [NSRect] = [main]) -> NSRect {
            PanelFramePersistence.constrainedFrame(frame, minimumSize: minimum, maximumSize: maximum, screens: screens, fallbackScreen: main)
        }

        let saved = NSRect(x: 1700, y: 100, width: 300, height: 640)
        precondition(restore(saved, screens: [main, secondary]) == saved, "Preserve the original monitor and resized height")
        let disconnected = restore(saved)
        precondition(main.contains(disconnected) && disconnected.height == 640, "Recover a panel from a disconnected display")
        let tall = restore(NSRect(x: 50, y: -100, width: 300, height: 1200))
        precondition(tall.height == 900 && main.contains(tall), "Fit a tall panel to a smaller display")
        let above = restore(NSRect(x: 100, y: 850, width: 300, height: 440))
        precondition(above.maxY == main.maxY && above.minX == 100, "Keep the title and footer reachable")
        let tooSmall = restore(NSRect(x: 100, y: 100, width: 200, height: 100))
        precondition(tooSmall.size == minimum, "Honor the panel minimum size")
        let leftDisplay = NSRect(x: -1440, y: -200, width: 1440, height: 900)
        let leftFrame = NSRect(x: -1100, y: -100, width: 300, height: 440)
        precondition(restore(leftFrame, screens: [main, leftDisplay]) == leftFrame, "Support negative desktop coordinates")
        precondition(restore(saved, screens: []) == saved, "No screen must not destroy stored geometry")
        let fixed = PanelFramePersistence.constrainedFrame(saved, minimumSize: NSSize(width: 280, height: 460), maximumSize: NSSize(width: 280, height: 460), screens: [main], fallbackScreen: main)
        precondition(fixed.size == NSSize(width: 280, height: 460), "Settings must retain their fixed dimensions")
        print("PASS: saved position, resized height, multiple displays, disconnected display, visible bounds, minimum size, fixed settings size, no display")
    }
}
