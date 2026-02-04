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
extension Color {
    static let appBackground = Color(hex: "0A1226")
    static let appSecondary = Color(hex: "0E1A33")
    static let appAccent = Color(hex: "13224A")
    static let appHighlight = Color(hex: "003999")
    static let appHighlightText = Color(hex: "C8D8FF")
    static let appControlDefault = Color(hex: "0C328C")
    static let appControlActive = Color(hex: "448AFF")
    static let appTextPrimary = Color(hex: "E9F0FF")
    static let appTextSecondary = Color(hex: "B8C6E6")
    static let appDivider = Color(hex: "1B2B55")
    
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
    
    @Published var isPinned = false
    @Published var isPlaylistVisible = false
    weak var playerWindow: NSWindow?
    weak var playlistWindow: NSWindow?
    
    private var playerObserver: NSObjectProtocol?
    private var playlistObserver: NSObjectProtocol?
    private var playerKeyObserver: NSObjectProtocol?
    private var playlistKeyObserver: NSObjectProtocol?
    private var playerMainObserver: NSObjectProtocol?
    private var playlistMainObserver: NSObjectProtocol?
    private var pendingPin = false
    private var isForegroundSyncing = false
    private var didAlignPlaylistOnce = false
    
    func registerPlayerWindow(_ window: NSWindow) {
        playerWindow = window
        
        // Observe player window movement
        playerObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.movePlaylistIfPinned()
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
            self?.checkPinStatus()
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
            self?.isPinned = false
            self?.isPlaylistVisible = false
            self?.playlistWindow = nil
        }
        
        if pendingPin {
            pinPlaylist()
            pendingPin = false
        }

        if !didAlignPlaylistOnce {
            alignPlaylistBelowPlayer()
            didAlignPlaylistOnce = true
        }
    }
    
    private func checkPinStatus() {
        guard isPinned, let player = playerWindow, let playlist = playlistWindow else { return }
        
        let playerFrame = player.frame
        let playlistFrame = playlist.frame
        
        // Check if playlist is aligned to player's right edge
        let tolerance: CGFloat = 5
        let isAlignedTop = abs(playlistFrame.maxY - playerFrame.maxY) < tolerance
        let isAlignedRight = abs(playlistFrame.minX - playerFrame.maxX) < tolerance
        
        if !isAlignedTop || !isAlignedRight {
            isPinned = false
        }
    }
    
    private func movePlaylistIfPinned() {
        guard isPinned, let player = playerWindow, let playlist = playlistWindow else { return }
        
        // Move playlist to stay pinned to player's right
        var newOrigin = playlist.frame.origin
        newOrigin.x = player.frame.maxX
        newOrigin.y = player.frame.maxY - playlist.frame.height
        playlist.setFrameOrigin(newOrigin)
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
        var playlistFrame = playlist.frame
        playlistFrame.size.width = playerFrame.width
        playlistFrame.origin.x = playerFrame.minX
        playlistFrame.origin.y = playerFrame.minY - playlistFrame.height
        playlist.setFrame(playlistFrame, display: true)
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
    }
    
    func pinPlaylist() {
        guard let player = playerWindow, let playlist = playlistWindow else { return }
        
        // Position playlist to right of player
        var newOrigin = playlist.frame.origin
        newOrigin.x = player.frame.maxX
        newOrigin.y = player.frame.maxY - playlist.frame.height
        playlist.setFrameOrigin(newOrigin)
        isPinned = true
    }
    
    func showPlaylist() {
        guard let playlist = playlistWindow else { return }
        playlist.makeKeyAndOrderFront(nil)
        isPlaylistVisible = true
    }
    
    func hidePlaylist() {
        guard let playlist = playlistWindow else { return }
        playlist.orderOut(nil)
        isPlaylistVisible = false
        isPinned = false
    }
    
    func togglePlaylist(openWindow: () -> Void) {
        if let playlist = playlistWindow {
            if playlist.isVisible {
                hidePlaylist()
            } else {
                showPlaylist()
            }
        } else {
            openWindow()
        }
    }
    
    func togglePin(openWindow: () -> Void) {
        if isPinned {
            isPinned = false
            return
        }
        
        if let playlist = playlistWindow {
            if !playlist.isVisible {
                showPlaylist()
            }
            pinPlaylist()
        } else {
            pendingPin = true
            openWindow()
        }
    }
}

@main
struct woredApp: App {
    @StateObject private var viewModel = AudioPlayerViewModel()
    
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
                window.styleMask = [.borderless, .miniaturizable]
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.isMovableByWindowBackground = true
                window.backgroundColor = .appBackground
                window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
                
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
                window.styleMask = [.borderless, .resizable, .miniaturizable]
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.isMovableByWindowBackground = true
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
