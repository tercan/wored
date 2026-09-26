import Foundation
import AppKit

struct Song: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let title: String
    let artist: String
    let album: String?
    let genre: String?
    let year: String?
    let trackNumber: String?
    let discNumber: String?
    var duration: TimeInterval
    var isAvailable: Bool = true
    var fileSize: Int64?
    var modificationDate: Date?
    var formatName: String?
    var bitRate: Int?
    var sampleRate: Double?
    var channelCount: Int?

    init(
        id: UUID = UUID(),
        url: URL,
        title: String,
        artist: String,
        album: String? = nil,
        genre: String? = nil,
        year: String? = nil,
        trackNumber: String? = nil,
        discNumber: String? = nil,
        duration: TimeInterval,
        isAvailable: Bool = true,
        fileSize: Int64? = nil,
        modificationDate: Date? = nil,
        formatName: String? = nil,
        bitRate: Int? = nil,
        sampleRate: Double? = nil,
        channelCount: Int? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.artist = artist
        self.album = album
        self.genre = genre
        self.year = year
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.duration = duration
        self.isAvailable = isAvailable
        self.fileSize = fileSize
        self.modificationDate = modificationDate
        self.formatName = formatName
        self.bitRate = bitRate
        self.sampleRate = sampleRate
        self.channelCount = channelCount
    }
}

struct SongArtworkPayload: Equatable, Sendable {
    let data: Data
    let mimeType: String
}

enum SongArtworkChange: Equatable, Sendable {
    case keep
    case replace(SongArtworkPayload)
    case remove

    nonisolated var shouldRewriteArtwork: Bool {
        switch self {
        case .keep:
            return false
        case .replace, .remove:
            return true
        }
    }
}

struct SongTagDraft: Equatable, Sendable {
    var title: String
    var artist: String
    var album: String
    var genre: String
    var year: String
    var trackNumber: String
    var discNumber: String
    var artworkChange: SongArtworkChange

    init(
        title: String,
        artist: String,
        album: String,
        genre: String,
        year: String,
        trackNumber: String,
        discNumber: String,
        artworkChange: SongArtworkChange = .keep
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.genre = genre
        self.year = year
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.artworkChange = artworkChange
    }

    init(song: Song) {
        self.init(
            title: song.title,
            artist: song.artist == L10n.t(.unknownArtist) ? "" : song.artist,
            album: song.album ?? "",
            genre: song.genre ?? "",
            year: song.year ?? "",
            trackNumber: song.trackNumber ?? "",
            discNumber: song.discNumber ?? "",
            artworkChange: .keep
        )
    }
}

struct PlayerError: Identifiable {
    let id = UUID()
    let message: String
}

struct ImportSummary {
    var addedCount = 0
    var duplicateCount = 0
    var unsupportedCount = 0

    var didChangePlaylist: Bool {
        addedCount > 0
    }
}

struct CachedMetadata {
    let title: String?
    let artist: String?
    let album: String?
    let genre: String?
    let year: String?
    let trackNumber: String?
    let discNumber: String?
    let art: NSImage?
}

struct LibrarySource: Codable, Identifiable, Equatable {
    let id: UUID
    var bookmarkData: Data
    var name: String
    var lastKnownPath: String
    var resourceIdentifier: String?
    var lastScannedAt: Date?
    var isAvailable: Bool

    init(
        id: UUID = UUID(),
        bookmarkData: Data,
        name: String,
        lastKnownPath: String,
        resourceIdentifier: String? = nil,
        lastScannedAt: Date? = nil,
        isAvailable: Bool = true
    ) {
        self.id = id
        self.bookmarkData = bookmarkData
        self.name = name
        self.lastKnownPath = lastKnownPath
        self.resourceIdentifier = resourceIdentifier
        self.lastScannedAt = lastScannedAt
        self.isAvailable = isAvailable
    }
}

// Codable struct for saving song data
struct SavedSong: Codable {
    let bookmarkData: Data
    let title: String
    let artist: String
    let duration: TimeInterval
    let originalPath: String?
    let fileSize: Int64?
    let modificationDate: Date?
    let resourceIdentifier: String?
    let album: String?
    let genre: String?
    let year: String?
    let trackNumber: String?
    let discNumber: String?
    let formatName: String?
    let bitRate: Int?
    let sampleRate: Double?
    let channelCount: Int?

    init(
        bookmarkData: Data,
        title: String,
        artist: String,
        duration: TimeInterval,
        originalPath: String? = nil,
        fileSize: Int64? = nil,
        modificationDate: Date? = nil,
        resourceIdentifier: String? = nil,
        album: String? = nil,
        genre: String? = nil,
        year: String? = nil,
        trackNumber: String? = nil,
        discNumber: String? = nil,
        formatName: String? = nil,
        bitRate: Int? = nil,
        sampleRate: Double? = nil,
        channelCount: Int? = nil
    ) {
        self.bookmarkData = bookmarkData
        self.title = title
        self.artist = artist
        self.duration = duration
        self.originalPath = originalPath
        self.fileSize = fileSize
        self.modificationDate = modificationDate
        self.resourceIdentifier = resourceIdentifier
        self.album = album
        self.genre = genre
        self.year = year
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.formatName = formatName
        self.bitRate = bitRate
        self.sampleRate = sampleRate
        self.channelCount = channelCount
    }
}

// Represents a user-defined playlist
struct Playlist: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var songs: [SavedSong]
    var createdAt: Date
    var updatedAt: Date
    var isDefault: Bool
    var sources: [LibrarySource]

    init(
        id: UUID = UUID(),
        name: String,
        songs: [SavedSong] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isDefault: Bool = false,
        sources: [LibrarySource] = []
    ) {
        self.id = id
        self.name = name
        self.songs = songs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDefault = isDefault
        self.sources = sources
    }

    static func == (lhs: Playlist, rhs: Playlist) -> Bool {
        lhs.id == rhs.id
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case songs
        case createdAt
        case updatedAt
        case isDefault
        case sources
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        songs = try container.decode([SavedSong].self, forKey: .songs)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        isDefault = try container.decode(Bool.self, forKey: .isDefault)
        sources = try container.decodeIfPresent([LibrarySource].self, forKey: .sources) ?? []
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
