//
//  woredApp.swift
//  wored
//
//  Created by Tercan Keskin on 3.01.2026.
//

import SwiftUI
import AppKit
import Combine

// MARK: - App Color Palette
extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: 1.0
        )
    }
}

extension Color {
    private static func dynamic(light: String, dark: String) -> Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(hex: dark)
                : NSColor(hex: light)
        }))
    }

    static let appBackground = dynamic(light: "F5F7FA", dark: "0A1226")
    static let appSecondary = dynamic(light: "FFFFFF", dark: "0E1A33")
    static let appAccent = dynamic(light: "E4E9F2", dark: "13224A")
    // AppHighlight ve text renkleri tema değişince de aynı kalabilir veya uyarlanabilir
    // Şimdilik highlight'ı sabit tutalım, textleri uyarlayalım
    static let appHighlight = Color(hex: "003999") 
    static let appHighlightText = dynamic(light: "003999", dark: "C8D8FF")
    static let appControlDefault = dynamic(light: "D1D9E6", dark: "0C328C")
    static let appControlActive = Color(hex: "448AFF")
    static let appTextPrimary = dynamic(light: "1A202C", dark: "E9F0FF")
    static let appTextSecondary = dynamic(light: "718096", dark: "B8C6E6")
    static let appDivider = dynamic(light: "E2E8F0", dark: "1B2B55")
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}

extension NSColor {
    static let appBackground = NSColor(Color.appBackground)
    static let appSecondary = NSColor(Color.appSecondary)
    static let appAccent = NSColor(Color.appAccent)
    static let appHighlight = NSColor(Color.appHighlight)
    static let appHighlightText = NSColor(Color.appHighlightText)
    static let appControlDefault = NSColor(Color.appControlDefault)
    static let appControlActive = NSColor(Color.appControlActive)
    static let appTextPrimary = NSColor(Color.appTextPrimary)
    static let appTextSecondary = NSColor(Color.appTextSecondary)
    static let appDivider = NSColor(Color.appDivider)
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
    private var isForegroundSyncing = false
    private var didAlignPlaylistOnce = false
    private var isSyncingFrame = false
    private var pendingShowPlaylist = false
    private let playlistHeightKey = "wored.playlistHeight"
    private let playlistVisibleKey = "wored.playlistVisible"
    private var appActiveObserver: NSObjectProtocol?
    private var appTerminateObserver: NSObjectProtocol?
    private var isAppTerminating = false
    
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
    }
    
    func registerPlayerWindow(_ window: NSWindow) {
        playerWindow = window
        
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
        guard !isForegroundSyncing else { return }
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
        guard let player = playerWindow else { return }
        bringToFront(player)
        if let playlist = playlistWindow, playlist.isVisible {
            bringToFront(playlist)
        }
    }
    
    func showPlaylist() {
        guard let playlist = playlistWindow else { return }
        alignPlaylistBelowPlayer()
        attachPlaylistToPlayer()
        playlist.makeKeyAndOrderFront(nil)
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
    
    func togglePlaylist(openWindow: () -> Void) {
        if let playlist = playlistWindow {
            if playlist.isVisible {
                hidePlaylist()
            } else {
                showPlaylist()
            }
        } else {
            pendingShowPlaylist = true
            openWindow()
        }
    }

    func restorePlaylistIfNeeded(openWindow: () -> Void) {
        guard UserDefaults.standard.bool(forKey: playlistVisibleKey) else { return }
        if let playlist = playlistWindow {
            if !playlist.isVisible {
                showPlaylist()
            }
        } else {
            pendingShowPlaylist = true
            openWindow()
        }
    }
    
}

@main
struct woredApp: App {
    @StateObject private var viewModel = AudioPlayerViewModel.shared
    
    var body: some Scene {
        // Main Player Window
        WindowGroup("Wored", id: "player") {
            PlayerView(viewModel: viewModel)
                .background(PlayerWindowAccessor())
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        
        // Playlist Window
        Window("Playlist", id: "playlist") {
            PlaylistView(viewModel: viewModel)
                .background(PlaylistWindowAccessor())
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 320, height: 280)
        .defaultPosition(.topTrailing)
        
        MenuBarExtra("Wored", systemImage: "music.note") {
            MenuBarView(viewModel: viewModel)
        }
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

// MARK: - Playlist Window Accessor
struct PlaylistWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.styleMask = [.borderless, .closable, .resizable, .miniaturizable]
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.isMovableByWindowBackground = false
                window.isMovable = false
                window.backgroundColor = .appBackground
                window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
                
                window.minSize = NSSize(width: 280, height: 200)
                window.maxSize = NSSize(width: 900, height: 1200)
                
                if let contentView = window.contentView {
                    contentView.wantsLayer = true
                    contentView.layer?.cornerRadius = 0
                    contentView.layer?.masksToBounds = true
                }
                
                WindowManager.shared.registerPlaylistWindow(window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Menu Bar View
struct MenuBarView: View {
    @ObservedObject var viewModel: AudioPlayerViewModel
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.currentSongTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.appTextPrimary)
                .lineLimit(1)
            
            if !viewModel.artist.isEmpty {
                Text(viewModel.artist)
                    .font(.system(size: 10))
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(1)
            }
            
            HStack(spacing: 12) {
                Button(action: { viewModel.previousSong() }) {
                    Image(systemName: "backward.end.fill")
                }
                Button(action: { viewModel.togglePlayPause() }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                }
                Button(action: { viewModel.nextSong() }) {
                    Image(systemName: "forward.end.fill")
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.appHighlight)
            
            Divider()
                .overlay(Color.appDivider)
            
            Button(L10n.t(.playlist)) {
                openWindow(id: "playlist")
            }
            Button("Wored") {
                openWindow(id: "player")
            }
        }
        .padding(10)
        .frame(width: 220)
        .background(Color.appBackground)
    }
}
