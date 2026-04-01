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

// Represents a user-defined playlist
struct Playlist: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var songs: [SavedSong]
    var createdAt: Date
    var updatedAt: Date
    var isDefault: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        songs: [SavedSong] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.songs = songs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDefault = isDefault
    }
    
    static func == (lhs: Playlist, rhs: Playlist) -> Bool {
        lhs.id == rhs.id
    }
}

// Top-level container for all playlists
struct PlaylistCollection: Codable {
    let version: Int
    var playlists: [Playlist]
    var activePlaylistId: UUID?
    var lastPlayedIndex: Int?
    var lastPlayedPosition: TimeInterval?
}

// Legacy format for migration
struct LegacySavedPlaylist: Codable {
    let version: Int
    let songs: [SavedSong]
    let lastPlayedIndex: Int?
    let lastPlayedPosition: TimeInterval?
}
