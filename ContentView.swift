import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - Player View
struct PlayerView: View {
    @ObservedObject var viewModel: AudioPlayerViewModel
    @ObservedObject private var windowManager = WindowManager.shared
    @Environment(\.openWindow) private var openWindow
    @State private var showInfo = false
    @State private var wasPlayingBeforeSeek = false
    @State private var didRestorePlaylist = false
    
    private var repeatIcon: String {
        viewModel.repeatMode == .one ? "repeat.1" : "repeat"
    }
    
    private var repeatIsActive: Bool {
        viewModel.repeatMode != .none
    }
    
    var body: some View {
        VStack(spacing: 6) {

                
            HStack(spacing: 10) {
                        Group {
                            if let art = viewModel.albumArt {
                                Image(nsImage: art)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 56, height: 56)
                                    .clipped()
                                    .cornerRadius(4)
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.appSecondary)
                                    Image(systemName: "music.note")
                                        .font(.system(size: 18))
                                        .foregroundColor(.appHighlight)
                                }
                                .frame(width: 56, height: 56)
                            }
                        }
                        .frame(width: 56, height: 56, alignment: .topLeading)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    MarqueeText(
                                        text: viewModel.currentSongTitle,
                                        font: .system(size: 12, weight: .semibold),
                                        color: .appTextPrimary,
                                        speed: 28,
                                        delay: 0.8,
                                        spacing: 24
                                    )
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    InfoPanelButton()
                                }
                                
                                MarqueeText(
                                    text: viewModel.artist.isEmpty ? L10n.t(.unknownArtist) : viewModel.artist,
                                    font: .system(size: 10),
                                    color: .appTextSecondary,
                                    speed: 28,
                                    delay: 0.8,
                                    spacing: 24
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            VStack(spacing: 2) {
                                SquareSlider(
                                    value: Binding(
                                        get: { viewModel.currentTime },
                                        set: { newValue in
                                            viewModel.currentTime = newValue
                                        }
                                    ),
                                    range: 0...max(viewModel.duration, 1),
                                    onEditingChanged: { editing in
                                        viewModel.isSeeking = editing
                                        if editing {
                                            wasPlayingBeforeSeek = viewModel.isPlaying
                                        } else {
                                            let shouldResume = wasPlayingBeforeSeek || viewModel.isPlaying
                                            viewModel.seek(to: viewModel.currentTime, shouldResume: shouldResume)
                                        }
                                    },
                                    knobSize: 10
                                )
                                .frame(maxWidth: .infinity)
                                .frame(height: 12)
                                .focusable(false)
                                
                                HStack {
                                    Text(formatTime(viewModel.currentTime))
                                    Spacer()
                                    Text(formatTime(viewModel.duration))
                                }
                                .frame(maxWidth: .infinity)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.appTextSecondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    
                    GeometryReader { geo in
                        let totalWidth = geo.size.width
                        let controlsWidth = totalWidth * 0.8
                        let actionsWidth = max(totalWidth * 0.2 - 8, 0)
                        
                        HStack(spacing: 8) {
                            HStack(spacing: 6) {
                            Button(action: { viewModel.previousSong() }) {
                                Image(systemName: "backward.end.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.appControlDefault)
                                    .frame(width: 18, height: 18)
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                            .contentShape(Rectangle())
                            .overlay(
                                Rectangle()
                                    .stroke(Color.appControlDefault.opacity(0.3), lineWidth: 1)
                            )
                            
                            Button(action: { viewModel.togglePlayPause() }) {
                                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(viewModel.isPlaying ? .appControlActive : .appControlDefault)
                                    .frame(width: 18, height: 18)
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                            .keyboardShortcut(.space, modifiers: [])
                            .contentShape(Rectangle())
                            .overlay(
                                Rectangle()
                                    .stroke(Color.appControlDefault.opacity(0.3), lineWidth: 1)
                            )
                            
                            Button(action: { viewModel.nextSong() }) {
                                Image(systemName: "forward.end.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.appControlDefault)
                                    .frame(width: 18, height: 18)
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                            .contentShape(Rectangle())
                            .overlay(
                                Rectangle()
                                    .stroke(Color.appControlDefault.opacity(0.3), lineWidth: 1)
                            )
                            
                            Button(action: { viewModel.toggleShuffle() }) {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 11))
                                    .foregroundColor(viewModel.isShuffled ? .appControlActive : .appControlDefault)
                                    .frame(width: 18, height: 18)
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                            .contentShape(Rectangle())
                            .overlay(
                                Rectangle()
                                    .stroke(Color.appControlDefault.opacity(0.3), lineWidth: 1)
                            )
                            
                            Button(action: { viewModel.cycleRepeatMode() }) {
                                Image(systemName: repeatIcon)
                                    .font(.system(size: 11))
                                    .foregroundColor(repeatIsActive ? .appControlActive : .appControlDefault)
                                    .frame(width: 18, height: 18)
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                            .contentShape(Rectangle())
                            .overlay(
                                Rectangle()
                                    .stroke(Color.appControlDefault.opacity(0.3), lineWidth: 1)
                            )
                            
                            Button(action: { viewModel.cyclePlaybackSpeed() }) {
                                Text(viewModel.playbackSpeedText)
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundColor(viewModel.playbackRate != 1.0 ? .appControlActive : .appControlDefault)
                                    .frame(width: 24, height: 18)
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                            .contentShape(Rectangle())
                            .overlay(
                                Rectangle()
                                    .stroke(Color.appControlDefault.opacity(0.3), lineWidth: 1)
                            )
                            
                            Button(action: { viewModel.toggleMute() }) {
                                Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(viewModel.isMuted ? .appControlActive : .appControlDefault)
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                            
                            SquareSlider(
                                value: Binding(
                                    get: { Double(viewModel.volume) },
                                    set: { viewModel.volume = Float($0) }
                                ),
                                range: 0...1,
                                knobSize: 10
                            )
                            .padding(.leading, 6)
                            .frame(width: 80, height: 12)
                            .focusable(false)
                        }
                            .frame(width: controlsWidth, alignment: .leading)
                            
                        HStack {
                            Button(action: {
                                windowManager.togglePlaylist(openWindow: { openWindow(id: "playlist") })
                            }) {
                                Image(systemName: windowManager.isPlaylistVisible ? "list.bullet.rectangle.fill" : "list.bullet")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.appTextSecondary)
                                    .padding(4)
                                    .background(Color.appSecondary)
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                            .help(L10n.t(.playlist))
                        }
                        .frame(width: actionsWidth, alignment: .trailing)
                        }
                    }
                    .frame(height: 20)
                }
        .padding(5)
        .onChange(of: viewModel.alwaysOnTop) { newValue in
            WindowManager.shared.playerWindow?.level = newValue ? .floating : .normal
        }
        .background(Color.appBackground)
        .frame(width: 300)
        .onAppear {
            guard !didRestorePlaylist else { return }
            didRestorePlaylist = true
            windowManager.restorePlaylistIfNeeded(openWindow: { openWindow(id: "playlist") })
        }
        .onMoveCommand { direction in
            switch direction {
            case .left:
                viewModel.seekBy(-5)
            case .right:
                viewModel.seekBy(5)
            case .up:
                viewModel.adjustVolume(by: 0.05)
            case .down:
                viewModel.adjustVolume(by: -0.05)
            default:
                break
            }
        }
        .alert(item: $viewModel.activeError) { error in
            Alert(
                title: Text(L10n.t(.errorTitle)),
                message: Text(error.message),
                dismissButton: .default(Text(L10n.t(.ok)))
            )
        }
        .preferredColorScheme(viewModel.appTheme.colorScheme)
        .id(viewModel.appLanguage) // Re-render when language changes
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Playlist View
struct PlaylistView: View {
    @ObservedObject var viewModel: AudioPlayerViewModel
    @State private var isImporterPresented = false
    @State private var hoveredSongId: UUID?
    @State private var selection: UUID?
    @State private var infoSong: Song?
    @State private var draggingSongId: UUID?
    
    private var filteredSongs: [Song] {
        viewModel.queue
    }
    
    var body: some View {
        let hasUnavailable = viewModel.queue.contains { !$0.isAvailable }
        
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Text(L10n.t(.playlistTitle))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.appTextSecondary)
                    .tracking(1.2)
                
                Spacer()
                
                TooltippedView(tooltip: L10n.t(.removeMissing)) {
                    Button(action: { viewModel.removeUnavailableSongs() }) {
                        Image(systemName: "trash.slash")
                            .font(.system(size: 11))
                            .foregroundColor(.appTextSecondary)
                            .padding(6)
                            .background(Color.appAccent)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .disabled(!hasUnavailable)
                }
                
                TooltippedView(tooltip: L10n.t(.clear)) {
                    Button(action: { viewModel.clearQueue() }) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.appTextSecondary)
                            .padding(6)
                            .background(Color.appAccent)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .disabled(viewModel.queue.isEmpty)
                }
                
                TooltippedView(tooltip: L10n.t(.add)) {
                    Button(action: { isImporterPresented = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.appTextPrimary)
                            .padding(6)
                            .background(Color.appAccent)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .keyboardShortcut("o", modifiers: [.command])
                }
            }
            .padding(10) // Reduced from 12
            .background(Color.appBackground.opacity(0.95))
            
            Divider().overlay(Color.appDivider)
            
            if filteredSongs.isEmpty {
                VStack(spacing: 4) {
                    Text(L10n.t(.emptyStateTitle))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.appTextPrimary)
                    Text(L10n.t(.emptyStateSubtitle))
                        .font(.system(size: 10))
                        .foregroundColor(.appTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.appBackground)
            } else {
                List(selection: $selection) {
                    ForEach(filteredSongs) { song in
                        let index = viewModel.queue.firstIndex(of: song) ?? 0
                        let isPlaying = viewModel.currentIndex == index
                        let isDragging = draggingSongId == song.id
                        let rowBackground: Color = {
                            if isDragging {
                                return Color.appHighlight
                            }
                            if isPlaying {
                                return Color.appAccent.opacity(0.6)
                            }
                            if hoveredSongId == song.id {
                                return Color.appSecondary
                            }
                            return Color.appBackground
                        }()
                        
                        HStack(spacing: 8) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 10))
                                .foregroundColor(.appTextSecondary.opacity(0.5))
                            
                            Group {
                                if isPlaying {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundColor(.appHighlight)
                                        .font(.system(size: 10))
                                } else {
                                    Text("\(index + 1)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.appTextSecondary)
                                }
                            }
                            .frame(width: 18, alignment: .center)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                let displayTitle = song.title
                                let displayArtist = song.artist.isEmpty ? "" : " • \(song.artist)"
                                let displayText = displayTitle + displayArtist
                                
                                if isPlaying {
                                    MarqueeText(
                                        text: displayText,
                                        font: .system(size: 11, weight: .medium),
                                        color: .appHighlightText,
                                        speed: 28,
                                        delay: 0.8,
                                        spacing: 24
                                    )
                                    .layoutPriority(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .help(displayText)
                                } else {
                                    Text(displayText)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.appTextPrimary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .help(displayText)
                                }
                            }
                            
                            Spacer()
                            
                            if viewModel.isFavorite(song: song) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.appHighlight)
                            }
                            
                            if !song.isAvailable {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.appHighlight)
                            }
                            
                            Text(formatDuration(song.duration))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.appTextSecondary)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .tag(song.id)
                        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                        .listRowBackground(rowBackground)
                        .overlay(alignment: .leading) {
                            if isPlaying {
                                Rectangle()
                                    .fill(Color.appHighlight)
                                    .frame(width: 2)
                                    .offset(x: -4)
                            }
                        }
                        .onHover { isHovered in
                            hoveredSongId = isHovered ? song.id : nil
                        }
                        .onDrag {
                            draggingSongId = song.id
                            return NSItemProvider(object: song.id.uuidString as NSString)
                        }
                        .onDrop(of: [.plainText], delegate: SongDropDelegate(
                            targetSong: song,
                            draggingSongId: $draggingSongId,
                            viewModel: viewModel,
                            isReorderEnabled: true
                        ))
                        .onTapGesture(count: 2) {
                            viewModel.playSong(at: index)
                        }
                        .contextMenu {
                            Button(L10n.t(.play)) {
                                viewModel.playSong(at: index)
                            }
                            Button(L10n.t(.playNext)) {
                                viewModel.playNext(song: song)
                            }
                            Button(L10n.t(.addToQueue)) {
                                viewModel.addToQueue(song: song)
                            }
                            Button(viewModel.isFavorite(song: song) ? L10n.t(.removeFromFavorites) : L10n.t(.addToFavorites)) {
                                viewModel.toggleFavorite(song: song)
                            }
                            Divider()
                            Button(L10n.t(.showInFinder)) {
                                NSWorkspace.shared.activateFileViewerSelecting([song.url])
                            }
                            Button(L10n.t(.info)) {
                                infoSong = song
                            }
                            Divider()
                            Button(L10n.t(.delete)) {
                                viewModel.removeSong(at: index)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
                .onDeleteCommand {
                    guard let selectedId = selection,
                          let index = viewModel.queue.firstIndex(where: { $0.id == selectedId }) else { return }
                    viewModel.removeSong(at: index)
                }
            }
        }
        .background(Color.appBackground)
        .frame(minWidth: 280, idealWidth: 320, minHeight: 200)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.audio, .folder],
            allowsMultipleSelection: true
        ) { result in
            if let urls = try? result.get() {
                viewModel.addSongs(urls: urls)
            }
        }
        .alert(item: $infoSong) { song in
            Alert(
                title: Text(song.title),
                message: Text("\(song.artist)\n\(formatDuration(song.duration))"),
                dismissButton: .default(Text(L10n.t(.ok)))
            )
        }
    }
    
    // Helper: Format duration to mm:ss
    func formatDuration(_ time: TimeInterval) -> String {
        guard time > 0 else { return "--:--" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Drag & Drop Delegate
private struct SongDropDelegate: DropDelegate {
    let targetSong: Song
    @Binding var draggingSongId: UUID?
    let viewModel: AudioPlayerViewModel
    let isReorderEnabled: Bool
    
    func validateDrop(info: DropInfo) -> Bool {
        isReorderEnabled
    }
    
    func performDrop(info: DropInfo) -> Bool {
        guard isReorderEnabled else {
            draggingSongId = nil
            return false
        }
        if let draggingId = draggingSongId,
           draggingId != targetSong.id,
           let fromIndex = viewModel.queue.firstIndex(where: { $0.id == draggingId }),
           let toIndex = viewModel.queue.firstIndex(where: { $0.id == targetSong.id }) {
            let destination = fromIndex < toIndex ? toIndex + 1 : toIndex
            if fromIndex != destination {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.moveSong(from: IndexSet(integer: fromIndex), to: destination)
                }
            }
        }
        draggingSongId = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard isReorderEnabled,
              let draggingId = draggingSongId,
              draggingId != targetSong.id,
              let fromIndex = viewModel.queue.firstIndex(where: { $0.id == draggingId }),
              let toIndex = viewModel.queue.firstIndex(where: { $0.id == targetSong.id }) else { return }
        
        let destination = fromIndex < toIndex ? toIndex + 1 : toIndex
        if fromIndex != destination {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.moveSong(from: IndexSet(integer: fromIndex), to: destination)
            }
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: isReorderEnabled ? .move : .forbidden)
    }
}

// MARK: - Legacy ContentView (for compatibility)
struct ContentView: View {
    @StateObject private var viewModel = AudioPlayerViewModel()
    
    var body: some View {
        PlayerView(viewModel: viewModel)
    }
}

// MARK: - Info Row Helper
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.appTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.appTextPrimary)
        }
    }
}

struct InfoLinkRow: View {
    let label: String
    let title: String
    let url: URL
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.appTextSecondary)
            Spacer()
            Link(title, destination: url)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .underline()
        }
    }
}

// MARK: - Tooltip Wrapper (reliable even when disabled)
private final class TooltipHostingView: NSView {
    var hostingView: NSHostingView<AnyView>?
}

private struct TooltippedView<Content: View>: NSViewRepresentable {
    let tooltip: String
    let content: Content
    
    init(tooltip: String, @ViewBuilder content: () -> Content) {
        self.tooltip = tooltip
        self.content = content()
    }
    
    func makeNSView(context: Context) -> TooltipHostingView {
        let container = TooltipHostingView()
        let hosting = NSHostingView(rootView: AnyView(content))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        container.toolTip = tooltip
        container.hostingView = hosting
        return container
    }
    
    func updateNSView(_ nsView: TooltipHostingView, context: Context) {
        nsView.toolTip = tooltip
        nsView.hostingView?.rootView = AnyView(content)
    }
}

// MARK: - Info Panel (borderless)
private struct SettingsPanelView: View {
    @EnvironmentObject var viewModel: AudioPlayerViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.appHighlight)
                Text(L10n.t(.settings))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.appTextPrimary)
                Spacer()
            }
            .padding(12)
            .padding(.top, 8) // Added extra top spacing
            .background(Color.appSecondary)
            
            Divider().overlay(Color.appDivider)
            
            VStack(alignment: .leading, spacing: 16) {
                // Audio Section
                VStack(spacing: 8) {
                    SectionHeader(title: L10n.t(.settingsAudio))
                    
                    // Crossfade
                    SettingsRow(icon: "waveform", title: L10n.t(.settingsCrossfade)) {
                        HStack(spacing: 8) {
                            Text(String(format: "%.1fs", viewModel.crossfadeDuration))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.appHighlightText)
                                .frame(width: 30, alignment: .trailing)
                            
                            SquareSlider(value: $viewModel.crossfadeDuration, range: 0...5)
                                .frame(width: 60, height: 12)
                        }
                    }
                    
                    // EQ
                    SettingsRow(icon: "slider.vertical.3", title: L10n.t(.settingsEQ)) {
                        Picker("", selection: $viewModel.eqPreset) {
                            ForEach(EQPreset.allCases, id: \.self) { preset in
                                Text(preset.displayName).tag(preset)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                        .labelsHidden()
                    }
                }
                
                // Interface Section
                VStack(spacing: 8) {
                    SectionHeader(title: L10n.t(.settingsUI))
                    
                    SettingsRow(icon: "uiwindow.split.2x1", title: L10n.t(.settingsAlwaysOnTop)) {
                        Toggle("", isOn: $viewModel.alwaysOnTop)
                            .toggleStyle(.switch)
                            .tint(.appHighlight)
                            .labelsHidden()
                            .allowsHitTesting(false) // Handle tap on row
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.alwaysOnTop.toggle()
                    }
                    
                    SettingsRow(icon: "paintpalette", title: L10n.t(.settingsTheme)) {
                        Picker("", selection: $viewModel.appTheme) {
                            ForEach(AppTheme.allCases) { theme in
                                Text(theme.displayName).tag(theme)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                        .labelsHidden()
                    }
                }
                
                // System Section
                VStack(spacing: 8) {
                    SectionHeader(title: L10n.t(.settingsSystem))
                    
                    SettingsRow(icon: "power", title: L10n.t(.settingsLaunchAtStartup)) {
                        Toggle("", isOn: $viewModel.launchAtStartup)
                            .toggleStyle(.switch)
                            .tint(.appHighlight)
                            .labelsHidden()
                            .allowsHitTesting(false) // Handle tap on row
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.launchAtStartup.toggle()
                    }
                    
                    SettingsRow(icon: "globe", title: L10n.t(.settingsLanguage)) {
                        Picker("", selection: $viewModel.appLanguage) {
                            ForEach(AppLanguage.allCases) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                        .labelsHidden()
                    }
                }
                
                Divider().overlay(Color.appDivider.opacity(0.5))
                
                // Footer Info
                HStack {
                    Text("v0.2.0 (2026.02.08)")
                        .font(.system(size: 10))
                        .foregroundColor(.appTextSecondary)
                    Spacer()
                    Text("Tercan Keskin")
                        .font(.system(size: 10))
                        .foregroundColor(.appTextSecondary)
                }
                .padding(.top, 4)
            }
            .padding(16)
            
            Spacer()
        }
        .frame(width: 280, height: 460) // Increased height, slightly narrower
        .background(Color.appBackground)
        .overlay(
            Rectangle()
                .stroke(Color.appDivider, lineWidth: 1)
        )
    }
}

private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.appTextSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 2)
    }
}

private struct SettingsRow<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.appTextSecondary)
                .frame(width: 16)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.appTextPrimary)
            
            Spacer()
            
            content
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.appSecondary.opacity(0.5))
        .cornerRadius(0) // Radiusless
        .overlay(
            Rectangle() // Radiusless border
                .stroke(Color.appDivider.opacity(0.5), lineWidth: 1)
        )
    }
}



private final class InfoPanelController: NSObject, NSWindowDelegate {
    static let shared = InfoPanelController()
    private var panel: NSPanel?
    private var keyMonitor: Any?
    private var clickMonitor: Any?
    
    func toggle(relativeTo anchor: NSView) {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
            stopKeyMonitor()
            stopClickMonitor()
            return
        }
        show(relativeTo: anchor)
    }
    
    private func show(relativeTo anchor: NSView) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 460),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.hasShadow = false
        panel.isOpaque = true
        panel.backgroundColor = .clear // Transparent background for custom view background
        panel.level = .floating
        panel.hidesOnDeactivate = true
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.delegate = self
        
        let hostingView = NSHostingView(rootView: SettingsPanelView().environmentObject(AudioPlayerViewModel.shared))
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 0 // Radiusless
        hostingView.layer?.masksToBounds = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView
        
        if let window = anchor.window {
            let windowFrame = window.frame
            let panelWidth: CGFloat = 280
            let panelHeight: CGFloat = 460
            
            // Default to right side
            var x = windowFrame.maxX + 12
            
            // Check screen bounds
            if let screen = window.screen {
                if x + panelWidth > screen.visibleFrame.maxX {
                   // Move to left side
                   x = windowFrame.minX - panelWidth - 12
                }
            }
            
            // Center vertically relative to player window
            let y = windowFrame.midY - (panelHeight / 2)
            
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        panel.orderFrontRegardless()
        self.panel = panel
        startKeyMonitor()
        startClickMonitor()
    }
    
    func windowDidResignKey(_ notification: Notification) {
        panel?.orderOut(nil)
        stopKeyMonitor()
        stopClickMonitor()
    }
    
    private func startKeyMonitor() {
        stopKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 { // ESC
                self.panel?.orderOut(nil)
                self.stopKeyMonitor()
                return nil
            }
            return event
        }
    }
    
    private func stopKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
    
    private func startClickMonitor() {
        stopClickMonitor()
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let panel = self.panel else { return event }
            if event.window === panel {
                return event
            }
            panel.orderOut(nil)
            self.stopKeyMonitor()
            self.stopClickMonitor()
            return event
        }
    }
    
    private func stopClickMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }
}

private struct InfoPanelButton: NSViewRepresentable {
    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        button.image?.size = NSSize(width: 10, height: 10)
        button.contentTintColor = .appHighlight
        button.target = context.coordinator
        button.action = #selector(Coordinator.clicked(_:))
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        button.frame = NSRect(x: 0, y: 0, width: 18, height: 18)
        button.imageScaling = .scaleProportionallyDown
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 18),
            button.heightAnchor.constraint(equalToConstant: 18)
        ])
        button.imagePosition = .imageOnly
        return button
    }
    
    func updateNSView(_ nsView: NSButton, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    final class Coordinator: NSObject {
        @objc func clicked(_ sender: NSButton) {
            InfoPanelController.shared.toggle(relativeTo: sender)
        }
    }
}

// MARK: - Square Slider (minimal knob)
private final class TrackingSlider: NSSlider {
    var onEditingChanged: ((Bool) -> Void)?
    
    override func mouseDown(with event: NSEvent) {
        onEditingChanged?(true)
        super.mouseDown(with: event)
        onEditingChanged?(false)
    }
}

private final class SquareSliderCell: NSSliderCell {
    var knobSize: CGFloat = 6
    var knobColor: NSColor = .appHighlight
    var trackColor: NSColor = .appDivider
    var trackHeight: CGFloat = 2
    
    override func barRect(flipped: Bool) -> NSRect {
        guard let controlView = controlView else {
            let base = super.barRect(flipped: flipped)
            let height = trackHeight
            return NSRect(x: base.minX, y: base.midY - height / 2, width: base.width, height: height)
        }
        let bounds = controlView.bounds
        let height = trackHeight
        return NSRect(x: bounds.minX, y: bounds.midY - height / 2, width: bounds.width, height: height)
    }
    
    override func knobRect(flipped: Bool) -> NSRect {
        guard let controlView = controlView else {
            let base = super.knobRect(flipped: flipped)
            let bar = barRect(flipped: flipped)
            let size = knobSize
            return NSRect(
                x: base.midX - size / 2,
                y: bar.midY - size / 2,
                width: size,
                height: size
            )
        }
        let bounds = controlView.bounds
        let size = knobSize
        let minValue = minValue
        let maxValue = maxValue
        let ratio = maxValue > minValue ? (doubleValue - minValue) / (maxValue - minValue) : 0
        let x = bounds.minX + CGFloat(ratio) * (bounds.width - size)
        let y = bounds.midY - size / 2
        return NSRect(x: x, y: y, width: size, height: size)
    }
    
    override func drawKnob(_ knobRect: NSRect) {
        let rect = knobRect
        knobColor.setFill()
        rect.fill()
    }
    
    override func drawBar(inside rect: NSRect, flipped: Bool) {
        let bar = barRect(flipped: flipped)
        trackColor.setFill()
        bar.fill()
    }
}

private struct SquareSlider: NSViewRepresentable {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var onEditingChanged: ((Bool) -> Void)? = nil
    var knobSize: CGFloat = 6
    
    func makeNSView(context: Context) -> TrackingSlider {
        let slider = TrackingSlider()
        let cell = SquareSliderCell()
        cell.knobSize = knobSize
        cell.knobColor = .appHighlight
        cell.trackColor = .appDivider
        cell.trackHeight = 2
        slider.cell = cell
        slider.minValue = range.lowerBound
        slider.maxValue = range.upperBound
        slider.doubleValue = value
        slider.isContinuous = true
        slider.target = context.coordinator
        slider.action = #selector(Coordinator.valueChanged(_:))
        slider.onEditingChanged = onEditingChanged
        slider.controlSize = .mini
        slider.focusRingType = .none
        return slider
    }
    
    func updateNSView(_ nsView: TrackingSlider, context: Context) {
        if nsView.minValue != range.lowerBound {
            nsView.minValue = range.lowerBound
        }
        if nsView.maxValue != range.upperBound {
            nsView.maxValue = range.upperBound
        }
        if nsView.doubleValue != value {
            nsView.doubleValue = value
        }
        nsView.onEditingChanged = onEditingChanged
        if let cell = nsView.cell as? SquareSliderCell {
            cell.knobSize = knobSize
            cell.trackColor = .appDivider
            cell.trackHeight = 2
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value)
    }
    
    final class Coordinator: NSObject {
        private var value: Binding<Double>
        
        init(value: Binding<Double>) {
            self.value = value
        }
        
        @objc func valueChanged(_ sender: NSSlider) {
            value.wrappedValue = sender.doubleValue
        }
    }
}

// MARK: - Marquee Text
private struct MarqueeWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color
    let speed: Double
    let delay: Double
    let spacing: CGFloat
    
    @State private var textWidth: CGFloat = 0
    @State private var animate = false
    
    var body: some View {
        GeometryReader { geo in
            let containerWidth = geo.size.width
            ZStack(alignment: .leading) {
                // Always measure text width, even when not scrolling.
                marqueeText(measure: true)
                    .opacity(0)
                if textWidth <= containerWidth || containerWidth <= 0 {
                    Text(text)
                        .font(font)
                        .foregroundColor(color)
                        .lineLimit(1)
                } else {
                    HStack(spacing: spacing) {
                        marqueeText(measure: true)
                        marqueeText(measure: false)
                    }
                    .offset(x: animate ? -(textWidth + spacing) : 0)
                    .animation(
                        .linear(duration: max((textWidth + spacing) / speed, 2))
                            .delay(delay)
                            .repeatForever(autoreverses: false),
                        value: animate
                    )
                    .onAppear { restartAnimation() }
                    .onChange(of: textWidth) { _ in restartAnimation() }
                    .onChange(of: containerWidth) { _ in restartAnimation() }
                }
            }
            .frame(width: containerWidth, alignment: .leading)
            .clipped()
            .onPreferenceChange(MarqueeWidthPreferenceKey.self) { width in
                if width > 0, abs(textWidth - width) > 0.5 {
                    textWidth = width
                }
            }
        }
        .frame(height: 14)
    }
    
    private func marqueeText(measure: Bool) -> some View {
        Text(text)
            .font(font)
            .foregroundColor(color)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: MarqueeWidthPreferenceKey.self,
                        value: measure ? proxy.size.width : 0
                    )
                }
            )
    }
    
    private func restartAnimation() {
        animate = false
        DispatchQueue.main.async {
            animate = true
        }
    }
}

// MARK: - Popover Window Accessor (remove corner radius)
struct PopoverWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { self.apply(to: view) }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { self.apply(to: nsView) }
    }
    
    private func apply(to view: NSView) {
        guard let window = view.window else { return }
        window.hasShadow = false
        window.isOpaque = true
        window.backgroundColor = .appSecondary
        if let contentView = window.contentView {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = 0
            contentView.layer?.masksToBounds = true
        }
    }
}

// MARK: - Scroll Event Handler
struct ScrollableView<Content: View>: NSViewRepresentable {
    let content: Content
    var onVerticalScroll: ((CGFloat) -> Void)?
    var onHorizontalScroll: ((CGFloat) -> Void)?
    
    init(@ViewBuilder content: () -> Content,
         onVerticalScroll: ((CGFloat) -> Void)? = nil,
         onHorizontalScroll: ((CGFloat) -> Void)? = nil) {
        self.content = content()
        self.onVerticalScroll = onVerticalScroll
        self.onHorizontalScroll = onHorizontalScroll
    }
    
    func makeNSView(context: Context) -> NSHostingView<Content> {
        let hostingView = ScrollableHostingView(rootView: content)
        hostingView.onVerticalScroll = onVerticalScroll
        hostingView.onHorizontalScroll = onHorizontalScroll
        return hostingView
    }
    
    func updateNSView(_ nsView: NSHostingView<Content>, context: Context) {
        nsView.rootView = content
        if let scrollable = nsView as? ScrollableHostingView<Content> {
            scrollable.onVerticalScroll = onVerticalScroll
            scrollable.onHorizontalScroll = onHorizontalScroll
        }
    }
}

class ScrollableHostingView<Content: View>: NSHostingView<Content> {
    var onVerticalScroll: ((CGFloat) -> Void)?
    var onHorizontalScroll: ((CGFloat) -> Void)?
    
    override func scrollWheel(with event: NSEvent) {
        if abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) {
            onVerticalScroll?(event.scrollingDeltaY)
        } else if abs(event.scrollingDeltaX) > 0 {
            onHorizontalScroll?(event.scrollingDeltaX)
        }
    }
}

#Preview {
    ContentView()
}
