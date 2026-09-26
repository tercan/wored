import SwiftUI
import AppKit
import Combine

extension NSUserInterfaceItemIdentifier {
    static let woredPlayerWindow = NSUserInterfaceItemIdentifier("wored.playerWindow")
    static let woredPlaylistWindow = NSUserInterfaceItemIdentifier("wored.playlistWindow")
    static let woredSettingsPanel = NSUserInterfaceItemIdentifier("wored.settingsPanel")
    static let woredSongInfoPanel = NSUserInterfaceItemIdentifier("wored.songInfoPanel")
}

// MARK: - Window Manager for Pinning
class WindowManager: ObservableObject {
    static let shared = WindowManager()
    
    @Published var isPlaylistVisible = false
    weak var playerWindow: NSWindow?
    weak var playlistWindow: NSWindow?
    
    private var playerObserver: NSObjectProtocol?
    private var playlistObserver: NSObjectProtocol?
    private var playerKeyObserver: NSObjectProtocol?
    private var playlistKeyObserver: NSObjectProtocol?
    private var playerMainObserver: NSObjectProtocol?
    private var playlistMainObserver: NSObjectProtocol?
    private var playlistResizeObserver: NSObjectProtocol?
    private var keyboardMonitor: Any?
    private var isForegroundSyncing = false
    private var didAlignPlaylistOnce = false
    private var isSyncingFrame = false
    private var pendingShowPlaylist = false
    private let playlistHeightKey = "wored.playlistHeight"
    private let playlistVisibleKey = "wored.playlistVisible"
    private var appActiveObserver: NSObjectProtocol?
    private var appTerminateObserver: NSObjectProtocol?
    private var isAppTerminating = false
    private var arePlayerWindowsHidden = false
    
    private init() {
        pendingShowPlaylist = UserDefaults.standard.bool(forKey: playlistVisibleKey)
        appActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.bringWindowsToFrontIfNeeded()
        }
        appTerminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isAppTerminating = true
            if let visible = self?.isPlaylistVisible, let key = self?.playlistVisibleKey {
                UserDefaults.standard.set(visible, forKey: key)
            }
        }
        configureKeyboardShortcuts()
    }

    deinit {
        if let keyboardMonitor {
            NSEvent.removeMonitor(keyboardMonitor)
        }
    }

    private func configureKeyboardShortcuts() {
        guard keyboardMonitor == nil else { return }
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if self.handleWindowShortcut(event) { return nil }
            guard self.shouldHandleSpacebar(event) else { return event }
            AudioPlayerViewModel.shared.togglePlayPause()
            return nil
        }
    }

    private func handleWindowShortcut(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard modifiers == .command, !event.isARepeat,
              NSApp.isActive, NSApp.modalWindow == nil else { return false }
        if let window = NSApp.keyWindow {
            guard window.attachedSheet == nil,
                  isPlaybackShortcutWindow(window) || window.identifier?.rawValue == "wored.menuBarPanel" else { return false }
        } else {
            guard playerWindow?.isVisible == true || playlistWindow?.isVisible == true else { return false }
        }
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "l":
            togglePlaylist()
        case ",":
            InfoPanelController.shared.toggleNearPlayerWindow()
        default:
            return false
        }
        return true
    }

    private func shouldHandleSpacebar(_ event: NSEvent) -> Bool {
        guard event.keyCode == 49, !event.isARepeat else { return false }

        let blockedModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        guard event.modifierFlags.intersection(blockedModifiers).isEmpty else { return false }

        guard let keyWindow = NSApp.keyWindow,
              isPlaybackShortcutWindow(keyWindow) else { return false }

        return !isTextInputFocused(in: keyWindow)
    }

    private func isPlaybackShortcutWindow(_ window: NSWindow) -> Bool {
        if window === playerWindow || window === playlistWindow {
            return true
        }

        let supportedIdentifiers: Set<NSUserInterfaceItemIdentifier> = [
            .woredPlayerWindow,
            .woredPlaylistWindow,
            .woredSettingsPanel,
            .woredSongInfoPanel
        ]

        guard let identifier = window.identifier else { return false }
        return supportedIdentifiers.contains(identifier)
    }

    private func isTextInputFocused(in window: NSWindow) -> Bool {
        guard let responder = window.firstResponder else { return false }

        if responder is NSTextView || responder is NSTextField {
            return true
        }

        guard var view = responder as? NSView else { return false }
        while let superview = view.superview {
            if superview is NSTextField {
                return true
            }
            view = superview
        }

        return false
    }
    
    func registerPlayerWindow(_ window: NSWindow) {
        playerWindow = window
        window.identifier = .woredPlayerWindow
        
        // Synch always on top state
        window.level = AudioPlayerViewModel.shared.alwaysOnTop ? .floating : .normal
        
        enforcePlaylistWidth()
        
        // Observe player window movement
        playerObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.syncPlaylistFrameToPlayer()
        }
        
        playerKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.syncForeground(from: window)
        }
        
        playerMainObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.syncForeground(from: window)
        }
    }
    
    func registerPlaylistWindow(_ window: NSWindow) {
        playlistWindow = window
        window.identifier = .woredPlaylistWindow
        isPlaylistVisible = window.isVisible
        
        // Observe playlist window movement
        playlistObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.syncPlaylistFrameToPlayer()
        }

        playlistResizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.handlePlaylistResize()
        }
        
        playlistKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.syncForeground(from: window)
        }
        
        playlistMainObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.syncForeground(from: window)
        }
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.isPlaylistVisible = false
            self?.detachPlaylistFromPlayer()
            self?.playlistWindow = nil
            guard self?.isAppTerminating != true else { return }
            if let key = self?.playlistVisibleKey {
                UserDefaults.standard.set(false, forKey: key)
            }
        }

        if pendingShowPlaylist {
            showPlaylist()
            pendingShowPlaylist = false
        } else if !didAlignPlaylistOnce {
            alignPlaylistBelowPlayer()
            didAlignPlaylistOnce = true
            window.orderOut(nil)
            isPlaylistVisible = false
        }
    }
    
    private func syncPlaylistFrameToPlayer() {
        guard let player = playerWindow, let playlist = playlistWindow, playlist.isVisible else { return }
        guard !isSyncingFrame else { return }
        isSyncingFrame = true
        defer { isSyncingFrame = false }
        
        let height = playlist.frame.height
        var newFrame = playlist.frame
        newFrame.size.width = player.frame.width
        newFrame.origin.x = player.frame.minX
        newFrame.origin.y = player.frame.minY - height
        playlist.setFrame(newFrame, display: true)
        enforcePlaylistWidth()
    }
    
    private func bringToFront(_ window: NSWindow) {
        guard window.isVisible, !window.isMiniaturized else { return }
        if !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
        }
        window.orderFrontRegardless()
    }

    private func alignPlaylistBelowPlayer() {
        guard let player = playerWindow, let playlist = playlistWindow else { return }
        let playerFrame = player.frame
        let storedHeight = CGFloat(UserDefaults.standard.double(forKey: playlistHeightKey))
        let targetHeight = storedHeight > 0 ? storedHeight : playlist.frame.height
        
        var playlistFrame = playlist.frame
        playlistFrame.size.width = playerFrame.width
        playlistFrame.size.height = targetHeight
        playlistFrame.origin.x = playerFrame.minX
        playlistFrame.origin.y = playerFrame.minY - targetHeight
        playlist.setFrame(playlistFrame, display: true)
        enforcePlaylistWidth()
    }
    
    private func handlePlaylistResize() {
        guard let playlist = playlistWindow, let player = playerWindow else { return }
        guard !isSyncingFrame else { return }
        isSyncingFrame = true
        defer { isSyncingFrame = false }
        
        let height = playlist.frame.height
        UserDefaults.standard.set(Double(height), forKey: playlistHeightKey)
        
        var frame = playlist.frame
        frame.size.width = player.frame.width
        frame.origin.x = player.frame.minX
        frame.origin.y = player.frame.minY - height
        playlist.setFrame(frame, display: true)
        enforcePlaylistWidth()
    }

    private func enforcePlaylistWidth() {
        guard let player = playerWindow, let playlist = playlistWindow else { return }
        let width = player.frame.width
        playlist.minSize.width = width
        playlist.maxSize.width = width
    }

    private func attachPlaylistToPlayer() {
        guard let player = playerWindow, let playlist = playlistWindow else { return }
        if playlist.parent != player {
            player.addChildWindow(playlist, ordered: .below)
        }
    }

    private func detachPlaylistFromPlayer() {
        guard let player = playerWindow, let playlist = playlistWindow else { return }
        if playlist.parent == player {
            player.removeChildWindow(playlist)
        }
    }
    
    private func syncForeground(from source: NSWindow) {
        guard !isForegroundSyncing, !arePlayerWindowsHidden else { return }
        isForegroundSyncing = true
        defer { isForegroundSyncing = false }
        
        guard let player = playerWindow, let playlist = playlistWindow else { return }
        if source === player {
            bringToFront(playlist)
        } else if source === playlist {
            bringToFront(player)
        }
        attachPlaylistToPlayer()
    }

    private func bringWindowsToFrontIfNeeded() {
        guard !arePlayerWindowsHidden else { return }
        guard let player = playerWindow else { return }
        bringToFront(player)
        if let playlist = playlistWindow, playlist.isVisible {
            bringToFront(playlist)
        }
    }
    
    func hidePlayerWindows() {
        arePlayerWindowsHidden = true
        InfoPanelController.close()
        SongInfoPanelController.close()
        playlistWindow?.orderOut(nil)
        playerWindow?.orderOut(nil)
    }

    func showPlayerWindows() {
        arePlayerWindowsHidden = false
        playerWindow?.deminiaturize(nil)
        playerWindow?.makeKeyAndOrderFront(nil)
        if isPlaylistVisible {
            showPlaylist()
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func showPlaylist() {
        guard let playlist = playlistWindow else { return }
        alignPlaylistBelowPlayer()
        attachPlaylistToPlayer()
        playlist.orderFront(nil)
        isPlaylistVisible = true
        UserDefaults.standard.set(true, forKey: playlistVisibleKey)
    }
    
    func hidePlaylist() {
        guard let playlist = playlistWindow else { return }
        detachPlaylistFromPlayer()
        playlist.orderOut(nil)
        isPlaylistVisible = false
        UserDefaults.standard.set(false, forKey: playlistVisibleKey)
    }
    
    func togglePlaylist() {
        if let playlist = playlistWindow {
            if playlist.isVisible {
                hidePlaylist()
            } else {
                showPlaylist()
            }
        } else {
            pendingShowPlaylist = true
            PlaylistWindowController.shared.open()
        }
    }

    func restorePlaylistIfNeeded() {
        guard UserDefaults.standard.bool(forKey: playlistVisibleKey) else { return }
        if let playlist = playlistWindow {
            if !playlist.isVisible {
                showPlaylist()
            }
        } else {
            pendingShowPlaylist = true
            PlaylistWindowController.shared.open()
        }
    }
    
}
