import SwiftUI
import AppKit

enum PanelCloseShortcut {
    static func matches(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown, !event.isARepeat else { return false }
        if event.keyCode == 53 { return true }
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        return event.charactersIgnoringModifiers?.lowercased() == "w" &&
            (modifiers == .command || modifiers == .control)
    }
}

struct WindowHeightResizeHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> HeightResizeView {
        HeightResizeView()
    }

    func updateNSView(_ nsView: HeightResizeView, context: Context) {}
}

final class HeightResizeView: NSView {
    private var initialFrame: NSRect?
    private var initialMouseY: CGFloat = 0
    private var cursorTrackingArea: NSTrackingArea?

    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeUpDown)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let cursorTrackingArea { removeTrackingArea(cursorTrackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.activeAlways, .inVisibleRect, .cursorUpdate, .mouseEnteredAndExited], owner: self)
        addTrackingArea(area)
        cursorTrackingArea = area
    }

    override func cursorUpdate(with event: NSEvent) { NSCursor.resizeUpDown.set() }
    override func mouseEntered(with event: NSEvent) { NSCursor.resizeUpDown.set() }
    override func mouseExited(with event: NSEvent) { NSCursor.arrow.set() }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        window?.invalidateCursorRects(for: self)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        NSCursor.resizeUpDown.set()
        initialFrame = window.frame
        initialMouseY = window.convertPoint(toScreen: event.locationInWindow).y
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let initialFrame else { return }
        NSCursor.resizeUpDown.set()
        let mouseY = window.convertPoint(toScreen: event.locationInWindow).y
        let height = min(max(initialFrame.height + initialMouseY - mouseY, window.minSize.height), window.maxSize.height)
        // Keep the top edge anchored while changing only the height.
        let frame = NSRect(x: initialFrame.minX, y: initialFrame.maxY - height, width: initialFrame.width, height: height)
        window.setFrame(frame, display: true)
    }

    override func mouseUp(with event: NSEvent) {
        initialFrame = nil
    }
}

// MARK: - Player Window Accessor
struct PlayerWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.styleMask = [.borderless, .closable, .miniaturizable]
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.isMovable = true
                window.isMovableByWindowBackground = true
                window.backgroundColor = .appBackground
                window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
                
                // Always on top support
                if AudioPlayerViewModel.shared.alwaysOnTop {
                    window.level = .floating
                } else {
                    window.level = .normal
                }
                
                if let contentView = window.contentView {
                    contentView.wantsLayer = true
                    contentView.layer?.cornerRadius = 0
                    contentView.layer?.masksToBounds = true
                }
                
                WindowManager.shared.registerPlayerWindow(window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }
        let targetSize = NSSize(width: 300, height: 140)
        if window.contentView?.frame.size != targetSize {
            window.setContentSize(targetSize)
        }
    }
}

final class PlaylistWindowController {
    static let shared = PlaylistWindowController()
    private var window: NSWindow?

    func open() {
        let width = WindowManager.shared.playerWindow?.frame.width ?? 300
        let window = PlaylistWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 280),
            styleMask: [.borderless, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = L10n.t(.playlist)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.isMovable = false
        window.backgroundColor = .appBackground
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.minSize = NSSize(width: width, height: 200)
        window.maxSize = NSSize(width: width, height: 1200)

        let hosting = NSHostingView(rootView: PlaylistView(viewModel: AudioPlayerViewModel.shared))
        hosting.sizingOptions = []
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = 0
        hosting.layer?.masksToBounds = true
        window.contentView = hosting
        self.window = window
        WindowManager.shared.registerPlaylistWindow(window)
    }
}

private final class PlaylistWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
