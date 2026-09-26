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
        case cancel
        case save
        case saving
        case showInFinder
        case delete
        case info
        case play
        case playNext
        case addToQueue
        case addToFavorites
        case removeFromFavorites
        case removeFromHistory
        case emptyStateTitle
        case emptyStateSubtitle
        case emptyFavoritesTitle
        case emptyFavoritesSubtitle
        case emptyHistoryTitle
        case emptyHistorySubtitle
        case clearHistoryTitle
        case clearHistoryConfirm
        case playlist
        case playlistView
        case favoritesView
        case historyView
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
        case rescanLibrary
        case dropToAddSongs
        case unsupportedFilesSkipped
        case duplicateSongsSkipped
        case songsAdded
        case noLibrarySources
        case libraryRescanComplete
        case libraryRescanUnavailable
        case launchAtStartupUnavailable
        case searchPlaceholder
        case clearSearch
        case noSearchResults
        case songCountSuffix
        case resultCountSuffix
        case selectedCountSuffix
        case missingCountSuffix
        case unknownValue
        case songInfoTitle
        case songInfoTrackTitle
        case songInfoMetadata
        case songInfoTechnical
        case songInfoFile
        case songInfoArtist
        case songInfoAlbum
        case songInfoGenre
        case songInfoYear
        case songInfoTrackNumber
        case songInfoDiscNumber
        case songInfoArtwork
        case songInfoDuration
        case songInfoFormat
        case songInfoBitRate
        case songInfoSampleRate
        case songInfoChannels
        case songInfoFileName
        case songInfoFileSize
        case songInfoModified
        case songInfoFilePath
        case editTags
        case chooseArtwork
        case removeArtwork
        case resetArtwork
        case tagEditorTitle
        case tagEditorSaved
        case tagEditorUnsupportedFormat
        case tagEditorUnsupportedVersion
        case tagEditorUnsupportedTagLayout
        case tagEditorUnsupportedArtwork
        case tagEditorUnreadableFile
        case tagEditorUnwritableFile
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
        .cancel: "Vazgeç",
        .save: "Kaydet",
        .saving: "Kaydediliyor",
        .showInFinder: "Finder'da Göster",
        .delete: "Sil",
        .info: "Bilgi",
        .play: "Çal",
        .playNext: "Sıradaki Olarak Çal",
        .addToQueue: "Sıraya Ekle",
        .addToFavorites: "Favorilere Ekle",
        .removeFromFavorites: "Favorilerden Kaldır",
        .removeFromHistory: "Geçmişten Kaldır",
        .emptyStateTitle: "Listende henüz şarkı yok",
        .emptyStateSubtitle: "Başlamak için listeye şarkılarını ekle",
        .emptyFavoritesTitle: "Favori parça yok",
        .emptyFavoritesSubtitle: "Parçaları sağ tık menüsünden favorilere ekleyebilirsiniz",
        .emptyHistoryTitle: "Geçmiş boş",
        .emptyHistorySubtitle: "Çalınan parçalar burada görünür",
        .clearHistoryTitle: "Geçmişi Temizle",
        .clearHistoryConfirm: "Çalma geçmişini temizlemek istediğinize emin misiniz?",
        .playlist: "Çalma listesi",
        .playlistView: "Liste",
        .favoritesView: "Favoriler",
        .historyView: "Geçmiş",
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
        .defaultPlaylist: "Varsayılan Liste",
        .rescanLibrary: "Yeniden Tara",
        .dropToAddSongs: "Dosya veya klasör bırak",
        .unsupportedFilesSkipped: "desteklenmeyen dosya atlandı",
        .duplicateSongsSkipped: "tekrar parça atlandı",
        .songsAdded: "şarkı eklendi",
        .noLibrarySources: "Yeniden taranacak klasör yok",
        .libraryRescanComplete: "Yeniden tarama tamamlandı",
        .libraryRescanUnavailable: "Klasöre erişilemedi",
        .launchAtStartupUnavailable: "Başlangıç ayarı güncellenemedi",
        .searchPlaceholder: "Listede ara",
        .clearSearch: "Aramayı temizle",
        .noSearchResults: "Eşleşen parça bulunamadı",
        .songCountSuffix: "parça",
        .resultCountSuffix: "sonuç",
        .selectedCountSuffix: "seçili",
        .missingCountSuffix: "eksik",
        .unknownValue: "Bilinmiyor",
        .songInfoTitle: "Parça Bilgisi",
        .songInfoTrackTitle: "Başlık",
        .songInfoMetadata: "Parça",
        .songInfoTechnical: "Teknik",
        .songInfoFile: "Dosya",
        .songInfoArtist: "Sanatçı",
        .songInfoAlbum: "Albüm",
        .songInfoGenre: "Tür",
        .songInfoYear: "Yıl",
        .songInfoTrackNumber: "Parça no",
        .songInfoDiscNumber: "Disk no",
        .songInfoArtwork: "Kapak Görseli",
        .songInfoDuration: "Süre",
        .songInfoFormat: "Biçim",
        .songInfoBitRate: "Bit hızı",
        .songInfoSampleRate: "Örnekleme",
        .songInfoChannels: "Kanal",
        .songInfoFileName: "Dosya adı",
        .songInfoFileSize: "Boyut",
        .songInfoModified: "Değiştirilme",
        .songInfoFilePath: "Yol",
        .editTags: "Etiketleri Düzenle",
        .chooseArtwork: "Kapak Seç",
        .removeArtwork: "Kaldır",
        .resetArtwork: "Geri Al",
        .tagEditorTitle: "Etiket Düzenleyici",
        .tagEditorSaved: "Etiketler kaydedildi",
        .tagEditorUnsupportedFormat: "Şimdilik yalnızca MP3/ID3 etiketleri düzenlenebilir",
        .tagEditorUnsupportedVersion: "Bu ID3 sürümü henüz desteklenmiyor",
        .tagEditorUnsupportedTagLayout: "Bu dosyanın ID3 yapısı güvenli şekilde düzenlenemiyor",
        .tagEditorUnsupportedArtwork: "Bu görsel kapak olarak kullanılamıyor",
        .tagEditorUnreadableFile: "Dosya okunamıyor",
        .tagEditorUnwritableFile: "Dosyaya yazma izni yok"
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
        .cancel: "Cancel",
        .save: "Save",
        .saving: "Saving",
        .showInFinder: "Show in Finder",
        .delete: "Delete",
        .info: "Info",
        .play: "Play",
        .playNext: "Play Next",
        .addToQueue: "Add to Queue",
        .addToFavorites: "Add to Favorites",
        .removeFromFavorites: "Remove from Favorites",
        .removeFromHistory: "Remove from History",
        .emptyStateTitle: "No songs yet",
        .emptyStateSubtitle: "Add audio files to start",
        .emptyFavoritesTitle: "No favorite tracks",
        .emptyFavoritesSubtitle: "Add tracks to favorites from the context menu",
        .emptyHistoryTitle: "History is empty",
        .emptyHistorySubtitle: "Played tracks will appear here",
        .clearHistoryTitle: "Clear History",
        .clearHistoryConfirm: "Are you sure you want to clear playback history?",
        .playlist: "Playlist",
        .playlistView: "List",
        .favoritesView: "Favorites",
        .historyView: "History",
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
        .defaultPlaylist: "Default Playlist",
        .rescanLibrary: "Rescan",
        .dropToAddSongs: "Drop files or folders",
        .unsupportedFilesSkipped: "unsupported files skipped",
        .duplicateSongsSkipped: "duplicate songs skipped",
        .songsAdded: "songs added",
        .noLibrarySources: "No folders to rescan",
        .libraryRescanComplete: "Rescan complete",
        .libraryRescanUnavailable: "Folder could not be accessed",
        .launchAtStartupUnavailable: "Launch at startup could not be updated",
        .searchPlaceholder: "Search playlist",
        .clearSearch: "Clear search",
        .noSearchResults: "No matching tracks",
        .songCountSuffix: "songs",
        .resultCountSuffix: "results",
        .selectedCountSuffix: "selected",
        .missingCountSuffix: "missing",
        .unknownValue: "Unknown",
        .songInfoTitle: "Track Info",
        .songInfoTrackTitle: "Title",
        .songInfoMetadata: "Track",
        .songInfoTechnical: "Technical",
        .songInfoFile: "File",
        .songInfoArtist: "Artist",
        .songInfoAlbum: "Album",
        .songInfoGenre: "Genre",
        .songInfoYear: "Year",
        .songInfoTrackNumber: "Track no.",
        .songInfoDiscNumber: "Disc no.",
        .songInfoArtwork: "Artwork",
        .songInfoDuration: "Duration",
        .songInfoFormat: "Format",
        .songInfoBitRate: "Bit rate",
        .songInfoSampleRate: "Sample rate",
        .songInfoChannels: "Channels",
        .songInfoFileName: "File name",
        .songInfoFileSize: "Size",
        .songInfoModified: "Modified",
        .songInfoFilePath: "Path",
        .editTags: "Edit Tags",
        .chooseArtwork: "Choose Art",
        .removeArtwork: "Remove",
        .resetArtwork: "Reset",
        .tagEditorTitle: "Tag Editor",
        .tagEditorSaved: "Tags saved",
        .tagEditorUnsupportedFormat: "Only MP3/ID3 tags can be edited for now",
        .tagEditorUnsupportedVersion: "This ID3 version is not supported yet",
        .tagEditorUnsupportedTagLayout: "This file's ID3 layout cannot be edited safely",
        .tagEditorUnsupportedArtwork: "This image cannot be used as artwork",
        .tagEditorUnreadableFile: "File cannot be read",
        .tagEditorUnwritableFile: "File is not writable"
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
