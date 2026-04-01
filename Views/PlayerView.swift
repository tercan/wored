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
