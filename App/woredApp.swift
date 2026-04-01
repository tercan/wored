//
//  woredApp.swift
//  wored
//
//  Created by Tercan Keskin on 3.01.2026.
//

import SwiftUI
import AppKit
import Combine

// Color palette is in Extensions/Color+App.swift
// WindowManager is in App/WindowManager.swift
// Window accessors are in App/WindowAccessors.swift
// MenuBarView is in Views/MenuBarView.swift

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
