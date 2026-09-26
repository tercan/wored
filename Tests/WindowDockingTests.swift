import AppKit

// Window doubles never order real windows onto the user's desktop.
@MainActor
final class DockingTestWindow: NSWindow {
    var testFrame = NSRect.zero
    var testVisible = false
    weak var testParent: NSWindow?
    var presentationCount = 0
    var verifyPresentation: (() -> Void)?

    init(frame: NSRect) {
        super.init(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: true)
        testFrame = frame
    }

    override var frame: NSRect { testFrame }
    override var isVisible: Bool { testVisible }
    override var parent: NSWindow? {
        get { testParent }
        set { testParent = newValue }
    }
    override func setFrame(_ frameRect: NSRect, display flag: Bool) { testFrame = frameRect }
    override func addChildWindow(_ childWin: NSWindow, ordered place: NSWindow.OrderingMode) { childWin.parent = self }
    override func removeChildWindow(_ childWin: NSWindow) { childWin.parent = nil }
    override func orderOut(_ sender: Any?) { testVisible = false }
    override func orderFront(_ sender: Any?) { present() }
    override func orderFrontRegardless() { present() }
    override func makeKeyAndOrderFront(_ sender: Any?) { present() }

    private func present() {
        verifyPresentation?()
        testVisible = true
        presentationCount += 1
    }
}

@MainActor
final class AudioPlayerViewModel {
    static let shared = AudioPlayerViewModel()
    let alwaysOnTop = false
    func togglePlayPause() {}
}

@MainActor
final class InfoPanelController {
    static let shared = InfoPanelController()
    static func close() {}
    func toggleNearPlayerWindow() {}
}

@MainActor
enum SongInfoPanelController { static func close() {} }

@MainActor
final class PlaylistWindowController {
    static let shared = PlaylistWindowController()
    var creationCount = 0
    var window: DockingTestWindow?
    func open() {
        creationCount += 1
        let window = DockingTestWindow(frame: NSRect(x: 0, y: 0, width: 300, height: 280))
        self.window = window
        window.verifyPresentation = { [weak window] in
            guard let window, let player = WindowManager.shared.playerWindow else { fatalError("Missing parent") }
            precondition(window.parent === player && window.frame.maxY == player.frame.minY && window.frame.minX == player.frame.minX)
        }
        WindowManager.shared.registerPlaylistWindow(window)
    }
}

@main
@MainActor
struct WindowDockingTests {
    static func main() {
        _ = NSApplication.shared
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "wored.playlistVisible")
        defaults.set(316.0, forKey: "wored.playlistHeight")
        defer {
            defaults.removeObject(forKey: "wored.playlistVisible")
            defaults.removeObject(forKey: "wored.playlistHeight")
        }

        let manager = WindowManager.shared
        let playlist = DockingTestWindow(frame: NSRect(x: 0, y: 0, width: 300, height: 280))
        manager.registerPlaylistWindow(playlist)
        precondition(!playlist.isVisible && playlist.presentationCount == 0, "Do not display an unanchored playlist")

        let player = DockingTestWindow(frame: NSRect(x: 800, y: 650, width: 300, height: 140))
        playlist.verifyPresentation = {
            precondition(playlist.parent === player && playlist.frame == NSRect(x: 800, y: 334, width: 300, height: 316), "Dock before the first presentation")
        }
        manager.registerPlayerWindow(player)
        precondition(!playlist.isVisible, "Registration alone must not show the playlist before the player")
        player.testVisible = true
        notify(NSWindow.didChangeOcclusionStateNotification, player)
        precondition(playlist.isVisible && playlist.presentationCount == 1, "Resume the pending request when the player appears")
        playlist.verifyPresentation = nil

        player.testFrame = NSRect(x: 550, y: 480, width: 320, height: 110)
        notify(NSWindow.didResizeNotification, player)
        precondition(playlist.frame == NSRect(x: 550, y: 164, width: 320, height: 316), "Follow the final SwiftUI player size")
        player.testFrame.origin.x = 650
        notify(NSWindow.didMoveNotification, player)
        precondition(playlist.frame.minX == 650, "Follow player movement")

        notify(NSWindow.willCloseNotification, playlist)
        player.testVisible = false
        manager.showPlaylist()
        precondition(PlaylistWindowController.shared.creationCount == 0, "Defer creation while the player is hidden")
        player.testVisible = true
        notify(NSWindow.didChangeOcclusionStateNotification, player)
        precondition(PlaylistWindowController.shared.creationCount == 1 && manager.playlistWindow?.isVisible == true)

        notify(NSWindow.willCloseNotification, PlaylistWindowController.shared.window!)
        player.testVisible = false
        manager.showPlaylist()
        manager.hidePlaylist()
        player.testVisible = true
        notify(NSWindow.didChangeOcclusionStateNotification, player)
        precondition(PlaylistWindowController.shared.creationCount == 1 && !manager.isPlaylistVisible, "Do not reopen a cancelled request")
        print("PASS: startup registration order, delayed visibility, pre-show docking, saved height, player resize/move, deferred creation, cancellation")
    }

    private static func notify(_ name: Notification.Name, _ window: NSWindow) {
        NotificationCenter.default.post(name: name, object: window)
    }
}
