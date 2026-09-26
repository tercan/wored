import SwiftUI
import UniformTypeIdentifiers
import AppKit

private enum PlaylistContentMode: CaseIterable {
    case playlist
    case favorites
    case history

    var icon: String {
        switch self {
        case .playlist:
            return "music.note.list"
        case .favorites:
            return "heart"
        case .history:
            return "clock.arrow.circlepath"
        }
    }

    var title: String {
        switch self {
        case .playlist:
            return L10n.t(.playlistView)
        case .favorites:
            return L10n.t(.favoritesView)
        case .history:
            return L10n.t(.historyView)
        }
    }
}

// MARK: - Playlist View
struct PlaylistView: View {
    @ObservedObject var viewModel: AudioPlayerViewModel
    @State private var hoveredSongId: UUID?
    @State private var selection: Set<String> = []
    @State private var draggingSongId: UUID?
    @State private var showCreatePlaylist = false
    @State private var showRenamePlaylist = false
    @State private var showDeleteConfirm = false
    @State private var showClearHistoryConfirm = false
    @State private var newPlaylistName = ""
    @State private var renamePlaylistName = ""
    @State private var targetPlaylistId: UUID?
    @State private var isFileDropTarget = false
    @State private var searchText = ""
    @State private var contentMode: PlaylistContentMode = .playlist
    @FocusState private var isSearchFocused: Bool

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isFiltering: Bool {
        !trimmedSearchText.isEmpty
    }

    private var contentSongs: [Song] {
        switch contentMode {
        case .playlist:
            return viewModel.queue
        case .favorites:
            return viewModel.favoriteSongsSnapshot()
        case .history:
            return viewModel.historySongsSnapshot()
        }
    }

    private var filteredSongs: [Song] {
        guard isFiltering else { return contentSongs }

        return contentSongs.filter { song in
            song.title.localizedCaseInsensitiveContains(trimmedSearchText) ||
                song.artist.localizedCaseInsensitiveContains(trimmedSearchText) ||
                song.url.lastPathComponent.localizedCaseInsensitiveContains(trimmedSearchText)
        }
    }

    private var statusText: String {
        var segments: [String] = []
        let totalCount = contentSongs.count
        let visibleCount = filteredSongs.count
        let unavailableCount = contentSongs.filter { !$0.isAvailable }.count
        let totalDuration = contentSongs.reduce(0) { $0 + $1.duration }

        if isFiltering {
            segments.append("\(visibleCount)/\(totalCount) \(L10n.t(.resultCountSuffix))")
        } else {
            segments.append("\(totalCount) \(L10n.t(.songCountSuffix))")
        }

        if totalDuration > 0 {
            segments.append(formatTotalDuration(totalDuration))
        }

        if !selection.isEmpty {
            segments.append("\(selection.count) \(L10n.t(.selectedCountSuffix))")
        }

        if unavailableCount > 0 {
            segments.append("\(unavailableCount) \(L10n.t(.missingCountSuffix))")
        }

        return segments.joined(separator: " · ")
    }

    private var isClearDisabled: Bool {
        switch contentMode {
        case .playlist:
            return viewModel.queue.isEmpty
        case .favorites:
            return viewModel.favoriteURLs.isEmpty
        case .history:
            return viewModel.playHistory.isEmpty
        }
    }

    var body: some View {
        let hasUnavailable = viewModel.queue.contains { !$0.isAvailable }
        let isSearchEmpty = isFiltering && filteredSongs.isEmpty && !contentSongs.isEmpty

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

                        Divider()

                        Button(action: {
                            viewModel.rescanActiveLibrarySources()
                        }) {
                            Label(L10n.t(.rescanLibrary), systemImage: "arrow.clockwise")
                        }
                        .disabled(active.sources.isEmpty && viewModel.queue.isEmpty)
                    } label: {
                        Image(systemName: "folder.badge.gearshape")
                            .font(.system(size: 11))
                            .foregroundColor(.appTextSecondary)
                            .padding(6)
                            .background(Color.appAccent)
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
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .disabled(contentMode != .playlist || !hasUnavailable)
                }

                TooltippedView(tooltip: L10n.t(.clear)) {
                    Button(action: requestClearCurrentView) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.appTextSecondary)
                            .padding(6)
                            .background(Color.appAccent)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .disabled(isClearDisabled)
                }

                TooltippedView(tooltip: L10n.t(.add)) {
                    Button(action: openSongPanel) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.appTextPrimary)
                            .padding(6)
                            .background(Color.appAccent)
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
                            contentMode = .playlist
                            searchText = ""
                            selection.removeAll()
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

            contentModeSelector

            Divider().overlay(Color.appDivider)

            playlistSearchBar

            Divider().overlay(Color.appDivider)

            if filteredSongs.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: isSearchEmpty ? "magnifyingglass" : emptyStateIcon)
                        .font(.system(size: 18))
                        .foregroundColor(.appHighlight)
                    Text(isSearchEmpty ? L10n.t(.noSearchResults) : emptyStateTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.appTextPrimary)
                    if isSearchEmpty {
                        Button(action: clearSearch) {
                            Text(L10n.t(.clearSearch))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.appHighlightText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.appSecondary)
                                .border(Color.appDivider, width: 1)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(emptyStateSubtitle)
                            .font(.system(size: 10))
                            .foregroundColor(.appTextSecondary)
                        if contentMode == .playlist {
                            Text(L10n.t(.dropToAddSongs))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.appHighlightText)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.appBackground)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isSearchEmpty {
                        clearSearch()
                    } else if contentMode == .playlist {
                        openSongPanel()
                    }
                }
            } else {
                List(selection: $selection) {
                    ForEach(filteredSongs, id: \.url.path) { song in
                        let index = queueIndex(for: song)
                        let isPlaying = isPlayingSong(song)
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
                        .tag(selectionKey(for: song))
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
                            isReorderEnabled: contentMode == .playlist && !isFiltering
                        ))
                        .onTapGesture(count: 2) {
                            playSong(song)
                        }
                        .contextMenu {
                            Button(L10n.t(.play)) {
                                playSong(song)
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
                            Button(L10n.t(.editTags)) {
                                showSongInfo(for: song, startEditing: true)
                            }
                            Button(L10n.t(.info)) {
                                showSongInfo(for: song, startEditing: false)
                            }
                            if contentMode == .playlist || contentMode == .history {
                                Divider()
                                if contentMode == .playlist, let index {
                                    Button(L10n.t(.delete)) {
                                        viewModel.removeSong(at: index)
                                    }
                                } else if contentMode == .history {
                                    Button(L10n.t(.removeFromHistory)) {
                                        viewModel.removeFromHistory(song: song)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
                .setupSquareScroller()
                .onDeleteCommand {
                    removeSelectedSongs()
                }
            }

            Divider().overlay(Color.appDivider)
            playlistStatusBar

            if let notice = viewModel.playlistNotice {
                Divider().overlay(Color.appDivider)
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundColor(.appHighlight)
                    Text(notice)
                        .font(.system(size: 10))
                        .foregroundColor(.appTextSecondary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(Color.appSecondary.opacity(0.35))
            }
        }
        .background(Color.appBackground)
        .background {
            if !showCreatePlaylist && !showRenamePlaylist {
                shortcutButtons
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isFileDropTarget) { providers in
            handleFileDrop(providers: providers)
        }
        .onChange(of: viewModel.activePlaylistId) { _, _ in
            searchText = ""
            selection.removeAll()
        }
        .overlay {
            if isFileDropTarget {
                ZStack {
                    Color.appBackground.opacity(0.82)
                    Rectangle()
                        .stroke(Color.appHighlight, lineWidth: 1)
                        .padding(6)
                    Text(L10n.t(.dropToAddSongs))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.appHighlightText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.appSecondary)
                        .border(Color.appDivider, width: 1)
                }
            }
        }
        .frame(minWidth: 280, idealWidth: 320, minHeight: 200)
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
        .alert(L10n.t(.clearHistoryTitle), isPresented: $showClearHistoryConfirm) {
            Button(L10n.t(.clear), role: .destructive) {
                clearCurrentView()
            }
            Button(L10n.t(.cancel), role: .cancel) {}
        } message: {
            Text(L10n.t(.clearHistoryConfirm))
        }
    }

    private var contentModeSelector: some View {
        HStack(spacing: 0) {
            ForEach(PlaylistContentMode.allCases, id: \.self) { mode in
                let isActive = contentMode == mode
                Button(action: {
                    contentMode = mode
                    searchText = ""
                    selection.removeAll()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 9, weight: .medium))
                        Text(mode.title)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(isActive ? .appTextPrimary : .appTextSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .background(isActive ? Color.appBackground : Color.appSecondary.opacity(0.25))
                .overlay(
                    Rectangle()
                        .fill(isActive ? Color.appHighlight : Color.appDivider)
                        .frame(height: 1),
                    alignment: .bottom
                )
                .overlay(
                    Rectangle()
                        .fill(Color.appDivider)
                        .frame(width: mode == .history ? 0 : 1),
                    alignment: .trailing
                )
            }
        }
        .background(Color.appSecondary.opacity(0.25))
    }

    private var playlistSearchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundColor(.appTextSecondary)

            TextField(L10n.t(.searchPlaceholder), text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 10))
                .foregroundColor(.appTextPrimary)
                .focused($isSearchFocused)

            if isFiltering {
                Button(action: clearSearch) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.appTextSecondary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .accessibilityLabel(L10n.t(.clearSearch))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Color.appSecondary.opacity(0.35))
    }

    private var playlistStatusBar: some View {
        HStack(spacing: 6) {
            Text(statusText)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.appTextSecondary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(height: 22)
        .background(Color.appBackground)
    }

    private var emptyStateIcon: String {
        switch contentMode {
        case .playlist:
            return "music.note.list"
        case .favorites:
            return "heart"
        case .history:
            return "clock.arrow.circlepath"
        }
    }

    private var emptyStateTitle: String {
        switch contentMode {
        case .playlist:
            return L10n.t(.emptyStateTitle)
        case .favorites:
            return L10n.t(.emptyFavoritesTitle)
        case .history:
            return L10n.t(.emptyHistoryTitle)
        }
    }

    private var emptyStateSubtitle: String {
        switch contentMode {
        case .playlist:
            return L10n.t(.emptyStateSubtitle)
        case .favorites:
            return L10n.t(.emptyFavoritesSubtitle)
        case .history:
            return L10n.t(.emptyHistorySubtitle)
        }
    }

    private var shortcutButtons: some View {
        Group {
            Button(action: focusSearch) {
                EmptyView()
            }
            .keyboardShortcut("f", modifiers: [.command])

            Button(action: playSelectedSong) {
                EmptyView()
            }
            .keyboardShortcut(.return, modifiers: [])

            Button(action: createPlaylistFromShortcut) {
                EmptyView()
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button(action: selectAllVisibleSongs) {
                EmptyView()
            }
            .keyboardShortcut("a", modifiers: [.command])

            Button(action: clearQueueFromShortcut) {
                EmptyView()
            }
            .keyboardShortcut(.delete, modifiers: [.command, .shift])

            Button(action: clearSearchOrSelection) {
                EmptyView()
            }
            .keyboardShortcut(.cancelAction)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    // Helper: Format duration to mm:ss
    func formatDuration(_ time: TimeInterval) -> String {
        guard time > 0 else { return "--:--" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func formatTotalDuration(_ time: TimeInterval) -> String {
        let seconds = Int(time)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    func clearSearch() {
        searchText = ""
        isSearchFocused = true
    }

    func focusSearch() {
        isSearchFocused = true
    }

    func selectionKey(for song: Song) -> String {
        song.url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    func queueIndex(for song: Song) -> Int? {
        let key = selectionKey(for: song)
        return viewModel.queue.firstIndex { selectionKey(for: $0) == key }
    }

    func isPlayingSong(_ song: Song) -> Bool {
        guard let index = viewModel.currentIndex,
              viewModel.queue.indices.contains(index) else { return false }
        return selectionKey(for: viewModel.queue[index]) == selectionKey(for: song)
    }

    func playSong(_ song: Song) {
        if let index = queueIndex(for: song) {
            viewModel.playSong(at: index)
        } else {
            viewModel.playSongFromLibraryView(song)
        }
    }

    func playSelectedSong() {
        guard let song = filteredSongs.first(where: { selection.contains(selectionKey(for: $0)) }) else { return }
        playSong(song)
    }

    func selectAllVisibleSongs() {
        selection = Set(filteredSongs.map { selectionKey(for: $0) })
    }

    func removeSelectedSongs() {
        guard !selection.isEmpty else { return }
        switch contentMode {
        case .playlist:
            for index in viewModel.queue.indices.reversed() where selection.contains(selectionKey(for: viewModel.queue[index])) {
                viewModel.removeSong(at: index)
            }
        case .favorites:
            for song in filteredSongs where selection.contains(selectionKey(for: song)) {
                if viewModel.isFavorite(song: song) {
                    viewModel.toggleFavorite(song: song)
                }
            }
        case .history:
            for song in filteredSongs where selection.contains(selectionKey(for: song)) {
                viewModel.removeFromHistory(song: song)
            }
        }
        selection.removeAll()
    }

    func createPlaylistFromShortcut() {
        newPlaylistName = ""
        showCreatePlaylist = true
    }

    func clearQueueFromShortcut() {
        guard !isClearDisabled else { return }
        requestClearCurrentView()
    }

    func requestClearCurrentView() {
        if contentMode == .history && !viewModel.playHistory.isEmpty {
            showClearHistoryConfirm = true
            return
        }
        clearCurrentView()
    }

    func clearCurrentView() {
        switch contentMode {
        case .playlist:
            viewModel.clearQueue()
        case .favorites:
            viewModel.clearFavorites()
        case .history:
            viewModel.clearHistory()
        }
        searchText = ""
        selection.removeAll()
    }

    func clearSearchOrSelection() {
        if isFiltering {
            searchText = ""
            return
        }
        selection.removeAll()
    }

    func showSongInfo(for song: Song, startEditing: Bool) {
        SongInfoPanelController.shared.show(song: song, startEditing: startEditing)
    }

    func openSongPanel() {
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
    }

    func handleFileDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else { continue }
            handled = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let url = resolveDroppedURL(from: item) else { return }
                DispatchQueue.main.async {
                    viewModel.addSongs(urls: [url])
                }
            }
        }
        return handled
    }

    private func resolveDroppedURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let nsURL = item as? NSURL {
            return nsURL as URL
        }
        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }
        if let string = item as? String {
            return URL(string: string)
        }
        return nil
    }
}

// MARK: - Playlist Name Sheet
struct PlaylistNameSheet: View {
    let title: String
    @Binding var name: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @FocusState private var isNameFocused: Bool

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
                .focused($isNameFocused)
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
        .onAppear {
            DispatchQueue.main.async {
                isNameFocused = true
            }
        }
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
