import SwiftUI
import UniformTypeIdentifiers
import AppKit

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
struct SongDropDelegate: DropDelegate {
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
