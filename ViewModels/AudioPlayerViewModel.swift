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
    
    // Favorites storage (URL paths as strings)
    @Published private(set) var favoriteURLs: Set<String> = []
    
    // History storage (song paths with timestamps)
    @Published private(set) var playHistory: [(path: String, timestamp: Date)] = []
    
    // Multi-playlist management
    @Published var playlists: [Playlist] = []
    @Published var activePlaylistId: UUID?
    private let playlistCollectionVersion = 2
    
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
            UserDefaults.standard.set(launchAtStartup, forKey: launchAtStartupKey)
            updateLaunchAtStartup()
        }
    }
    
    private func updateLaunchAtStartup() {
        do {
            if launchAtStartup {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at startup status: \(error)")
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
    
    private func expandURLs(_ urls: [URL]) -> [URL] {
        var results: [URL] = []
        for url in urls {
            // Klasörün kendisi için güvenlik iznini başlat ve aktif tut
            let accessGranted = url.startAccessingSecurityScopedResource()
            if accessGranted {
                activeSecurityURLs.insert(url)
            }
            
            if isDirectory(url) {
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
                }
            }
        }
        return results
    }
    
    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }
    
    private func isAudioFile(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .audio)
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

    private func readDurationSync(for url: URL) -> TimeInterval {
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
                    self.queue[index].duration = finalSeconds
                    self.durationCache[url] = finalSeconds
                    self.savePlaylist()
                }
            }
        }
    }
    
    private func scheduleMetadataLoad(for url: URL, songId: UUID) {
        guard metadataCache[url] == nil else { return }
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
            await MainActor.run {
                guard let index = self.queue.firstIndex(where: { $0.id == songId }) else { return }
                let current = self.queue[index]
                let resolvedTitle = info.title ?? current.title
                let resolvedArtist = info.artist ?? current.artist
                let resolvedArt = info.artData.flatMap { NSImage(data: $0) }
                self.queue[index] = Song(
                    id: current.id,
                    url: current.url,
                    title: resolvedTitle,
                    artist: resolvedArtist,
                    duration: current.duration,
                    isAvailable: current.isAvailable
                )
                self.metadataCache[current.url] = CachedMetadata(
                    title: resolvedTitle,
                    artist: resolvedArtist,
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
        
        let updatedSong = Song(
            id: song.id,
            url: selectedURL,
            title: song.title,
            artist: song.artist,
            duration: song.duration,
            isAvailable: true
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
    
    func addSongs(urls: [URL]) {
        let expandedURLs = expandURLs(urls)
        var seen = Set(queue.map(\.url))
        
        for url in expandedURLs {
            guard !seen.contains(url) else { continue }
            seen.insert(url)
            
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
            
            let song = Song(
                url: url,
                title: resolvedTitle,
                artist: resolvedArtist,
                duration: resolvedDuration,
                isAvailable: true
            )
            queue.append(song)
            
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
        if currentIndex == nil && !queue.isEmpty {
            playSong(at: 0)
        }
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
        currentIndex = resolvedIndex
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
        
        guard scheduleFile(for: resolvedIndex, on: activeNode, startTime: pendingResumeIndex == resolvedIndex ? pendingResumeTime : nil) else { return }
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
        node.stop()
        suppressAutoAdvanceUntil = Date().addingTimeInterval(0.6)
        currentPlaybackOffset = target
        if let current = currentIndex {
            _ = scheduleFile(for: current, on: node, startTime: target)
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
    
    private func stopNodes() {
        playerNodes.forEach { $0.stop() }
    }
    
    private func scheduleFile(for index: Int, on node: AVAudioPlayerNode, startTime: TimeInterval?) -> Bool {
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
                    self?.handleScheduledItemCompleted(for: index)
                }
            }
            return true
        } catch {
            reportError("Dosya okunamadı: \(url.lastPathComponent)")
            endAccess(for: url)
            return false
        }
    }
    
    private func handleScheduledItemCompleted(for index: Int) {
        if isCrossfading {
            return
        }
        if let suppressUntil = suppressAutoAdvanceUntil, Date() < suppressUntil {
            return
        }
        if currentIndex == index && isPlaying {
            handleAutoAdvance()
        }
        if index >= 0 && index < queue.count {
            endAccess(for: queue[index].url)
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
        currentIndex = index
        
        let oldNodeIndex = activeNodeIndex
        let newNodeIndex = 1 - activeNodeIndex
        let oldURL = previousIndex != nil ? queue[previousIndex!].url : nil
        
        let oldNode = playerNodes[oldNodeIndex]
        let newNode = playerNodes[newNodeIndex]
        
        newNode.stop()
        guard scheduleFile(for: index, on: newNode, startTime: nil) else { return }
        
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
    
    // Helper: Extract metadata from asset
    private func extractInfo(asset: AVAsset) async -> (title: String?, artist: String?, artData: Data?) {
        var title: String?
        var artist: String?
        var artData: Data?
        
        let metadataItems = (try? await asset.load(.commonMetadata)) ?? []
        for item in metadataItems {
            if item.commonKey == .commonKeyTitle { title = item.stringValue }
            if item.commonKey == .commonKeyArtist { artist = item.stringValue }
            if item.commonKey == .commonKeyArtwork {
                artData = try? await item.load(.dataValue)
            }
        }
        return (title, artist, artData)
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
            let needsTemporaryAccess = !activeSecurityURLs.contains(song.url)
            let accessGranted = needsTemporaryAccess ? song.url.startAccessingSecurityScopedResource() : false
            defer {
                if needsTemporaryAccess && accessGranted {
                    song.url.stopAccessingSecurityScopedResource()
                }
            }
            
            var bookmarkData: Data?
            do {
                bookmarkData = try song.url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            } catch {
                bookmarkData = try? song.url.bookmarkData()
            }
            
            guard let resolvedBookmark = bookmarkData else { continue }
            
            let saved = SavedSong(
                bookmarkData: resolvedBookmark,
                title: song.title,
                artist: song.artist,
                duration: song.duration
            )
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
        var didRefreshBookmarks = false
        
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
            
            // Start accessing the security-scoped resource and keep it alive
            let accessGranted = url.startAccessingSecurityScopedResource()
            if accessGranted {
                activeSecurityURLs.insert(url)
            }
            
            var refreshedBookmark: Data?
            if isStale {
                refreshedBookmark = (try? url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )) ?? (try? url.bookmarkData())
            } else {
                refreshedBookmark = try? url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            }
            
            if let newBookmark = refreshedBookmark, newBookmark != saved.bookmarkData {
                refreshedSongs[index] = SavedSong(
                    bookmarkData: newBookmark,
                    title: saved.title,
                    artist: saved.artist,
                    duration: saved.duration
                )
                didRefreshBookmarks = true
            }
            
            let isFileAvailable = FileManager.default.fileExists(atPath: url.path)
            let song = Song(
                url: url,
                title: saved.title,
                artist: saved.artist,
                duration: saved.duration,
                isAvailable: isFileAvailable
            )
            queue.append(song)
            if saved.duration > 0 {
                durationCache[url] = saved.duration
            }
            
            if saved.duration <= 0 {
                scheduleDurationLoad(for: url, songId: song.id)
            }
        }
        
        savedSongsCache = refreshedSongs
        
        if didRefreshBookmarks {
            if let activeId = activePlaylistId,
               let playlistIndex = playlists.firstIndex(where: { $0.id == activeId }) {
                playlists[playlistIndex].songs = refreshedSongs
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
        
        // Save current playlist state first
        if let currentId = activePlaylistId,
           let currentIndex = playlists.firstIndex(where: { $0.id == currentId }) {
            playlists[currentIndex].songs = buildSavedSongs()
            playlists[currentIndex].updatedAt = Date()
        }
        
        // Stop playback
        stopPlayback(resetPosition: true, clearSelection: true)
        
        // Clear current queue
        endAllAccess()
        queue.removeAll()
        currentIndex = nil
        savedSongsCache = []
        metadataCache = [:]
        
        // Switch active playlist
        activePlaylistId = playlistId
        
        // Load new playlist songs
        loadSongsFromSavedSongs(playlist.songs)
        
        writePlaylistCollection()
    }
    
    func addSongsToPlaylist(playlistId: UUID, songs: [Song]) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else { return }
        
        for song in songs {
            let needsTemporaryAccess = !activeSecurityURLs.contains(song.url)
            let accessGranted = needsTemporaryAccess ? song.url.startAccessingSecurityScopedResource() : false
            defer {
                if needsTemporaryAccess && accessGranted {
                    song.url.stopAccessingSecurityScopedResource()
                }
            }
            
            var bookmarkData: Data?
            do {
                bookmarkData = try song.url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            } catch {
                bookmarkData = try? song.url.bookmarkData()
            }
            
            guard let resolved = bookmarkData else { continue }
            
            let saved = SavedSong(
                bookmarkData: resolved,
                title: song.title,
                artist: song.artist,
                duration: song.duration
            )
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
        isPlaying = false
        stopTimer()
        stopNodes()
        audioEngine.pause()
        hasPreparedPlayback = false
        isCrossfading = false
        crossfadeTimer?.invalidate()
        currentTime = duration
        savePlaybackStateIfNeeded(force: true)
        updateNowPlayingElapsed()
        endAllAccess()
    }
    
    private func stopPlayback(resetPosition: Bool, clearSelection: Bool) {
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
            currentSongTitle = L10n.t(.noTrackSelected)
            artist = ""
            albumArt = nil
        }
        refreshNowPlayingInfo()
        endAllAccess()
    }
    
}
