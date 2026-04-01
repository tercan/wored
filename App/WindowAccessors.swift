import SwiftUI
import AppKit

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
