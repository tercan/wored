import Foundation
import AppKit

struct Song: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let title: String
    let artist: String
    var duration: TimeInterval
    var isAvailable: Bool = true
    
    init(
        id: UUID = UUID(),
        url: URL,
        title: String,
        artist: String,
        duration: TimeInterval,
        isAvailable: Bool = true
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.artist = artist
        self.duration = duration
        self.isAvailable = isAvailable
    }
}

struct PlayerError: Identifiable {
    let id = UUID()
    let message: String
}

struct CachedMetadata {
    let title: String?
    let artist: String?
    let art: NSImage?
}

// Codable struct for saving song data
struct SavedSong: Codable {
    let bookmarkData: Data
    let title: String
    let artist: String
    let duration: TimeInterval
}

struct SavedPlaylist: Codable {
    let version: Int
    let songs: [SavedSong]
    let lastPlayedIndex: Int?
    let lastPlayedPosition: TimeInterval?
}
