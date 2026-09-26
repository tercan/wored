import AppKit

@MainActor
enum PanelFramePersistence {
    static let settings = "Wored.SettingsPanel"
    static let songInfo = "Wored.SongInfoPanel"

    static func restore(_ panel: NSPanel, name: String, preferredScreen: NSScreen?) -> Bool {
        guard panel.setFrameUsingName(name, force: true) else { return false }
        constrain(panel, preferredScreen: preferredScreen)
        return true
    }

    static func constrain(_ panel: NSPanel, preferredScreen: NSScreen?) {
        let frame = constrainedFrame(
            panel.frame,
            minimumSize: panel.minSize,
            maximumSize: panel.maxSize,
            screens: NSScreen.screens.map(\.visibleFrame),
            fallbackScreen: (preferredScreen ?? NSScreen.main)?.visibleFrame
        )
        panel.setFrame(frame, display: false)
    }

    static func constrainedFrame(_ frame: NSRect, minimumSize: NSSize, maximumSize: NSSize, screens: [NSRect], fallbackScreen: NSRect?) -> NSRect {
        guard !screens.isEmpty else { return frame }
        let bestScreen = screens.max {
            intersectionArea(frame, $0) < intersectionArea(frame, $1)
        }!
        let screen = intersectionArea(frame, bestScreen) > 0 ? bestScreen : (fallbackScreen ?? bestScreen)
        let width = min(max(frame.width, minimumSize.width), maximumSize.width, screen.width)
        let height = min(max(frame.height, minimumSize.height), maximumSize.height, screen.height)
        // Preserve the top edge when a smaller display requires reducing the height.
        let x = min(max(frame.minX, screen.minX), screen.maxX - width)
        let y = min(max(frame.maxY - height, screen.minY), screen.maxY - height)
        return NSRect(x: x, y: y, width: width, height: height)
    }

    private static func intersectionArea(_ frame: NSRect, _ screen: NSRect) -> CGFloat {
        let intersection = frame.intersection(screen)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }
}
