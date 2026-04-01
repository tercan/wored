import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - Playlist View
struct PlaylistView: View {
    @ObservedObject var viewModel: AudioPlayerViewModel
    @State private var hoveredSongId: UUID?
    @State private var selection: UUID?
    @State private var infoSong: Song?
    @State private var draggingSongId: UUID?
    @State private var showCreatePlaylist = false
    @State private var showRenamePlaylist = false
    @State private var showDeleteConfirm = false
    @State private var newPlaylistName = ""
    @State private var renamePlaylistName = ""
    @State private var targetPlaylistId: UUID?
    
    private var filteredSongs: [Song] {
        viewModel.queue
    }
    
    var body: some View {
        let hasUnavailable = viewModel.queue.contains { !$0.isAvailable }
        
        VStack(spacing: 0) {
            // Header Actions Row
            HStack(spacing: 8) {
                Text(L10n.t(.playlistTitle).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.appTextSecondary)
                    .tracking(1.2)
                
                Spacer()
                
                // Playlist management menu
                if let active = viewModel.activePlaylist {
                    Menu {
                        Button(action: {
                            targetPlaylistId = active.id
                            renamePlaylistName = active.name
                            showRenamePlaylist = true
                        }) {
                            Label(L10n.t(.renamePlaylist), systemImage: "pencil")
                        }
                        
                        if !active.isDefault {
                            Button(role: .destructive, action: {
                                targetPlaylistId = active.id
                                showDeleteConfirm = true
                            }) {
                                Label(L10n.t(.deletePlaylist), systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "folder.badge.gearshape")
                            .font(.system(size: 11))
                            .foregroundColor(.appTextSecondary)
                            .padding(6)
                            .background(Color.appAccent)
                            .cornerRadius(4)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 30)
                }
                
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
                    Button(action: {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = true
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = true
                        panel.allowedContentTypes = [.audio, .folder]
                        
                        panel.begin { response in
                            if response == .OK {
                                let urls = panel.urls
                                DispatchQueue.main.async {
                                    viewModel.addSongs(urls: urls)
                                }
                            }
                        }
                    }) {
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
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .background(Color.appBackground.opacity(0.95))
            
            // Playlist Tabs Row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(viewModel.playlists) { playlist in
                        let isActive = playlist.id == (viewModel.activePlaylistId ?? viewModel.playlists.first?.id)
                        
                        Button(action: {
                            if !isActive {
                                viewModel.switchPlaylist(to: playlist.id)
                            }
                        }) {
                            Text(playlist.name)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(isActive ? .appTextPrimary : .appTextSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .background(isActive ? Color.appBackground : Color.appSecondary.opacity(0.3))
                        .overlay(
                            // 2px Top Border
                            Rectangle()
                                .fill(isActive ? Color.appHighlight : Color.appDivider)
                                .frame(height: 2),
                            alignment: .top
                        )
                        .overlay(
                            // 1px Right Separator
                            Rectangle()
                                .fill(Color.appDivider)
                                .frame(width: 1),
                            alignment: .trailing
                        )
                    }
                    
                    // Create New Playlist Tab Button
                    Button(action: {
                        newPlaylistName = ""
                        showCreatePlaylist = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.appTextSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .background(Color.appSecondary.opacity(0.3))
                    .overlay(
                        // 2px Top Border
                        Rectangle()
                            .fill(Color.appDivider)
                            .frame(height: 2),
                        alignment: .top
                    )
                }
                // Ensure HStack stretches at least the full width
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.appSecondary.opacity(0.3))
            .overlay(
                // Baseline Top Divider for empty space in the ScrollView
                Rectangle()
                    .fill(Color.appDivider)
                    .frame(height: 2),
                alignment: .top
            )
            
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
                        
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 9))
                                .foregroundColor(.appTextSecondary.opacity(0.5))
                            
                            if isPlaying {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundColor(.appHighlight)
                                    .font(.system(size: 9))
                            }
                            
                            VStack(alignment: .leading, spacing: 1) {
                                let displayTitle = song.title
                                let displayText = song.artist.isEmpty ? displayTitle : "\(song.artist) • \(displayTitle)"
                                
                                if isPlaying {
                                    MarqueeText(
                                        text: displayText,
                                        font: .system(size: 10, weight: .medium),
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
                                        .font(.system(size: 10, weight: .medium))
                                        .tracking(-0.2) // tight spacing
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
                                .tracking(-0.1)
                                .foregroundColor(.appTextSecondary)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .tag(song.id)
                        .listRowInsets(EdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 4))
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
                            
                            // Add to other playlists
                            let otherPlaylists = viewModel.playlists.filter { $0.id != viewModel.activePlaylistId }
                            if !otherPlaylists.isEmpty {
                                Divider()
                                Menu(L10n.t(.addToPlaylist)) {
                                    ForEach(otherPlaylists) { playlist in
                                        Button(playlist.name) {
                                            viewModel.addSongsToPlaylist(playlistId: playlist.id, songs: [song])
                                        }
                                    }
                                }
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
                .setupSquareScroller()
                .onDeleteCommand {
                    guard let selectedId = selection,
                          let index = viewModel.queue.firstIndex(where: { $0.id == selectedId }) else { return }
                    viewModel.removeSong(at: index)
                }
            }
        }
        .background(Color.appBackground)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            var handled = false
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url = url {
                            DispatchQueue.main.async {
                                viewModel.addSongs(urls: [url])
                            }
                        }
                    }
                    handled = true
                }
            }
            return handled
        }
        .frame(minWidth: 280, idealWidth: 320, minHeight: 200)
        .alert(item: $infoSong) { song in
            Alert(
                title: Text(song.title),
                message: Text("\(song.artist)\n\(formatDuration(song.duration))"),
                dismissButton: .default(Text(L10n.t(.ok)))
            )
        }
        .overlay(
            Group {
                if showCreatePlaylist || showRenamePlaylist {
                    ZStack {
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                            .onTapGesture {
                                showCreatePlaylist = false
                                showRenamePlaylist = false
                            }
                        
                        if showCreatePlaylist {
                            PlaylistNameSheet(
                                title: L10n.t(.createPlaylist),
                                name: $newPlaylistName,
                                onSave: {
                                    let trimmed = newPlaylistName.trimmingCharacters(in: .whitespaces)
                                    guard !trimmed.isEmpty else { return }
                                    viewModel.createPlaylist(name: trimmed)
                                    showCreatePlaylist = false
                                },
                                onCancel: { showCreatePlaylist = false }
                            )
                        } else if showRenamePlaylist {
                            PlaylistNameSheet(
                                title: L10n.t(.renamePlaylist),
                                name: $renamePlaylistName,
                                onSave: {
                                    let trimmed = renamePlaylistName.trimmingCharacters(in: .whitespaces)
                                    guard !trimmed.isEmpty, let id = targetPlaylistId else { return }
                                    viewModel.renamePlaylist(id: id, newName: trimmed)
                                    showRenamePlaylist = false
                                },
                                onCancel: { showRenamePlaylist = false }
                            )
                        }
                    }
                    .transition(.opacity)
                    .zIndex(100)
                }
            }
        )
        .alert(L10n.t(.deletePlaylist), isPresented: $showDeleteConfirm) {
            Button(L10n.t(.delete), role: .destructive) {
                if let id = targetPlaylistId {
                    viewModel.deletePlaylist(id: id)
                }
            }
            Button(L10n.t(.cancel), role: .cancel) {}
        } message: {
            Text(L10n.t(.deletePlaylistConfirm))
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

// MARK: - Playlist Name Sheet
struct PlaylistNameSheet: View {
    let title: String
    @Binding var name: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.appTextPrimary)
            
            TextField(L10n.t(.playlistName), text: $name)
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color.appBackground)
                .border(Color.appDivider, width: 1)
                .frame(width: 220)
                .onSubmit { onSave() }
            
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text(L10n.t(.cancel))
                        .font(.system(size: 11))
                        .foregroundColor(.appTextSecondary)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.appBackground)
                        .border(Color.appDivider, width: 1)
                }
                .buttonStyle(.plain)
                
                Button(action: onSave) {
                    Text(L10n.t(.ok))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.appBackground)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        // Make button look disabled dynamically
                        .background(name.trimmingCharacters(in: .whitespaces).isEmpty ? Color.appAccent : Color.appHighlight)
                }
                .buttonStyle(.plain)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 280)
        .background(Color.appSecondary.opacity(0.95))
        .border(Color.appDivider, width: 1)
        .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
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

// MARK: - AppKit Custom Square Scroller
class SquareScroller: NSScroller {
    override class var isCompatibleWithOverlayScrollers: Bool { return true }
    
    override func drawKnob() {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        // Remove 2px padding, give it a sharp rectangular look.
        let path = CGPath(rect: self.rect(for: .knob).insetBy(dx: 2, dy: 1), transform: nil)
        context.addPath(path)
        let color = NSColor(Color.appTextSecondary).withAlphaComponent(0.6)
        context.setFillColor(color.cgColor)
        context.fillPath()
    }
}

struct CustomScrollerModifier: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let scrollView = view.enclosingScrollView else { return }
            let scroller = SquareScroller()
            scrollView.verticalScroller = scroller
            scrollView.hasVerticalScroller = true
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension View {
    func setupSquareScroller() -> some View {
        self.background(CustomScrollerModifier())
    }
}
