import Foundation

enum L10n {
    enum Key: String {
        case noTrackSelected
        case unknownArtist
        case playlistTitle
        case add
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
        case playNext
        case addToQueue
        case addToFavorites
        case removeFromFavorites
        case emptyStateTitle
        case emptyStateSubtitle
        case playlist
        case removeMissing
        case settings
        case settingsAudio
        case settingsCrossfade
        case settingsEQ
        case settingsUI
        case settingsAlwaysOnTop
        case settingsTheme
        case themeSystem
        case themeLight
        case themeDark
        case settingsSystem
        case settingsLaunchAtStartup
        case settingsLanguage
        case settingsAbout
        case newPlaylist
        case createPlaylist
        case renamePlaylist
        case deletePlaylist
        case deletePlaylistConfirm
        case playlistName
        case addToPlaylist
        case defaultPlaylist
    }
    
    private static let tr: [Key: String] = [
        .noTrackSelected: "Parça seçilmedi",
        .unknownArtist: "Bilinmeyen Sanatçı",
        .playlistTitle: "ÇALMA LİSTESİ",
        .add: "Ekle",
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
        .playNext: "Sıradaki Olarak Çal",
        .addToQueue: "Sıraya Ekle",
        .addToFavorites: "Favorilere Ekle",
        .removeFromFavorites: "Favorilerden Kaldır",
        .emptyStateTitle: "Listende henüz şarkı yok",
        .emptyStateSubtitle: "Başlamak için listeye şarkılarını ekle",
        .playlist: "Çalma listesi",
        .removeMissing: "Eksikleri temizle",
        .settings: "Ayarlar",
        .settingsAudio: "Ses",
        .settingsCrossfade: "Crossfade",
        .settingsEQ: "Ekolayzer",
        .settingsUI: "Arayüz",
        .settingsAlwaysOnTop: "Her zaman üstte",
        .settingsTheme: "Tema",
        .themeSystem: "Sistem",
        .themeLight: "Açık",
        .themeDark: "Koyu",
        .settingsSystem: "Sistem",
        .settingsLaunchAtStartup: "Başlangıçta aç",
        .settingsLanguage: "Dil",
        .settingsAbout: "Hakkında",
        .newPlaylist: "Yeni Liste",
        .createPlaylist: "Liste Oluştur",
        .renamePlaylist: "Yeniden Adlandır",
        .deletePlaylist: "Listeyi Sil",
        .deletePlaylistConfirm: "Bu listeyi silmek istediğinize emin misiniz?",
        .playlistName: "Liste Adı",
        .addToPlaylist: "Listeye Ekle",
        .defaultPlaylist: "Varsayılan Liste"
    ]
    
    private static let en: [Key: String] = [
        .noTrackSelected: "No track selected",
        .unknownArtist: "Unknown Artist",
        .playlistTitle: "Playlist",
        .add: "Add",
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
        .playNext: "Play Next",
        .addToQueue: "Add to Queue",
        .addToFavorites: "Add to Favorites",
        .removeFromFavorites: "Remove from Favorites",
        .emptyStateTitle: "No songs yet",
        .emptyStateSubtitle: "Add audio files to start",
        .playlist: "Playlist",
        .removeMissing: "Remove missing",
        .settings: "Settings",
        .settingsAudio: "Audio",
        .settingsCrossfade: "Crossfade",
        .settingsEQ: "Equalizer",
        .settingsUI: "Interface",
        .settingsAlwaysOnTop: "Always on top",
        .settingsTheme: "Theme",
        .themeSystem: "System",
        .themeLight: "Light",
        .themeDark: "Dark",
        .settingsSystem: "System",
        .settingsLaunchAtStartup: "Launch at startup",
        .settingsLanguage: "Language",
        .settingsAbout: "About",
        .newPlaylist: "New Playlist",
        .createPlaylist: "Create Playlist",
        .renamePlaylist: "Rename",
        .deletePlaylist: "Delete Playlist",
        .deletePlaylistConfirm: "Are you sure you want to delete this playlist?",
        .playlistName: "Playlist Name",
        .addToPlaylist: "Add to Playlist",
        .defaultPlaylist: "Default Playlist"
    ]
    
    static func t(_ key: Key) -> String {
        var isTurkish = false
        if let userLang = UserDefaults.standard.string(forKey: "wored.language"),
           userLang != "system" {
            isTurkish = (userLang == "tr")
        } else {
            let preferred = Locale.preferredLanguages.first ?? "en"
            isTurkish = preferred.hasPrefix("tr")
        }
        
        let table = isTurkish ? tr : en
        return table[key] ?? en[key] ?? key.rawValue
    }
}
