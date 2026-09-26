import Foundation
import AppKit
import AVFoundation
import Combine
import SwiftUI
import UniformTypeIdentifiers
import MediaPlayer
import ServiceManagement

// Model types are defined in Models/Song.swift and Models/Enums.swift

// NSObject required for notifications and command handling
class AudioPlayerViewModel: NSObject, ObservableObject {
    static let shared = AudioPlayerViewModel()

    private let audioEngine = AVAudioEngine()
    private let mixNode = AVAudioMixerNode()
    private let eqNode = AVAudioUnitEQ(numberOfBands: 5)
    private let timePitchNode = AVAudioUnitTimePitch()
    private let playerNodes: [AVAudioPlayerNode] = [AVAudioPlayerNode(), AVAudioPlayerNode()]
    private var activeNodeIndex: Int = 0
    private var isCrossfading = false
    private var crossfadeTimer: Timer?
    private var engineConfigured = false
    var timer: Timer?
    private var activeSecurityURLs: Set<URL> = []
    private var metadataCache: [URL: CachedMetadata] = [:]
    private var durationCache: [URL: TimeInterval] = [:]
    private var savedSongsCache: [SavedSong] = []
    private var pendingResumeIndex: Int?
    private var pendingResumeTime: TimeInterval?
    private var lastPlaybackSave: TimeInterval = 0
    private var nowPlayingInfo: [String: Any] = [:]
    private var commandCenterConfigured = false
    private var playbackOrder: [Int] = []
    private var playbackPosition: Int = 0
    private var hasPreparedPlayback = false
    private var currentPlaybackOffset: TimeInterval = 0
    private var suppressAutoAdvanceUntil: Date?
    private var playbackGeneration = 0
    private var isLoadingPreferences = false
    private var isUpdatingLaunchAtStartup = false
    private var detachedPlaybackSong: Song?
    private var noticeTimer: Timer?
    private let volumeKey = "wored.volume"
    private let muteKey = "wored.mute"
    private let shuffleKey = "wored.shuffle"
    private let repeatKey = "wored.repeat"
    private let favoritesKey = "wored.favorites"
    private let historyKey = "wored.history"
    private let speedKey = "wored.speed"
    private let crossfadeKey = "wored.crossfade"
    private let eqPresetKey = "wored.eqpreset"
    private let alwaysOnTopKey = "wored.alwaysontop"
    private let themeKey = "wored.theme"
    private let launchAtStartupKey = "wored.launchAtStartup"
    private let languageKey = "wored.language"
    private let maxHistoryCount = 50
    private let staleSourceScanInterval: TimeInterval = 7 * 24 * 60 * 60

    // Favorites storage (URL paths as strings)
    @Published private(set) var favoriteURLs: Set<String> = []

    // History storage (song paths with timestamps)
    @Published private(set) var playHistory: [(path: String, timestamp: Date)] = []

    // Multi-playlist management
    @Published var playlists: [Playlist] = []
    @Published var activePlaylistId: UUID?
    private let playlistCollectionVersion = 3

    var activePlaylist: Playlist? {
        guard let id = activePlaylistId else { return playlists.first }
        return playlists.first(where: { $0.id == id })
    }

    // Playlist Data
    @Published var queue: [Song] = []       // Song queue
    @Published var currentIndex: Int? = nil // Currently playing song index

    @Published var isPlaying: Bool = false {
        didSet {
            MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
            updateNowPlayingElapsed()
        }
    }
    @Published var currentSongTitle: String = L10n.t(.noTrackSelected)
    @Published var artist: String = ""
    @Published var albumArt: NSImage? = nil

    @Published var currentTime: TimeInterval = 0.0
    @Published var duration: TimeInterval = 0.0
    @Published var isSeeking: Bool = false
    @Published var activeError: PlayerError? = nil
    @Published var playlistNotice: String? = nil
    @Published var volume: Float = 0.8 {
        didSet {
            UserDefaults.standard.set(Double(volume), forKey: volumeKey)
            updateOutputVolume()
        }
    }
    @Published var isMuted: Bool = false {
        didSet {
            UserDefaults.standard.set(isMuted, forKey: muteKey)
            updateOutputVolume()
        }
    }
    @Published var isShuffled: Bool = false {
        didSet {
            UserDefaults.standard.set(isShuffled, forKey: shuffleKey)
        }
    }
    @Published var repeatMode: RepeatMode = .none {
        didSet {
            UserDefaults.standard.set(repeatMode.rawValue, forKey: repeatKey)
        }
    }
    @Published var playbackRate: Float = 1.0 {
        didSet {
            let clamped = min(max(playbackRate, 0.5), 2.0)
            if clamped != playbackRate { playbackRate = clamped }
            UserDefaults.standard.set(Double(playbackRate), forKey: speedKey)
            timePitchNode.rate = playbackRate
        }
    }
    @Published var crossfadeDuration: TimeInterval = 2.0 {
        didSet {
            let clamped = min(max(crossfadeDuration, 0), 5)
            if clamped != crossfadeDuration { crossfadeDuration = clamped }
            UserDefaults.standard.set(crossfadeDuration, forKey: crossfadeKey)
        }
    }
    @Published var eqPreset: EQPreset = .flat {
        didSet {
            UserDefaults.standard.set(eqPreset.rawValue, forKey: eqPresetKey)
            applyEQPreset()
        }
    }
    @Published var alwaysOnTop: Bool = false {
        didSet {
            UserDefaults.standard.set(alwaysOnTop, forKey: alwaysOnTopKey)
        }
    }

    @Published var appTheme: AppTheme = .system {
        didSet {
            UserDefaults.standard.set(appTheme.rawValue, forKey: themeKey)
            NSApp.appearance = appTheme.nsAppearance
        }
    }

    @Published var launchAtStartup: Bool = false {
        didSet {
            guard !isLoadingPreferences, !isUpdatingLaunchAtStartup else { return }
            UserDefaults.standard.set(launchAtStartup, forKey: launchAtStartupKey)
            updateLaunchAtStartup()
        }
    }

    private func updateLaunchAtStartup() {
        guard !isUpdatingLaunchAtStartup else { return }
        isUpdatingLaunchAtStartup = true
        defer { isUpdatingLaunchAtStartup = false }

        do {
            let service = SMAppService.mainApp
            if launchAtStartup {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status != .notRegistered {
                    try service.unregister()
                }
            }
        } catch {
            UserDefaults.standard.set(false, forKey: launchAtStartupKey)
            launchAtStartup = false
            showPlaylistNotice(L10n.t(.launchAtStartupUnavailable))
        }
    }

    @Published var appLanguage: AppLanguage = .system {
        didSet {
            UserDefaults.standard.set(appLanguage.rawValue, forKey: languageKey)
            // Trigger UI update if needed (Localization.t reads from UserDefaults)
        }
    }

    // File path for saving playlist
    private var playlistURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("Wored", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)

        return appFolder.appendingPathComponent("playlist.json")
    }

    override init() {
        super.init()
        loadPreferences()
        loadFavorites()
        loadHistory()
        loadPlaylist()
        configureAudioEngine()
        configureRemoteCommandCenter()
        observeApplicationActivation()
        scheduleStaleSourceRescan()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func observeApplicationActivation() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func handleApplicationDidBecomeActive() {
        refreshActivePlaylistMetadata(force: false)
    }

    private func configureRemoteCommandCenter() {
        guard !commandCenterConfigured else { return }
        commandCenterConfigured = true

        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.handleRemotePlay()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.handleRemotePause()
            return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextSong()
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousSong()
            return .success
        }
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: event.positionTime)
            self?.currentTime = event.positionTime
            self?.updateNowPlayingElapsed()
            return .success
        }
    }

    private func handleRemotePlay() {
        if !isPlaying {
            togglePlayPause()
        }
    }

    private func handleRemotePause() {
        if isPlaying {
            togglePlayPause()
        }
    }

    private func loadPreferences() {
        isLoadingPreferences = true
        defer { isLoadingPreferences = false }

        let storedVolume = UserDefaults.standard.object(forKey: volumeKey) as? Double
        volume = Float(storedVolume ?? 0.8)
        isMuted = UserDefaults.standard.bool(forKey: muteKey)
        isShuffled = UserDefaults.standard.bool(forKey: shuffleKey)
        if let raw = UserDefaults.standard.string(forKey: repeatKey),
           let mode = RepeatMode(rawValue: raw) {
            repeatMode = mode
        }
        let storedSpeed = UserDefaults.standard.object(forKey: speedKey) as? Double
        playbackRate = Float(storedSpeed ?? 1.0)

        // New settings
        let storedCrossfade = UserDefaults.standard.object(forKey: crossfadeKey) as? Double
        crossfadeDuration = storedCrossfade ?? 2.0

        if let rawEQ = UserDefaults.standard.string(forKey: eqPresetKey),
           let preset = EQPreset(rawValue: rawEQ) {
            eqPreset = preset
        }

        alwaysOnTop = UserDefaults.standard.bool(forKey: alwaysOnTopKey)

        if let rawTheme = UserDefaults.standard.string(forKey: themeKey),
           let theme = AppTheme(rawValue: rawTheme) {
            appTheme = theme
        }
        DispatchQueue.main.async {
            NSApp.appearance = self.appTheme.nsAppearance
        }

        launchAtStartup = UserDefaults.standard.bool(forKey: launchAtStartupKey)

        if let rawLang = UserDefaults.standard.string(forKey: languageKey),
           let lang = AppLanguage(rawValue: rawLang) {
            appLanguage = lang
        }
    }

    private func reportError(_ message: String) {
        DispatchQueue.main.async {
            self.activeError = PlayerError(message: message)
        }
    }

    private func showPlaylistNotice(_ message: String) {
        noticeTimer?.invalidate()
        playlistNotice = message
        noticeTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.playlistNotice = nil
        }
    }

    private func importNotice(for summary: ImportSummary) -> String? {
        var parts: [String] = []
        if summary.addedCount > 0 {
            parts.append("\(summary.addedCount) \(L10n.t(.songsAdded))")
        }
        if summary.duplicateCount > 0 {
            parts.append("\(summary.duplicateCount) \(L10n.t(.duplicateSongsSkipped))")
        }
        if summary.unsupportedCount > 0 {
            parts.append("\(summary.unsupportedCount) \(L10n.t(.unsupportedFilesSkipped))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - Favorites

    private func loadFavorites() {
        if let paths = UserDefaults.standard.stringArray(forKey: favoritesKey) {
            favoriteURLs = Set(paths)
        }
    }

    private func saveFavorites() {
        UserDefaults.standard.set(Array(favoriteURLs), forKey: favoritesKey)
    }

    func toggleFavorite(song: Song) {
        let path = song.url.path
        if favoriteURLs.contains(path) {
            favoriteURLs.remove(path)
        } else {
            favoriteURLs.insert(path)
        }
        saveFavorites()
    }

    func isFavorite(song: Song) -> Bool {
        favoriteURLs.contains(song.url.path)
    }

    func clearFavorites() {
        favoriteURLs.removeAll()
        saveFavorites()
    }

    // MARK: - History

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([[String: String]].self, from: data) else { return }

        let formatter = ISO8601DateFormatter()
        playHistory = decoded.compactMap { entry in
            guard let path = entry["path"],
                  let timestampStr = entry["timestamp"],
                  let timestamp = formatter.date(from: timestampStr) else { return nil }
            return (path: path, timestamp: timestamp)
        }
    }

    private func saveHistory() {
        let formatter = ISO8601DateFormatter()
        let encoded: [[String: String]] = playHistory.map { entry in
            ["path": entry.path, "timestamp": formatter.string(from: entry.timestamp)]
        }
        if let data = try? JSONEncoder().encode(encoded) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    func recordToHistory(song: Song) {
        let entry = (path: song.url.path, timestamp: Date())
        playHistory.removeAll { $0.path == entry.path }
        playHistory.insert(entry, at: 0)
        if playHistory.count > maxHistoryCount {
            playHistory = Array(playHistory.prefix(maxHistoryCount))
        }
        saveHistory()
    }

    func clearHistory() {
        playHistory.removeAll()
        saveHistory()
    }

    func removeFromHistory(song: Song) {
        playHistory.removeAll { $0.path == song.url.path }
        saveHistory()
    }

    private func resolveSavedSongURL(_ saved: SavedSong) -> URL? {
        var isStale = false
        if let url = try? URL(
            resolvingBookmarkData: saved.bookmarkData,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) {
            return url
        }
        if let path = saved.originalPath {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    private func songSnapshot(from saved: SavedSong) -> Song? {
        guard let url = resolveSavedSongURL(saved) else { return nil }
        return Song(
            url: url,
            title: saved.title,
            artist: saved.artist,
            album: saved.album,
            genre: saved.genre,
            year: saved.year,
            trackNumber: saved.trackNumber,
            discNumber: saved.discNumber,
            duration: saved.duration,
            isAvailable: FileManager.default.fileExists(atPath: url.path),
            fileSize: saved.fileSize,
            modificationDate: saved.modificationDate,
            formatName: saved.formatName,
            bitRate: saved.bitRate,
            sampleRate: saved.sampleRate,
            channelCount: saved.channelCount
        )
    }

    private func knownSongsSnapshot() -> [Song] {
        var songs: [Song] = []
        var seenPaths = Set<String>()

        func append(_ song: Song) {
            let path = normalizedPath(for: song.url)
            guard !seenPaths.contains(path) else { return }
            seenPaths.insert(path)
            songs.append(song)
        }

        queue.forEach(append)

        for playlist in playlists {
            for saved in playlist.songs {
                guard let song = songSnapshot(from: saved) else { continue }
                append(song)
            }
        }

        return songs
    }

    func favoriteSongsSnapshot() -> [Song] {
        knownSongsSnapshot().filter { favoriteURLs.contains($0.url.path) }
    }

    func historySongsSnapshot() -> [Song] {
        let knownByPath = Dictionary(uniqueKeysWithValues: knownSongsSnapshot().map { ($0.url.path, $0) })
        var songs: [Song] = []
        var seenPaths = Set<String>()

        for entry in playHistory {
            guard !seenPaths.contains(entry.path),
                  let song = knownByPath[entry.path] else { continue }
            seenPaths.insert(entry.path)
            songs.append(song)
        }

        return songs
    }

    private func configureAudioEngine() {
        guard !engineConfigured else { return }
        engineConfigured = true

        audioEngine.attach(mixNode)
        audioEngine.attach(eqNode)
        audioEngine.attach(timePitchNode)
        playerNodes.forEach { node in
            audioEngine.attach(node)
            audioEngine.connect(node, to: mixNode, format: nil)
        }
        audioEngine.connect(mixNode, to: eqNode, format: nil)
        audioEngine.connect(eqNode, to: timePitchNode, format: nil)
        audioEngine.connect(timePitchNode, to: audioEngine.mainMixerNode, format: nil)
        timePitchNode.rate = playbackRate

        let bandFrequencies: [Float] = [60, 250, 1000, 4000, 10000]
        for (index, band) in eqNode.bands.enumerated() {
            band.filterType = .parametric
            band.frequency = bandFrequencies[min(index, bandFrequencies.count - 1)]
            band.bandwidth = 1.0
            band.gain = 0
            band.bypass = false
        }

        updateOutputVolume()
        startEngineIfNeeded()
        applyEQPreset()
    }

    private func applyEQPreset() {
        let gains = eqPreset.bandGains
        for (index, band) in eqNode.bands.enumerated() {
            if index < gains.count {
                band.gain = gains[index]
            }
        }
    }

    private func startEngineIfNeeded() {
        guard !audioEngine.isRunning else { return }
        do {
            try audioEngine.start()
        } catch {
            reportError("Audio engine başlatılamadı: \(error.localizedDescription)")
        }
    }

    private func updateOutputVolume() {
        mixNode.outputVolume = isMuted ? 0 : volume
    }

    private func refreshNowPlayingInfo() {
        guard currentSongTitle != L10n.t(.noTrackSelected) else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            nowPlayingInfo = [:]
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentSongTitle,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1 : 0
        ]
        if let art = albumArt {
            let artwork = MPMediaItemArtwork(boundsSize: art.size) { _ in art }
            info[MPMediaItemPropertyArtwork] = artwork
        }
        nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingElapsed() {
        guard !nowPlayingInfo.isEmpty else { return }
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1 : 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func normalizedPath(for url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func fileResourceIdentifier(for url: URL) -> String? {
        let values = try? url.resourceValues(forKeys: [.fileResourceIdentifierKey])
        guard let identifier = values?.fileResourceIdentifier else { return nil }
        return String(describing: identifier)
    }

    private func fileSize(for url: URL) -> Int64? {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        guard let size = values?.fileSize else { return nil }
        return Int64(size)
    }

    private func modificationDate(for url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    private func technicalInfo(
        for url: URL,
        duration: TimeInterval
    ) -> (
        fileSize: Int64?,
        modificationDate: Date?,
        formatName: String?,
        bitRate: Int?,
        sampleRate: Double?,
        channelCount: Int?
    ) {
        let currentFileSize = fileSize(for: url)
        let currentModificationDate = modificationDate(for: url)
        let extensionName = url.pathExtension.isEmpty ? nil : url.pathExtension.uppercased()
        var bitRate: Int?
        var sampleRate: Double?
        var channelCount: Int?

        if let file = try? AVAudioFile(forReading: url) {
            let fileFormat = file.fileFormat
            sampleRate = fileFormat.sampleRate > 0 ? fileFormat.sampleRate : nil
            channelCount = fileFormat.channelCount > 0 ? Int(fileFormat.channelCount) : nil

            if let encodedBitRate = fileFormat.settings[AVEncoderBitRateKey] as? Int,
               encodedBitRate > 0 {
                bitRate = encodedBitRate
            }
        }

        if bitRate == nil, let currentFileSize, duration > 0 {
            bitRate = Int((Double(currentFileSize) * 8) / duration)
        }

        return (
            fileSize: currentFileSize,
            modificationDate: currentModificationDate,
            formatName: extensionName,
            bitRate: bitRate,
            sampleRate: sampleRate,
            channelCount: channelCount
        )
    }

    private func datesDiffer(_ lhs: Date?, _ rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return false
        case let (.some(lhs), .some(rhs)):
            return abs(lhs.timeIntervalSince(rhs)) > 0.5
        default:
            return true
        }
    }

    private func metadataSnapshotNeedsRefresh(saved: SavedSong?, url: URL) -> Bool {
        guard let saved else { return true }
        let currentFileSize = fileSize(for: url)
        let currentModificationDate = modificationDate(for: url)

        if saved.fileSize == nil || saved.modificationDate == nil {
            return true
        }
        if saved.fileSize != currentFileSize {
            return true
        }
        return datesDiffer(saved.modificationDate, currentModificationDate)
    }

    private func bookmarkData(for url: URL) -> Data? {
        do {
            return try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            return try? url.bookmarkData()
        }
    }

    private func hasSongEquivalent(to url: URL) -> Bool {
        let path = normalizedPath(for: url)
        let resourceIdentifier = fileResourceIdentifier(for: url)
        return queue.contains { song in
            if normalizedPath(for: song.url) == path {
                return true
            }
            guard let resourceIdentifier else { return false }
            return fileResourceIdentifier(for: song.url) == resourceIdentifier
        }
    }

    private func savedSong(_ savedSong: SavedSong, matches url: URL) -> Bool {
        let path = normalizedPath(for: url)
        if savedSong.originalPath == path {
            return true
        }
        if let resourceIdentifier = savedSong.resourceIdentifier,
           resourceIdentifier == fileResourceIdentifier(for: url) {
            return true
        }

        var isStale = false
        let resolvedURL = try? URL(
            resolvingBookmarkData: savedSong.bookmarkData,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        guard let resolvedURL else { return false }
        return normalizedPath(for: resolvedURL) == path
    }

    private func savedSongs(_ savedSongs: [SavedSong], contain url: URL) -> Bool {
        savedSongs.contains { savedSong in
            self.savedSong(savedSong, matches: url)
        }
    }

    private func makeSavedSong(from song: Song) -> SavedSong? {
        let needsTemporaryAccess = !activeSecurityURLs.contains(song.url)
        let accessGranted = needsTemporaryAccess ? song.url.startAccessingSecurityScopedResource() : false
        defer {
            if needsTemporaryAccess && accessGranted {
                song.url.stopAccessingSecurityScopedResource()
            }
        }

        guard let bookmarkData = bookmarkData(for: song.url) else { return nil }
        let needsAudioTechnical = song.formatName == nil ||
            song.bitRate == nil ||
            song.sampleRate == nil ||
            song.channelCount == nil
        let technical = needsAudioTechnical ?
            technicalInfo(for: song.url, duration: song.duration) :
            (
                fileSize: fileSize(for: song.url),
                modificationDate: modificationDate(for: song.url),
                formatName: song.formatName,
                bitRate: song.bitRate,
                sampleRate: song.sampleRate,
                channelCount: song.channelCount
            )
        return SavedSong(
            bookmarkData: bookmarkData,
            title: song.title,
            artist: song.artist,
            duration: song.duration,
            originalPath: normalizedPath(for: song.url),
            fileSize: technical.fileSize ?? song.fileSize,
            modificationDate: technical.modificationDate ?? song.modificationDate,
            resourceIdentifier: fileResourceIdentifier(for: song.url),
            album: song.album,
            genre: song.genre,
            year: song.year,
            trackNumber: song.trackNumber,
            discNumber: song.discNumber,
            formatName: technical.formatName ?? song.formatName,
            bitRate: technical.bitRate ?? song.bitRate,
            sampleRate: technical.sampleRate ?? song.sampleRate,
            channelCount: technical.channelCount ?? song.channelCount
        )
    }

    private func expandURLs(_ urls: [URL]) -> (audioURLs: [URL], sourceDirectories: [URL], unsupportedCount: Int) {
        var results: [URL] = []
        var sourceDirectories: [URL] = []
        var unsupportedCount = 0
        for url in urls {
            // Klasörün kendisi için güvenlik iznini başlat ve aktif tut
            let accessGranted = url.startAccessingSecurityScopedResource()
            if accessGranted {
                activeSecurityURLs.insert(url)
            }

            if isDirectory(url) {
                sourceDirectories.append(url)
                if let enumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) {
                    for case let fileURL as URL in enumerator {
                        if isDirectory(fileURL) { continue }
                        if isAudioFile(fileURL) {
                            results.append(fileURL)
                        }
                    }
                }
            } else {
                if isAudioFile(url) {
                    results.append(url)
                } else {
                    unsupportedCount += 1
                }
            }
        }
        return (results, sourceDirectories, unsupportedCount)
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    private func isAudioFile(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .audio)
    }

    private func registerLibrarySources(_ urls: [URL]) {
        guard let activeId = activePlaylistId,
              let playlistIndex = playlists.firstIndex(where: { $0.id == activeId }) else { return }

        for url in urls {
            guard let bookmarkData = bookmarkData(for: url) else { continue }
            let path = normalizedPath(for: url)
            let resourceIdentifier = fileResourceIdentifier(for: url)
            let alreadyExists = playlists[playlistIndex].sources.contains { source in
                source.lastKnownPath == path ||
                    (resourceIdentifier != nil && source.resourceIdentifier == resourceIdentifier)
            }
            guard !alreadyExists else { continue }

            playlists[playlistIndex].sources.append(
                LibrarySource(
                    bookmarkData: bookmarkData,
                    name: url.lastPathComponent,
                    lastKnownPath: path,
                    resourceIdentifier: resourceIdentifier,
                    lastScannedAt: Date(),
                    isAvailable: true
                )
            )
        }
    }

    private func resolveLibrarySource(_ source: LibrarySource) -> URL? {
        var isStale = false
        if let url = try? URL(
            resolvingBookmarkData: source.bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) {
            return url
        }
        if let url = try? URL(
            resolvingBookmarkData: source.bookmarkData,
            options: [.withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) {
            return url
        }
        return nil
    }

    private func scheduleStaleSourceRescan() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.rescanActiveLibrarySources(onlyIfStale: true)
        }
    }

    func rescanActiveLibrarySources(onlyIfStale: Bool = false) {
        guard let activeId = activePlaylistId,
              let playlistIndex = playlists.firstIndex(where: { $0.id == activeId }) else { return }

        let now = Date()
        let sources = playlists[playlistIndex].sources
        guard !sources.isEmpty else {
            if !onlyIfStale {
                if queue.isEmpty {
                    showPlaylistNotice(L10n.t(.noLibrarySources))
                } else {
                    refreshActivePlaylistMetadata(force: true)
                    showPlaylistNotice(L10n.t(.libraryRescanComplete))
                }
            } else {
                refreshActivePlaylistMetadata(force: false)
            }
            return
        }

        var urlsToScan: [URL] = []
        var updatedSources = sources
        var unavailableCount = 0

        for index in updatedSources.indices {
            if onlyIfStale,
               let lastScanned = updatedSources[index].lastScannedAt,
               now.timeIntervalSince(lastScanned) < staleSourceScanInterval {
                continue
            }

            guard let url = resolveLibrarySource(updatedSources[index]) else {
                updatedSources[index].isAvailable = false
                unavailableCount += 1
                continue
            }

            let accessGranted = url.startAccessingSecurityScopedResource()
            if accessGranted {
                activeSecurityURLs.insert(url)
            }

            guard FileManager.default.fileExists(atPath: url.path) else {
                updatedSources[index].isAvailable = false
                unavailableCount += 1
                continue
            }

            updatedSources[index].name = url.lastPathComponent
            updatedSources[index].bookmarkData = bookmarkData(for: url) ?? updatedSources[index].bookmarkData
            updatedSources[index].lastKnownPath = normalizedPath(for: url)
            updatedSources[index].resourceIdentifier = fileResourceIdentifier(for: url)
            updatedSources[index].lastScannedAt = now
            updatedSources[index].isAvailable = true
            urlsToScan.append(url)
        }

        playlists[playlistIndex].sources = updatedSources
        guard !urlsToScan.isEmpty else {
            writePlaylistCollection()
            refreshActivePlaylistMetadata(force: !onlyIfStale)
            if !onlyIfStale, unavailableCount > 0 {
                showPlaylistNotice("\(unavailableCount) \(L10n.t(.libraryRescanUnavailable))")
            } else if !onlyIfStale {
                showPlaylistNotice(L10n.t(.libraryRescanComplete))
            }
            return
        }

        let summary = addSongs(urls: urlsToScan, registerSources: false, autoPlay: false, showNotice: false)
        refreshActivePlaylistMetadata(force: !onlyIfStale)
        if let notice = importNotice(for: summary), !onlyIfStale {
            showPlaylistNotice("\(L10n.t(.libraryRescanComplete)) · \(notice)")
        } else if !onlyIfStale {
            showPlaylistNotice(L10n.t(.libraryRescanComplete))
        }
    }

    private func checkAvailability(for url: URL) -> Bool {
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return FileManager.default.fileExists(atPath: url.path)
    }

    nonisolated private func readDurationSync(for url: URL) -> TimeInterval {
        guard let file = try? AVAudioFile(forReading: url) else { return 0 }
        let sampleRate = file.processingFormat.sampleRate
        guard sampleRate > 0 else { return 0 }
        return Double(file.length) / sampleRate
    }

    private func scheduleDurationLoad(for url: URL, songId: UUID) {
        guard (durationCache[url] ?? 0) <= 0 else { return }
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let accessGranted = url.startAccessingSecurityScopedResource()
            defer {
                if accessGranted {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            var resolvedSeconds: TimeInterval = 0
            resolvedSeconds = self.readDurationSync(for: url)
            if resolvedSeconds <= 0 {
                let asyncAsset = AVURLAsset(url: url)
                let duration = (try? await asyncAsset.load(.duration)) ?? .zero
                resolvedSeconds = max(0, CMTimeGetSeconds(duration))
            }
            let finalSeconds = resolvedSeconds
            await MainActor.run {
                if let index = self.queue.firstIndex(where: { $0.id == songId }), finalSeconds > 0 {
                    let technical = self.technicalInfo(for: url, duration: finalSeconds)
                    self.queue[index].duration = finalSeconds
                    self.queue[index].fileSize = technical.fileSize ?? self.queue[index].fileSize
                    self.queue[index].modificationDate = technical.modificationDate ?? self.queue[index].modificationDate
                    self.queue[index].formatName = technical.formatName ?? self.queue[index].formatName
                    self.queue[index].bitRate = technical.bitRate ?? self.queue[index].bitRate
                    self.queue[index].sampleRate = technical.sampleRate ?? self.queue[index].sampleRate
                    self.queue[index].channelCount = technical.channelCount ?? self.queue[index].channelCount
                    self.durationCache[url] = finalSeconds
                    self.savePlaylist()
                }
            }
        }
    }

    private func scheduleMetadataLoad(for url: URL, songId: UUID, force: Bool = false) {
        guard force || metadataCache[url] == nil else { return }
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let accessGranted = url.startAccessingSecurityScopedResource()
            defer {
                if accessGranted {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let asset = AVURLAsset(url: url)
            let info = await self.extractInfo(asset: asset)
            let resolvedSeconds = self.readDurationSync(for: url)
            await MainActor.run {
                guard let index = self.queue.firstIndex(where: { $0.id == songId }) else { return }
                let current = self.queue[index]
                let fallbackTitle = current.url.deletingPathExtension().lastPathComponent
                let fallbackArtist = L10n.t(.unknownArtist)
                let technical = self.technicalInfo(
                    for: current.url,
                    duration: resolvedSeconds > 0 ? resolvedSeconds : current.duration
                )
                let resolvedTitle = info.title ?? (force ? fallbackTitle : current.title)
                let resolvedArtist = info.artist ?? (force ? fallbackArtist : current.artist)
                let resolvedAlbum = info.album ?? (force ? nil : current.album)
                let resolvedGenre = info.genre ?? (force ? nil : current.genre)
                let resolvedYear = info.year ?? (force ? nil : current.year)
                let resolvedTrackNumber = info.trackNumber ?? (force ? nil : current.trackNumber)
                let resolvedDiscNumber = info.discNumber ?? (force ? nil : current.discNumber)
                let resolvedDuration = resolvedSeconds > 0 ? resolvedSeconds : current.duration
                let previousArt = self.metadataCache[current.url]?.art
                let resolvedArt = info.artData.flatMap { NSImage(data: $0) } ?? (force ? nil : previousArt)
                self.queue[index] = Song(
                    id: current.id,
                    url: current.url,
                    title: resolvedTitle,
                    artist: resolvedArtist,
                    album: resolvedAlbum,
                    genre: resolvedGenre,
                    year: resolvedYear,
                    trackNumber: resolvedTrackNumber,
                    discNumber: resolvedDiscNumber,
                    duration: resolvedDuration,
                    isAvailable: current.isAvailable,
                    fileSize: technical.fileSize ?? current.fileSize,
                    modificationDate: technical.modificationDate ?? current.modificationDate,
                    formatName: technical.formatName ?? current.formatName,
                    bitRate: technical.bitRate ?? current.bitRate,
                    sampleRate: technical.sampleRate ?? current.sampleRate,
                    channelCount: technical.channelCount ?? current.channelCount
                )
                if resolvedSeconds > 0 {
                    self.durationCache[current.url] = resolvedSeconds
                }
                self.metadataCache[current.url] = CachedMetadata(
                    title: resolvedTitle,
                    artist: resolvedArtist,
                    album: resolvedAlbum,
                    genre: resolvedGenre,
                    year: resolvedYear,
                    trackNumber: resolvedTrackNumber,
                    discNumber: resolvedDiscNumber,
                    art: resolvedArt
                )
                if self.currentIndex == index {
                    self.currentSongTitle = resolvedTitle
                    self.artist = resolvedArtist
                    self.albumArt = resolvedArt
                    self.refreshNowPlayingInfo()
                }
                self.savePlaylist()
            }
        }
    }

    private func savedSongForQueueIndex(_ index: Int, song: Song) -> SavedSong? {
        if savedSongsCache.indices.contains(index),
           savedSong(savedSongsCache[index], matches: song.url) {
            return savedSongsCache[index]
        }
        return savedSongsCache.first { savedSong($0, matches: song.url) }
    }

    @discardableResult
    private func refreshActivePlaylistMetadata(force: Bool) -> Int {
        var scheduledCount = 0
        for (index, song) in queue.enumerated() {
            let saved = savedSongForQueueIndex(index, song: song)
            guard force || metadataSnapshotNeedsRefresh(saved: saved, url: song.url) else { continue }
            scheduleMetadataLoad(for: song.url, songId: song.id, force: true)
            scheduledCount += 1
        }
        return scheduledCount
    }

    private func beginAccess(for index: Int) -> Bool {
        guard index >= 0 && index < queue.count else { return false }
        let url = queue[index].url
        if activeSecurityURLs.contains(url) { return true }

        let granted = url.startAccessingSecurityScopedResource()
        if granted {
            activeSecurityURLs.insert(url)
            return true
        }

        // Non-sandbox or non-security-scoped bookmarks may still be readable.
        if FileManager.default.isReadableFile(atPath: url.path) {
            return true
        }

        // Attempt to re-authorize access for older playlists.
        if reauthorizeAccess(for: index) {
            return true
        }

        reportError("Dosyaya erişim izni alınamadı: \(url.lastPathComponent)")
        return false
    }

    private func beginAccess(for url: URL, displayName: String) -> Bool {
        if activeSecurityURLs.contains(url) { return true }

        let granted = url.startAccessingSecurityScopedResource()
        if granted {
            activeSecurityURLs.insert(url)
            return true
        }

        if FileManager.default.isReadableFile(atPath: url.path) {
            return true
        }

        reportError("Dosyaya erişim izni alınamadı: \(displayName)")
        return false
    }

    private func reauthorizeAccess(for index: Int) -> Bool {
        if Thread.isMainThread {
            return reauthorizeAccessOnMain(for: index)
        }
        var result = false
        DispatchQueue.main.sync {
            result = reauthorizeAccessOnMain(for: index)
        }
        return result
    }

    private func reauthorizeAccessOnMain(for index: Int) -> Bool {
        guard index >= 0 && index < queue.count else { return false }
        let song = queue[index]

        let panel = NSOpenPanel()
        panel.message = "Erişim izni için dosyayı yeniden seçin."
        panel.prompt = L10n.t(.ok)
        panel.directoryURL = song.url.deletingLastPathComponent()
        panel.allowedContentTypes = [.audio]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.nameFieldStringValue = song.url.lastPathComponent

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return false }

        let technical = technicalInfo(for: selectedURL, duration: song.duration)
        let updatedSong = Song(
            id: song.id,
            url: selectedURL,
            title: song.title,
            artist: song.artist,
            album: song.album,
            genre: song.genre,
            year: song.year,
            trackNumber: song.trackNumber,
            discNumber: song.discNumber,
            duration: song.duration,
            isAvailable: true,
            fileSize: technical.fileSize ?? song.fileSize,
            modificationDate: technical.modificationDate ?? song.modificationDate,
            formatName: technical.formatName ?? song.formatName,
            bitRate: technical.bitRate ?? song.bitRate,
            sampleRate: technical.sampleRate ?? song.sampleRate,
            channelCount: technical.channelCount ?? song.channelCount
        )
        queue[index] = updatedSong

        if let cached = metadataCache[song.url] {
            metadataCache[selectedURL] = cached
            metadataCache.removeValue(forKey: song.url)
        }
        if let cachedDuration = durationCache[song.url] {
            durationCache[selectedURL] = cachedDuration
            durationCache.removeValue(forKey: song.url)
        }

        let accessGranted = selectedURL.startAccessingSecurityScopedResource()
        if accessGranted {
            activeSecurityURLs.insert(selectedURL)
        }

        savePlaylist()
        return accessGranted || FileManager.default.isReadableFile(atPath: selectedURL.path)
    }

    private func endAccess(for url: URL) {
        guard activeSecurityURLs.contains(url) else { return }
        url.stopAccessingSecurityScopedResource()
        activeSecurityURLs.remove(url)
    }

    private func endAllAccess() {
        for url in activeSecurityURLs {
            url.stopAccessingSecurityScopedResource()
        }
        activeSecurityURLs.removeAll()
    }

    private func endAllAccess(except preservedURLs: Set<URL>) {
        for url in Array(activeSecurityURLs) where !preservedURLs.contains(url) {
            url.stopAccessingSecurityScopedResource()
            activeSecurityURLs.remove(url)
        }
    }

    @discardableResult
    func addSongs(
        urls: [URL],
        registerSources: Bool = true,
        autoPlay: Bool = true,
        showNotice: Bool = true
    ) -> ImportSummary {
        let expanded = expandURLs(urls)
        var summary = ImportSummary(unsupportedCount: expanded.unsupportedCount)

        if registerSources {
            registerLibrarySources(expanded.sourceDirectories)
        }

        for url in expanded.audioURLs {
            if hasSongEquivalent(to: url) {
                summary.duplicateCount += 1
                continue
            }

            // Eğer tekil dosya eklendiyse onlara da erişim izni başlat (klasör içindekiler false dönebilir)
            let accessGranted = url.startAccessingSecurityScopedResource()
            if accessGranted {
                activeSecurityURLs.insert(url)
            }

            // Üst klasör veya dosyanın kendi izni aktif olduğu için (isReadableFile true döner)
            if !accessGranted && !FileManager.default.isReadableFile(atPath: url.path) {
                reportError("Dosyaya erişim izni alınamadı: \(url.lastPathComponent)")
                continue
            }

            // Extract metadata and duration
            let cachedMetadata = metadataCache[url]
            let resolvedTitle = cachedMetadata?.title ?? url.deletingPathExtension().lastPathComponent
            let resolvedArtist = cachedMetadata?.artist ?? L10n.t(.unknownArtist)

            // Get duration synchronously
            let cachedDuration = durationCache[url] ?? 0
            let computedDuration = readDurationSync(for: url)
            let resolvedDuration = computedDuration > 0 ? computedDuration : cachedDuration
            if computedDuration > 0 {
                durationCache[url] = computedDuration
            }
            let technical = technicalInfo(for: url, duration: resolvedDuration)

            let song = Song(
                url: url,
                title: resolvedTitle,
                artist: resolvedArtist,
                album: cachedMetadata?.album,
                genre: cachedMetadata?.genre,
                year: cachedMetadata?.year,
                trackNumber: cachedMetadata?.trackNumber,
                discNumber: cachedMetadata?.discNumber,
                duration: resolvedDuration,
                isAvailable: true,
                fileSize: technical.fileSize,
                modificationDate: technical.modificationDate,
                formatName: technical.formatName,
                bitRate: technical.bitRate,
                sampleRate: technical.sampleRate,
                channelCount: technical.channelCount
            )
            queue.append(song)
            summary.addedCount += 1

            if resolvedDuration <= 0 {
                scheduleDurationLoad(for: url, songId: song.id)
            }
            if cachedMetadata == nil {
                scheduleMetadataLoad(for: url, songId: song.id)
            }
        }

        // Save playlist after adding songs
        savePlaylist()

        // If nothing is playing, start first song
        if autoPlay && summary.addedCount > 0 && currentIndex == nil && !queue.isEmpty {
            playSong(at: 0)
        }

        if showNotice, let notice = importNotice(for: summary) {
            showPlaylistNotice(notice)
        }

        return summary
    }

    // Play song at specific index
    func playSong(at index: Int, preserveOrder: Bool = false) {
        guard index >= 0 && index < queue.count else { return }

        var song = queue[index]
        if !song.isAvailable {
            let available = checkAvailability(for: song.url)
            if !available {
                reportError("Dosya bulunamadı: \(song.title)")
                return
            }
            song.isAvailable = true
            queue[index] = song
        }

        if let resumeIndex = pendingResumeIndex, resumeIndex != index {
            pendingResumeIndex = nil
            pendingResumeTime = nil
        }

        guard let resolvedIndex = preparePlaybackOrder(startingAt: index, preserveExisting: preserveOrder) else { return }
        let generation = advancePlaybackGeneration()
        currentIndex = resolvedIndex
        detachedPlaybackSong = nil
        endAllAccess()
        stopNodes()
        configureAudioEngine()
        startEngineIfNeeded()
        activeNodeIndex = 0
        isCrossfading = false
        crossfadeTimer?.invalidate()

        let activeNode = playerNodes[activeNodeIndex]
        let inactiveNode = playerNodes[1 - activeNodeIndex]
        inactiveNode.stop()

        guard scheduleFile(
            for: resolvedIndex,
            on: activeNode,
            startTime: pendingResumeIndex == resolvedIndex ? pendingResumeTime : nil,
            generation: generation
        ) else { return }
        applySongInfo(for: resolvedIndex)
        recordToHistory(song: queue[resolvedIndex])
        currentPlaybackOffset = pendingResumeIndex == resolvedIndex ? (pendingResumeTime ?? 0) : 0

        if let resumeIndex = pendingResumeIndex, resumeIndex == resolvedIndex, let resumeTime = pendingResumeTime {
            pendingResumeIndex = nil
            pendingResumeTime = nil
            currentTime = resumeTime
        } else {
            currentTime = 0
        }

        activeNode.volume = 1
        inactiveNode.volume = 0
        activeNode.play()
        hasPreparedPlayback = true
        isPlaying = true
        startTimer()
        refreshNowPlayingInfo()
    }

    func playSongFromLibraryView(_ song: Song) {
        if let index = queue.firstIndex(where: { normalizedPath(for: $0.url) == normalizedPath(for: song.url) }) {
            playSong(at: index)
            return
        }

        queue.append(song)
        savePlaylist()
        playSong(at: queue.count - 1)
    }

    func artwork(for song: Song) -> NSImage? {
        metadataCache[song.url]?.art
    }

    func prepareSongInfo(for song: Song) {
        guard let index = queue.firstIndex(where: { normalizedPath(for: $0.url) == normalizedPath(for: song.url) }) else { return }
        let current = queue[index]
        let saved = savedSongForQueueIndex(index, song: current)
        let needsFreshMetadata = metadataCache[current.url] == nil ||
            metadataSnapshotNeedsRefresh(saved: saved, url: current.url) ||
            current.album == nil ||
            current.genre == nil ||
            current.year == nil ||
            current.trackNumber == nil ||
            current.discNumber == nil
        scheduleMetadataLoad(for: current.url, songId: current.id, force: needsFreshMetadata)
    }

    func saveTags(for song: Song, draft: SongTagDraft) async -> String? {
        let url = song.url
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let isCurrentSong = currentIndex.flatMap { index -> Song? in
            queue.indices.contains(index) ? queue[index] : nil
        }.map { self.song($0, matches: song) } ?? false
        let wasPlaying = isCurrentSong && isPlaying
        let resumeTime = currentTime

        if wasPlaying {
            togglePlayPause()
        }

        do {
            try await Task.detached(priority: .utility) {
                try ID3TagEditor.write(tags: draft, to: url)
            }.value
            applyTagDraft(draft, to: url)
            if wasPlaying {
                seek(to: resumeTime, shouldResume: true)
            }
            showPlaylistNotice(L10n.t(.tagEditorSaved))
            return nil
        } catch {
            if wasPlaying {
                seek(to: resumeTime, shouldResume: true)
            }
            return error.localizedDescription
        }
    }

    private func applyTagDraft(_ draft: SongTagDraft, to url: URL) {
        let targetPath = normalizedPath(for: url)
        let resolvedTitle = displayTitle(from: draft, url: url)
        let resolvedArtist = displayArtist(from: draft)
        let album = optionalTagValue(draft.album)
        let genre = optionalTagValue(draft.genre)
        let year = optionalTagValue(draft.year)
        let trackNumber = optionalTagValue(draft.trackNumber)
        let discNumber = optionalTagValue(draft.discNumber)
        let resolvedArt = artwork(from: draft.artworkChange, existing: metadataCache[url]?.art)
        var didUpdateQueue = false

        for index in queue.indices where normalizedPath(for: queue[index].url) == targetPath {
            let current = queue[index]
            let technical = technicalInfo(for: current.url, duration: current.duration)
            queue[index] = Song(
                id: current.id,
                url: current.url,
                title: resolvedTitle,
                artist: resolvedArtist,
                album: album,
                genre: genre,
                year: year,
                trackNumber: trackNumber,
                discNumber: discNumber,
                duration: current.duration,
                isAvailable: current.isAvailable,
                fileSize: technical.fileSize ?? current.fileSize,
                modificationDate: technical.modificationDate ?? current.modificationDate,
                formatName: technical.formatName ?? current.formatName,
                bitRate: technical.bitRate ?? current.bitRate,
                sampleRate: technical.sampleRate ?? current.sampleRate,
                channelCount: technical.channelCount ?? current.channelCount
            )
            didUpdateQueue = true
        }

        metadataCache[url] = CachedMetadata(
            title: resolvedTitle,
            artist: resolvedArtist,
            album: album,
            genre: genre,
            year: year,
            trackNumber: trackNumber,
            discNumber: discNumber,
            art: resolvedArt
        )

        if let currentIndex,
           queue.indices.contains(currentIndex),
           normalizedPath(for: queue[currentIndex].url) == targetPath {
            currentSongTitle = resolvedTitle
            artist = resolvedArtist
            albumArt = resolvedArt
            refreshNowPlayingInfo()
        }

        if didUpdateQueue {
            savePlaylist()
        }

        updateSavedTagsAcrossPlaylists(
            matching: url,
            draft: draft,
            title: resolvedTitle,
            artist: resolvedArtist
        )
        writePlaylistCollection()
    }

    private func updateSavedTagsAcrossPlaylists(
        matching url: URL,
        draft: SongTagDraft,
        title: String,
        artist: String
    ) {
        let technical = technicalInfo(for: url, duration: 0)
        for playlistIndex in playlists.indices {
            for songIndex in playlists[playlistIndex].songs.indices {
                let saved = playlists[playlistIndex].songs[songIndex]
                guard savedSong(saved, matches: url) else { continue }
                playlists[playlistIndex].songs[songIndex] = SavedSong(
                    bookmarkData: saved.bookmarkData,
                    title: title,
                    artist: artist,
                    duration: saved.duration,
                    originalPath: normalizedPath(for: url),
                    fileSize: technical.fileSize ?? saved.fileSize,
                    modificationDate: technical.modificationDate ?? saved.modificationDate,
                    resourceIdentifier: fileResourceIdentifier(for: url) ?? saved.resourceIdentifier,
                    album: optionalTagValue(draft.album),
                    genre: optionalTagValue(draft.genre),
                    year: optionalTagValue(draft.year),
                    trackNumber: optionalTagValue(draft.trackNumber),
                    discNumber: optionalTagValue(draft.discNumber),
                    formatName: technical.formatName ?? saved.formatName,
                    bitRate: technical.bitRate ?? saved.bitRate,
                    sampleRate: technical.sampleRate ?? saved.sampleRate,
                    channelCount: technical.channelCount ?? saved.channelCount
                )
                playlists[playlistIndex].updatedAt = Date()
            }
        }

        if let activeId = activePlaylistId,
           let index = playlists.firstIndex(where: { $0.id == activeId }) {
            savedSongsCache = playlists[index].songs
        }
    }

    private func optionalTagValue(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func displayTitle(from draft: SongTagDraft, url: URL) -> String {
        optionalTagValue(draft.title) ?? url.deletingPathExtension().lastPathComponent
    }

    private func displayArtist(from draft: SongTagDraft) -> String {
        optionalTagValue(draft.artist) ?? L10n.t(.unknownArtist)
    }

    private func artwork(from change: SongArtworkChange, existing: NSImage?) -> NSImage? {
        switch change {
        case .keep:
            return existing
        case let .replace(payload):
            return NSImage(data: payload.data) ?? existing
        case .remove:
            return nil
        }
    }

    private func buildPlaybackOrder(startingAt index: Int) -> Int? {
        let availableIndices = queue.indices.filter { queue[$0].isAvailable }
        guard !availableIndices.isEmpty else { return nil }

        if isShuffled {
            playbackOrder = availableIndices.shuffled()
        } else {
            playbackOrder = availableIndices
        }

        if let position = playbackOrder.firstIndex(of: index) {
            playbackPosition = position
            return index
        }

        playbackPosition = 0
        return playbackOrder.first
    }

    private func applySongInfo(for index: Int) {
        guard index >= 0 && index < queue.count else { return }
        let song = queue[index]
        currentSongTitle = song.title
        artist = song.artist
        duration = song.duration

        if let cached = metadataCache[song.url] {
            albumArt = cached.art
        } else {
            albumArt = nil
            scheduleMetadataLoad(for: song.url, songId: song.id)
        }
    }

    private func rebuildPlaybackOrderForCurrent() {
        guard let current = currentIndex else {
            playbackOrder = []
            playbackPosition = 0
            return
        }
        _ = buildPlaybackOrder(startingAt: current)
    }

    private func preparePlaybackOrder(startingAt index: Int, preserveExisting: Bool) -> Int? {
        if preserveExisting, let position = playbackOrder.firstIndex(of: index) {
            playbackPosition = position
            return index
        }
        return buildPlaybackOrder(startingAt: index)
    }

    private func song(_ song: Song, matches other: Song) -> Bool {
        if normalizedPath(for: song.url) == normalizedPath(for: other.url) {
            return true
        }
        guard let resourceIdentifier = fileResourceIdentifier(for: song.url) else { return false }
        return fileResourceIdentifier(for: other.url) == resourceIdentifier
    }

    // Next / Previous functions
    func nextSong() {
        guard let current = currentIndex else { return }
        if repeatMode == .one {
            playSong(at: current, preserveOrder: true)
            return
        }
        guard let nextIndex = nextIndexForAdvance() else {
            finishPlaybackAtEnd()
            return
        }
        transitionTo(index: nextIndex, preserveOrder: true)
    }

    func previousSong() {
        guard let current = currentIndex else { return }
        if repeatMode == .one {
            playSong(at: current, preserveOrder: true)
            return
        }
        guard let prevIndex = previousIndexForAdvance() else { return }
        transitionTo(index: prevIndex, preserveOrder: true)
    }

    private func nextIndexForAdvance() -> Int? {
        let nextPosition = playbackPosition + 1
        if nextPosition < playbackOrder.count {
            playbackPosition = nextPosition
            return playbackOrder[nextPosition]
        }
        if repeatMode == .all, let first = playbackOrder.first {
            playbackPosition = 0
            return first
        }
        return nil
    }

    private func previousIndexForAdvance() -> Int? {
        let prevPosition = playbackPosition - 1
        if prevPosition >= 0 {
            playbackPosition = prevPosition
            return playbackOrder[prevPosition]
        }
        if repeatMode == .all, let last = playbackOrder.last {
            playbackPosition = max(playbackOrder.count - 1, 0)
            return last
        }
        return nil
    }

    private func transitionTo(index: Int, preserveOrder: Bool) {
        if isPlaying, crossfadeDuration > 0 {
            startCrossfade(to: index, preserveOrder: preserveOrder)
        } else {
            playSong(at: index, preserveOrder: preserveOrder)
        }
    }

    // Play/Pause
    func togglePlayPause() {
        if isPlaying {
            audioEngine.pause()
            playerNodes.forEach { $0.pause() }
            isPlaying = false
            stopTimer()
            savePlaybackStateIfNeeded(force: true)
            updateNowPlayingElapsed()
        } else {
            if !hasPreparedPlayback {
                if let index = currentIndex ?? (queue.isEmpty ? nil : 0) {
                    playSong(at: index)
                }
                return
            }
            startEngineIfNeeded()
            playerNodes.forEach { $0.play() }
            isPlaying = true
            startTimer()
            updateNowPlayingElapsed()
        }
    }

    func seek(to time: TimeInterval, shouldResume: Bool = false) {
        guard !isCrossfading else { return }
        let target = max(0, min(time, duration))
        let node = playerNodes[activeNodeIndex]
        let generation = advancePlaybackGeneration()
        node.stop()
        suppressAutoAdvanceUntil = Date().addingTimeInterval(0.6)
        currentPlaybackOffset = target

        let didSchedule: Bool
        if let current = currentIndex {
            didSchedule = scheduleFile(for: current, on: node, startTime: target, generation: generation)
        } else if let detachedPlaybackSong {
            didSchedule = scheduleDetachedFile(detachedPlaybackSong, on: node, startTime: target, generation: generation)
        } else {
            didSchedule = false
        }

        guard didSchedule else { return }

        node.volume = 1
        if shouldResume {
            startEngineIfNeeded()
            node.play()
            if !isPlaying {
                isPlaying = true
                startTimer()
            }
        } else if isPlaying {
            isPlaying = false
            stopTimer()
        }
        currentTime = target
        refreshNowPlayingInfo()
    }

    func seekBy(_ delta: TimeInterval) {
        let target = min(max(currentTime + delta, 0), duration)
        seek(to: target, shouldResume: isPlaying)
    }

    func adjustVolume(by delta: Float) {
        let next = min(max(volume + delta, 0), 1)
        volume = next
    }

    func toggleMute() {
        isMuted.toggle()
    }

    func toggleShuffle() {
        isShuffled.toggle()
        rebuildPlaybackOrderForCurrent()
    }

    func cycleRepeatMode() {
        switch repeatMode {
        case .none:
            repeatMode = .all
        case .all:
            repeatMode = .one
        case .one:
            repeatMode = .none
        }
    }

    func cyclePlaybackSpeed() {
        let speeds: [Float] = [1.0, 1.25, 1.5, 2.0, 0.75, 0.5]
        if let currentIndex = speeds.firstIndex(of: playbackRate) {
            let nextIndex = (currentIndex + 1) % speeds.count
            playbackRate = speeds[nextIndex]
        } else {
            playbackRate = 1.0
        }
    }

    var playbackSpeedText: String {
        if playbackRate == 1.0 { return "1x" }
        if playbackRate == floor(playbackRate) {
            return String(format: "%.0fx", playbackRate)
        }
        return String(format: "%.2gx", playbackRate)
    }

    private func advancePlaybackGeneration() -> Int {
        playbackGeneration += 1
        return playbackGeneration
    }

    private func stopNodes() {
        playerNodes.forEach { node in
            node.stop()
            node.volume = 0
        }
    }

    private func scheduleFile(
        for index: Int,
        on node: AVAudioPlayerNode,
        startTime: TimeInterval?,
        generation: Int
    ) -> Bool {
        guard index >= 0 && index < queue.count else { return false }
        guard beginAccess(for: index) else {
            queue[index].isAvailable = false
            return false
        }
        let url = queue[index].url

        do {
            let file = try AVAudioFile(forReading: url)
            let sampleRate = file.processingFormat.sampleRate
            let startFrame = AVAudioFramePosition((startTime ?? 0) * sampleRate)
            let totalFrames = file.length
            let totalSeconds = sampleRate > 0 ? Double(totalFrames) / sampleRate : 0
            if totalSeconds > 0, (queue[index].duration <= 0 || durationCache[url] == nil) {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.queue[index].duration = totalSeconds
                    self.durationCache[url] = totalSeconds
                    self.savePlaylist()
                }
            }
            if startFrame >= totalFrames {
                endAccess(for: url)
                return false
            }
            let frameCount = AVAudioFrameCount(totalFrames - startFrame)
            node.scheduleSegment(file, startingFrame: startFrame, frameCount: frameCount, at: nil) { [weak self] in
                DispatchQueue.main.async {
                    self?.handleScheduledItemCompleted(for: index, url: url, generation: generation)
                }
            }
            return true
        } catch {
            reportError("Dosya okunamadı: \(url.lastPathComponent)")
            endAccess(for: url)
            return false
        }
    }

    private func scheduleDetachedFile(
        _ song: Song,
        on node: AVAudioPlayerNode,
        startTime: TimeInterval?,
        generation: Int
    ) -> Bool {
        let url = song.url
        guard beginAccess(for: url, displayName: song.title) else { return false }

        do {
            let file = try AVAudioFile(forReading: url)
            let sampleRate = file.processingFormat.sampleRate
            let startFrame = AVAudioFramePosition((startTime ?? 0) * sampleRate)
            let totalFrames = file.length
            let totalSeconds = sampleRate > 0 ? Double(totalFrames) / sampleRate : 0
            if totalSeconds > 0, durationCache[url] == nil {
                durationCache[url] = totalSeconds
                if duration <= 0 {
                    duration = totalSeconds
                }
            }
            if startFrame >= totalFrames {
                endAccess(for: url)
                return false
            }
            let frameCount = AVAudioFrameCount(totalFrames - startFrame)
            node.scheduleSegment(file, startingFrame: startFrame, frameCount: frameCount, at: nil) { [weak self] in
                DispatchQueue.main.async {
                    self?.handleScheduledItemCompleted(for: -1, url: url, generation: generation)
                }
            }
            return true
        } catch {
            reportError("Dosya okunamadı: \(url.lastPathComponent)")
            endAccess(for: url)
            return false
        }
    }

    private func handleScheduledItemCompleted(for index: Int, url: URL, generation: Int) {
        guard generation == playbackGeneration else { return }
        defer {
            endAccess(for: url)
        }
        if isCrossfading {
            return
        }
        if let suppressUntil = suppressAutoAdvanceUntil, Date() < suppressUntil {
            return
        }
        if let currentIndex,
           currentIndex >= 0,
           currentIndex < queue.count,
           queue[currentIndex].url == url,
           isPlaying {
            handleAutoAdvance()
        } else if currentIndex == nil, detachedPlaybackSong?.url == url, isPlaying {
            finishPlaybackAtEnd()
        }
    }

    private func currentPlaybackTime() -> TimeInterval {
        let node = playerNodes[activeNodeIndex]
        guard let nodeTime = node.lastRenderTime,
              let playerTime = node.playerTime(forNodeTime: nodeTime) else { return currentTime }
        let seconds = Double(playerTime.sampleTime) / playerTime.sampleRate
        return currentPlaybackOffset + seconds
    }

    private func handleAutoAdvance() {
        if repeatMode == .one, let current = currentIndex {
            playSong(at: current, preserveOrder: true)
            return
        }
        guard let nextIndex = nextIndexForAdvance() else {
            finishPlaybackAtEnd()
            return
        }
        playSong(at: nextIndex, preserveOrder: true)
    }

    private func checkForAutoAdvance() {
        guard isPlaying, !isCrossfading else { return }
        if let suppressUntil = suppressAutoAdvanceUntil, Date() < suppressUntil {
            return
        }
        let node = playerNodes[activeNodeIndex]
        if !node.isPlaying && duration > 0 && currentTime >= (duration - 0.1) {
            handleAutoAdvance()
        }
    }

    private func peekNextIndex() -> Int? {
        let nextPosition = playbackPosition + 1
        if nextPosition < playbackOrder.count {
            return playbackOrder[nextPosition]
        }
        if repeatMode == .all, let first = playbackOrder.first {
            return first
        }
        return nil
    }

    private func maybeStartCrossfadeIfNeeded() {
        guard isPlaying, !isCrossfading, crossfadeDuration > 0 else { return }
        if let suppressUntil = suppressAutoAdvanceUntil, Date() < suppressUntil {
            return
        }
        guard repeatMode != .one else { return }
        guard duration > 0 else { return }
        let remaining = duration - currentTime
        if remaining <= crossfadeDuration, let nextIndex = peekNextIndex() {
            startCrossfade(to: nextIndex, preserveOrder: true)
        }
    }

    private func startCrossfade(to index: Int, preserveOrder: Bool) {
        guard !isCrossfading else { return }
        guard index >= 0 && index < queue.count else { return }
        guard index != currentIndex else { return }

        startEngineIfNeeded()
        let previousIndex = currentIndex
        _ = preparePlaybackOrder(startingAt: index, preserveExisting: preserveOrder)

        let oldNodeIndex = activeNodeIndex
        let newNodeIndex = 1 - activeNodeIndex
        let oldURL = previousIndex != nil ? queue[previousIndex!].url : nil

        let oldNode = playerNodes[oldNodeIndex]
        let newNode = playerNodes[newNodeIndex]

        newNode.stop()
        let nextGeneration = playbackGeneration + 1
        guard scheduleFile(for: index, on: newNode, startTime: nil, generation: nextGeneration) else { return }
        playbackGeneration = nextGeneration
        currentIndex = index
        detachedPlaybackSong = nil

        oldNode.volume = 1
        newNode.volume = 0
        newNode.play()

        activeNodeIndex = newNodeIndex
        applySongInfo(for: index)
        currentPlaybackOffset = 0
        currentTime = 0
        refreshNowPlayingInfo()

        isCrossfading = true
        crossfadeTimer?.invalidate()
        hasPreparedPlayback = true

        let steps = 20
        let interval = crossfadeDuration / Double(steps)
        var step = 0

        crossfadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            step += 1
            let progress = min(1, Double(step) / Double(steps))
            oldNode.volume = Float(1 - progress)
            newNode.volume = Float(progress)

            if progress >= 1 {
                timer.invalidate()
                oldNode.stop()
                if let url = oldURL {
                    self.endAccess(for: url)
                }
                self.isCrossfading = false
            }
        }
    }

    private enum MetadataField {
        case title
        case artist
        case album
        case genre
        case year
        case trackNumber
        case discNumber
        case artwork
    }

    private func metadataIdentifierText(for item: AVMetadataItem) -> String {
        var parts: [String] = []

        if let commonKey = item.commonKey?.rawValue {
            parts.append(commonKey)
        }
        if let identifier = item.identifier?.rawValue {
            parts.append(identifier)
        }
        if let key = item.key {
            parts.append(String(describing: key))
        }

        return parts.joined(separator: " ").lowercased()
    }

    private func metadataField(for item: AVMetadataItem) -> MetadataField? {
        if item.commonKey == .commonKeyTitle {
            return .title
        }
        if item.commonKey == .commonKeyArtist {
            return .artist
        }
        if item.commonKey == .commonKeyArtwork {
            return .artwork
        }

        let identifier = metadataIdentifierText(for: item)

        if identifier.contains("tit2") ||
            identifier.contains("©nam") ||
            identifier.contains("title") {
            return .title
        }

        if identifier.contains("talb") ||
            identifier.contains("©alb") ||
            (identifier.contains("album") && !identifier.contains("artist")) {
            return .album
        }

        if identifier.contains("tpe1") ||
            identifier.contains("©art") ||
            identifier.contains("leadperformer") ||
            identifier.contains("performer") ||
            identifier.contains("artist") {
            return .artist
        }

        if identifier.contains("tcon") ||
            identifier.contains("©gen") ||
            identifier.contains("genre") {
            return .genre
        }

        if identifier.contains("tdrc") ||
            identifier.contains("tyer") ||
            identifier.contains("©day") ||
            identifier.contains("year") ||
            identifier.contains("date") {
            return .year
        }

        if identifier.contains("trck") ||
            identifier.contains("trkn") ||
            identifier.contains("tracknumber") ||
            identifier.contains("track number") {
            return .trackNumber
        }

        if identifier.contains("tpos") ||
            identifier.contains("disk") ||
            identifier.contains("disc") {
            return .discNumber
        }

        if identifier.contains("apic") ||
            identifier.contains("covr") ||
            identifier.contains("cover") ||
            identifier.contains("artwork") {
            return .artwork
        }

        return nil
    }

    private func metadataString(from item: AVMetadataItem) async -> String? {
        guard let value = try? await item.load(.stringValue) else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func metadataYear(from item: AVMetadataItem) async -> String? {
        guard let value = await metadataString(from: item) else { return nil }
        let components = value.split { !$0.isWholeNumber }
        guard let year = components.first(where: { $0.count >= 4 }) else { return nil }
        return String(year.prefix(4))
    }

    private func metadataNumberText(from item: AVMetadataItem) async -> String? {
        if let value = await metadataString(from: item) {
            return value
        }
        if let number = try? await item.load(.numberValue), number.intValue > 0 {
            return number.stringValue
        }
        return nil
    }

    private func metadataItems(for asset: AVAsset) async -> [AVMetadataItem] {
        var items = (try? await asset.load(.commonMetadata)) ?? []
        let formats = (try? await asset.load(.availableMetadataFormats)) ?? []
        for format in formats {
            let formatItems = (try? await asset.loadMetadata(for: format)) ?? []
            items.append(contentsOf: formatItems)
        }
        return items
    }

    // Helper: Extract metadata from asset
    private func extractInfo(asset: AVAsset) async -> (
        title: String?,
        artist: String?,
        album: String?,
        genre: String?,
        year: String?,
        trackNumber: String?,
        discNumber: String?,
        artData: Data?
    ) {
        var title: String?
        var artist: String?
        var album: String?
        var genre: String?
        var year: String?
        var trackNumber: String?
        var discNumber: String?
        var artData: Data?

        for item in await metadataItems(for: asset) {
            switch metadataField(for: item) {
            case .title:
                if title == nil {
                    title = await metadataString(from: item)
                }
            case .artist:
                if artist == nil {
                    artist = await metadataString(from: item)
                }
            case .album:
                if album == nil {
                    album = await metadataString(from: item)
                }
            case .genre:
                if genre == nil {
                    genre = await metadataString(from: item)
                }
            case .year:
                if year == nil {
                    year = await metadataYear(from: item)
                }
            case .trackNumber:
                if trackNumber == nil {
                    trackNumber = await metadataNumberText(from: item)
                }
            case .discNumber:
                if discNumber == nil {
                    discNumber = await metadataNumberText(from: item)
                }
            case .artwork:
                guard artData == nil else { continue }
                artData = try? await item.load(.dataValue)
            case .none:
                continue
            }
        }
        return (
            title: title,
            artist: artist,
            album: album,
            genre: genre,
            year: year,
            trackNumber: trackNumber,
            discNumber: discNumber,
            artData: artData
        )
    }

    // Timer operations
    func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if !self.isSeeking {
                let seconds = self.currentPlaybackTime()
                if seconds.isFinite {
                    self.currentTime = seconds
                }
                self.savePlaybackStateIfNeeded()
                self.updateNowPlayingElapsed()
                self.checkForAutoAdvance()
                self.maybeStartCrossfadeIfNeeded()
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // Move song in queue (drag & drop)
    func moveSong(from source: IndexSet, to destination: Int) {
        // 1. Remember currently playing song
        let playingSongId = (currentIndex != nil && currentIndex! < queue.count) ? queue[currentIndex!].id : nil

        // 2. Move song in array
        queue.move(fromOffsets: source, toOffset: destination)

        // 3. Find and update new index of playing song
        if let activeId = playingSongId, let newIndex = queue.firstIndex(where: { $0.id == activeId }) {
            currentIndex = newIndex
        }

        // Save after reordering
        rebuildPlaybackOrderForCurrent()
        savePlaylist()
    }

    // MARK: - Playlist Persistence

    // Convert current queue to SavedSongs using security-scoped bookmarks
    private func buildSavedSongs() -> [SavedSong] {
        var savedSongs: [SavedSong] = []

        for song in queue {
            guard let saved = makeSavedSong(from: song) else { continue }
            savedSongs.append(saved)
        }
        return savedSongs
    }

    // Save current state to disk
    func savePlaylist() {
        let savedSongs = buildSavedSongs()
        savedSongsCache = savedSongs

        // Update active playlist's songs
        if let activeId = activePlaylistId,
           let index = playlists.firstIndex(where: { $0.id == activeId }) {
            playlists[index].songs = savedSongs
            playlists[index].updatedAt = Date()
        } else if let firstIndex = playlists.indices.first {
            playlists[firstIndex].songs = savedSongs
            playlists[firstIndex].updatedAt = Date()
        }

        writePlaylistCollection()
    }

    private func writePlaylistCollection() {
        let collection = PlaylistCollection(
            version: playlistCollectionVersion,
            playlists: playlists,
            activePlaylistId: activePlaylistId,
            lastPlayedIndex: currentIndex,
            lastPlayedPosition: currentIndex == nil ? nil : currentTime
        )
        do {
            let data = try JSONEncoder().encode(collection)
            try data.write(to: playlistURL)
        } catch {
            print("Failed to save playlist collection: \(error)")
        }
    }

    private func savePlaybackStateIfNeeded(force: Bool = false) {
        guard currentIndex != nil, !savedSongsCache.isEmpty else { return }
        if !force, abs(currentTime - lastPlaybackSave) < 5 { return }
        lastPlaybackSave = currentTime
        writePlaylistCollection()
    }

    // Load playlists from disk (handles legacy migration)
    func loadPlaylist() {
        guard FileManager.default.fileExists(atPath: playlistURL.path) else {
            // Create default playlist on first launch
            let defaultPlaylist = Playlist(name: L10n.t(.playlist), isDefault: true)
            playlists = [defaultPlaylist]
            activePlaylistId = defaultPlaylist.id
            writePlaylistCollection()
            return
        }

        do {
            let data = try Data(contentsOf: playlistURL)

            // Try new format first
            if let collection = try? JSONDecoder().decode(PlaylistCollection.self, from: data),
               collection.version >= 2 {
                playlists = collection.playlists
                activePlaylistId = collection.activePlaylistId ?? playlists.first?.id

                // Ensure default playlist exists
                if !playlists.contains(where: { $0.isDefault }) {
                    if playlists.isEmpty {
                        let defaultPlaylist = Playlist(name: L10n.t(.playlist), isDefault: true)
                        playlists.append(defaultPlaylist)
                        activePlaylistId = defaultPlaylist.id
                    } else {
                        playlists[0].isDefault = true
                    }
                }

                // Load active playlist songs into queue
                if let active = activePlaylist {
                    loadSongsFromSavedSongs(active.songs)
                }

                // Restore playback position
                if let resumeIndex = collection.lastPlayedIndex, resumeIndex >= 0, resumeIndex < queue.count {
                    let song = queue[resumeIndex]
                    currentIndex = resumeIndex
                    currentSongTitle = song.title
                    artist = song.artist
                    duration = song.duration
                    let resumeTime = min(collection.lastPlayedPosition ?? 0, song.duration)
                    currentTime = max(0, resumeTime)
                    pendingResumeIndex = resumeIndex
                    pendingResumeTime = resumeTime
                }
                return
            }

            // Legacy migration: try old LegacySavedPlaylist format
            let legacyPlaylist: LegacySavedPlaylist?
            if let lp = try? JSONDecoder().decode(LegacySavedPlaylist.self, from: data) {
                legacyPlaylist = lp
            } else {
                legacyPlaylist = nil
            }

            let savedSongs: [SavedSong]
            let lastPlayedIndex: Int?
            let lastPlayedPosition: TimeInterval?
            if let lp = legacyPlaylist {
                savedSongs = lp.songs
                lastPlayedIndex = lp.lastPlayedIndex
                lastPlayedPosition = lp.lastPlayedPosition
            } else {
                savedSongs = try JSONDecoder().decode([SavedSong].self, from: data)
                lastPlayedIndex = nil
                lastPlayedPosition = nil
            }

            // Create default playlist from legacy data
            let defaultPlaylist = Playlist(
                name: L10n.t(.playlist),
                songs: savedSongs,
                isDefault: true
            )
            playlists = [defaultPlaylist]
            activePlaylistId = defaultPlaylist.id

            // Load songs into queue
            loadSongsFromSavedSongs(savedSongs)

            // Restore playback position
            if let resumeIndex = lastPlayedIndex, resumeIndex >= 0, resumeIndex < queue.count {
                let song = queue[resumeIndex]
                currentIndex = resumeIndex
                currentSongTitle = song.title
                artist = song.artist
                duration = song.duration
                let resumeTime = min(lastPlayedPosition ?? 0, song.duration)
                currentTime = max(0, resumeTime)
                pendingResumeIndex = resumeIndex
                pendingResumeTime = resumeTime
            }

            // Migrate to new format
            writePlaylistCollection()
        } catch {
            print("Failed to load playlist: \(error)")
            reportError("Playlist yüklenemedi: \(error.localizedDescription)")
        }
    }

    // Resolve SavedSongs into queue Songs
    private func loadSongsFromSavedSongs(_ savedSongs: [SavedSong]) {
        var refreshedSongs = savedSongs
        var didRefreshSavedSnapshots = false

        for (index, saved) in savedSongs.enumerated() {
            var isStale = false

            let resolvedURL: URL?
            if let url = try? URL(
                resolvingBookmarkData: saved.bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                resolvedURL = url
            } else if let url = try? URL(
                resolvingBookmarkData: saved.bookmarkData,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                resolvedURL = url
            } else {
                resolvedURL = nil
            }

            guard let url = resolvedURL else { continue }
            guard !hasSongEquivalent(to: url) else { continue }

            // Start accessing the security-scoped resource and keep it alive
            let accessGranted = url.startAccessingSecurityScopedResource()
            if accessGranted {
                activeSecurityURLs.insert(url)
            }

            let currentPath = normalizedPath(for: url)
            let technical = technicalInfo(for: url, duration: saved.duration)
            let currentFileSize = technical.fileSize
            let currentModificationDate = technical.modificationDate
            let currentResourceIdentifier = fileResourceIdentifier(for: url)
            let shouldRefreshMetadata = metadataSnapshotNeedsRefresh(saved: saved, url: url)

            var refreshedBookmark: Data?
            if isStale {
                refreshedBookmark = (try? url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )) ?? (try? url.bookmarkData())
            } else {
                refreshedBookmark = bookmarkData(for: url)
            }

            let updatedBookmark = refreshedBookmark ?? saved.bookmarkData
            if updatedBookmark != saved.bookmarkData ||
                saved.originalPath != currentPath ||
                saved.resourceIdentifier != currentResourceIdentifier ||
                saved.fileSize != currentFileSize ||
                datesDiffer(saved.modificationDate, currentModificationDate) ||
                (saved.formatName == nil && technical.formatName != nil) ||
                (saved.bitRate == nil && technical.bitRate != nil) ||
                (saved.sampleRate == nil && technical.sampleRate != nil) ||
                (saved.channelCount == nil && technical.channelCount != nil) {
                refreshedSongs[index] = SavedSong(
                    bookmarkData: updatedBookmark,
                    title: saved.title,
                    artist: saved.artist,
                    duration: saved.duration,
                    originalPath: currentPath,
                    fileSize: currentFileSize,
                    modificationDate: currentModificationDate,
                    resourceIdentifier: currentResourceIdentifier,
                    album: saved.album,
                    genre: saved.genre,
                    year: saved.year,
                    trackNumber: saved.trackNumber,
                    discNumber: saved.discNumber,
                    formatName: technical.formatName ?? saved.formatName,
                    bitRate: technical.bitRate ?? saved.bitRate,
                    sampleRate: technical.sampleRate ?? saved.sampleRate,
                    channelCount: technical.channelCount ?? saved.channelCount
                )
                didRefreshSavedSnapshots = true
            }

            let isFileAvailable = FileManager.default.fileExists(atPath: url.path)
            let song = Song(
                url: url,
                title: saved.title,
                artist: saved.artist,
                album: saved.album,
                genre: saved.genre,
                year: saved.year,
                trackNumber: saved.trackNumber,
                discNumber: saved.discNumber,
                duration: saved.duration,
                isAvailable: isFileAvailable,
                fileSize: currentFileSize,
                modificationDate: currentModificationDate,
                formatName: technical.formatName ?? saved.formatName,
                bitRate: technical.bitRate ?? saved.bitRate,
                sampleRate: technical.sampleRate ?? saved.sampleRate,
                channelCount: technical.channelCount ?? saved.channelCount
            )
            queue.append(song)
            if saved.duration > 0 {
                durationCache[url] = saved.duration
            }

            if saved.duration <= 0 {
                scheduleDurationLoad(for: url, songId: song.id)
            }
            if shouldRefreshMetadata {
                scheduleMetadataLoad(for: url, songId: song.id, force: true)
            }
        }

        savedSongsCache = refreshedSongs

        if didRefreshSavedSnapshots {
            if let activeId = activePlaylistId,
               let playlistIndex = playlists.firstIndex(where: { $0.id == activeId }) {
                playlists[playlistIndex].songs = refreshedSongs
                writePlaylistCollection()
            }
        }
    }

    // MARK: - Multi-Playlist Management

    func createPlaylist(name: String) {
        let playlist = Playlist(name: name)
        playlists.append(playlist)
        writePlaylistCollection()
    }

    func deletePlaylist(id: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        guard !playlists[index].isDefault else { return }

        playlists.remove(at: index)

        if activePlaylistId == id {
            switchPlaylist(to: playlists.first?.id ?? UUID())
        } else {
            writePlaylistCollection()
        }
    }

    func renamePlaylist(id: UUID, newName: String) {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[index].name = newName
        playlists[index].updatedAt = Date()
        writePlaylistCollection()
    }

    func switchPlaylist(to playlistId: UUID) {
        guard let playlist = playlists.first(where: { $0.id == playlistId }) else { return }
        guard playlistId != activePlaylistId else { return }

        // Save current playlist state first
        if let currentId = activePlaylistId,
           let currentIndex = playlists.firstIndex(where: { $0.id == currentId }) {
            playlists[currentIndex].songs = buildSavedSongs()
            playlists[currentIndex].updatedAt = Date()
        }

        let shouldKeepPlayback = hasPreparedPlayback || isPlaying
        let playingSong = currentIndex.flatMap { index in
            queue.indices.contains(index) ? queue[index] : nil
        } ?? detachedPlaybackSong

        if !shouldKeepPlayback {
            stopPlayback(resetPosition: true, clearSelection: true)
            endAllAccess()
        } else if let playingURL = playingSong?.url {
            endAllAccess(except: [playingURL])
        }

        // Clear current visible queue
        queue.removeAll()
        currentIndex = nil
        savedSongsCache = []
        metadataCache = [:]

        // Switch active playlist
        activePlaylistId = playlistId

        // Load new playlist songs
        loadSongsFromSavedSongs(playlist.songs)

        if shouldKeepPlayback, let playingSong {
            if let newIndex = queue.firstIndex(where: { song($0, matches: playingSong) }) {
                currentIndex = newIndex
                detachedPlaybackSong = nil
                rebuildPlaybackOrderForCurrent()
            } else {
                currentIndex = nil
                detachedPlaybackSong = playingSong
                playbackOrder = []
                playbackPosition = 0
            }
        }

        writePlaylistCollection()
    }

    func addSongsToPlaylist(playlistId: UUID, songs: [Song]) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else { return }

        for song in songs {
            guard !savedSongs(playlists[index].songs, contain: song.url),
                  let saved = makeSavedSong(from: song) else { continue }
            playlists[index].songs.append(saved)
        }
        playlists[index].updatedAt = Date()
        writePlaylistCollection()
    }

    func removeSongFromPlaylist(playlistId: UUID, at songIndex: Int) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }),
              songIndex >= 0, songIndex < playlists[index].songs.count else { return }
        playlists[index].songs.remove(at: songIndex)
        playlists[index].updatedAt = Date()
        writePlaylistCollection()
    }

    // Remove song from queue
    func removeSong(at index: Int) {
        guard index >= 0 && index < queue.count else { return }

        // Stop if removing currently playing song
        if currentIndex == index {
            stopPlayback(resetPosition: true, clearSelection: true)
        } else if let current = currentIndex, index < current {
            currentIndex = current - 1
        }

        queue.remove(at: index)
        rebuildPlaybackOrderForCurrent()
        savePlaylist()
    }

    // Play Next: Insert song after currently playing song
    func playNext(song: Song) {
        let insertIndex: Int
        if let current = currentIndex {
            insertIndex = current + 1
        } else {
            insertIndex = 0
        }

        guard insertIndex <= queue.count else { return }
        queue.insert(song, at: insertIndex)
        rebuildPlaybackOrderForCurrent()
        savePlaylist()
    }

    // Add to Queue: Append song to the end of the queue
    func addToQueue(song: Song) {
        queue.append(song)
        rebuildPlaybackOrderForCurrent()
        savePlaylist()
    }

    func clearQueue() {
        stopPlayback(resetPosition: true, clearSelection: true)
        queue.removeAll()
        playbackOrder = []
        playbackPosition = 0
        savePlaylist()
    }

    func removeUnavailableSongs() {
        let currentId = currentIndex != nil && currentIndex! < queue.count ? queue[currentIndex!].id : nil
        queue.removeAll { !$0.isAvailable }

        if let id = currentId, let newIndex = queue.firstIndex(where: { $0.id == id }) {
            currentIndex = newIndex
        } else if currentId != nil {
            stopPlayback(resetPosition: true, clearSelection: true)
        }

        rebuildPlaybackOrderForCurrent()
        savePlaylist()
    }

    private func finishPlaybackAtEnd() {
        _ = advancePlaybackGeneration()
        isPlaying = false
        stopTimer()
        stopNodes()
        audioEngine.pause()
        hasPreparedPlayback = false
        isCrossfading = false
        crossfadeTimer?.invalidate()
        detachedPlaybackSong = nil
        currentTime = duration
        savePlaybackStateIfNeeded(force: true)
        updateNowPlayingElapsed()
        endAllAccess()
    }

    private func stopPlayback(resetPosition: Bool, clearSelection: Bool) {
        _ = advancePlaybackGeneration()
        stopNodes()
        audioEngine.pause()
        hasPreparedPlayback = false
        isCrossfading = false
        crossfadeTimer?.invalidate()
        isPlaying = false
        stopTimer()
        savePlaybackStateIfNeeded(force: true)
        if resetPosition {
            currentTime = 0.0
            duration = 0.0
        }
        if clearSelection {
            currentIndex = nil
            detachedPlaybackSong = nil
            currentSongTitle = L10n.t(.noTrackSelected)
            artist = ""
            albumArt = nil
        }
        refreshNowPlayingInfo()
        endAllAccess()
    }

}
