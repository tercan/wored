import Foundation

enum L10n {
    enum Key: String {
        case noTrackSelected
        case unknownArtist
        case playlistTitle
        case add
        case searchPlaceholder
        case clear
        case infoVersion
        case infoDeveloper
        case infoBuild
        case infoSubtitle
        case errorTitle
        case ok
        case showInFinder
        case delete
        case info
        case play
        case emptyStateTitle
        case emptyStateSubtitle
        case playlist
        case pin
        case unpin
        case miniMode
        case removeMissing
    }
    
    private static let tr: [Key: String] = [
        .noTrackSelected: "Parça seçilmedi",
        .unknownArtist: "Bilinmeyen Sanatçı",
        .playlistTitle: "ÇALMA LİSTESİ",
        .add: "Ekle",
        .searchPlaceholder: "Şarkı veya sanatçı ara...",
        .clear: "Temizle",
        .infoVersion: "Sürüm",
        .infoDeveloper: "Geliştirici",
        .infoBuild: "Derleme",
        .infoSubtitle: "macOS için minimal müzik çalar",
        .errorTitle: "Hata",
        .ok: "Tamam",
        .showInFinder: "Finder'da Göster",
        .delete: "Sil",
        .info: "Bilgi",
        .play: "Çal",
        .emptyStateTitle: "Henüz parça yok",
        .emptyStateSubtitle: "Başlamak için dosya ekle",
        .playlist: "Çalma listesi",
        .pin: "Pinle",
        .unpin: "Ayır",
        .miniMode: "Mini mod",
        .removeMissing: "Eksikleri temizle"
    ]
    
    private static let en: [Key: String] = [
        .noTrackSelected: "No Track Selected",
        .unknownArtist: "Unknown Artist",
        .playlistTitle: "PLAYLIST",
        .add: "Add",
        .searchPlaceholder: "Search song or artist...",
        .clear: "Clear",
        .infoVersion: "Version",
        .infoDeveloper: "Developer",
        .infoBuild: "Build",
        .infoSubtitle: "A minimal music player for macOS",
        .errorTitle: "Error",
        .ok: "OK",
        .showInFinder: "Show in Finder",
        .delete: "Delete",
        .info: "Info",
        .play: "Play",
        .emptyStateTitle: "No songs yet",
        .emptyStateSubtitle: "Add audio files to start",
        .playlist: "Playlist",
        .pin: "Pin",
        .unpin: "Unpin",
        .miniMode: "Mini mode",
        .removeMissing: "Remove missing"
    ]
    
    static func t(_ key: Key) -> String {
        let preferred = Locale.preferredLanguages.first ?? "en"
        let isTurkish = preferred.hasPrefix("tr")
        let table = isTurkish ? tr : en
        return table[key] ?? en[key] ?? key.rawValue
    }
}
