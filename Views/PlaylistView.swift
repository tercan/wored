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
    @State private var isSearchVisible = false
    @State private var searchText = ""
    @State private var contentMode: PlaylistContentMode = .playlist
    @State private var isSearchFocused = false
    @State private var searchFocusRequest = 0

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

    private var activePlaylistName: String {
        viewModel.activePlaylist?.name ?? L10n.t(.playlist)
    }

    private var clearTooltip: String {
        switch contentMode {
        case .playlist: return L10n.t(.clearPlaylist)
        case .favorites: return L10n.t(.clearFavorites)
        case .history: return L10n.t(.clearHistoryTitle)
        }
    }

    var body: some View {
        let hasUnavailable = viewModel.queue.contains { !$0.isAvailable }
        let isSearchEmpty = isFiltering && filteredSongs.isEmpty && !contentSongs.isEmpty

        VStack(spacing: 0) {
            playlistHeader

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
                        let isFavorite = viewModel.isFavorite(song: song)
                        let isDragging = draggingSongId == song.id
                        let showsDragHandle = contentMode == .playlist && !isFiltering && (hoveredSongId == song.id || isDragging)
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
                            Image(systemName: showsDragHandle ? "line.3.horizontal" : (isPlaying ? "play.fill" : "speaker.wave.2"))
                                .font(.system(size: 9))
                                .foregroundColor(isPlaying ? .appControlActive : .appTextSecondary)
                                .frame(width: 16, height: 16)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 1) {
                                let displayTitle = song.title
                                let displayText = song.artist.isEmpty ? displayTitle : "\(song.artist) • \(displayTitle)"

                                MarqueeText(
                                    text: displayText,
                                    font: .system(size: 10, weight: .medium),
                                    color: isPlaying ? .appHighlightText : .appTextPrimary,
                                    speed: 28,
                                    delay: 0.8,
                                    spacing: 24,
                                    isScrollingEnabled: isPlaying,
                                    lineHeight: 16
                                )
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .help(displayText)
                            }

                            Spacer()

                            Button {
                                viewModel.toggleFavorite(song: song)
                                if contentMode == .favorites && isFavorite {
                                    selection.remove(selectionKey(for: song))
                                }
                            } label: {
                                Image(systemName: isFavorite ? "heart.fill" : "heart")
                                    .font(.system(size: 9))
                                    .foregroundColor(isPlaying ? .appHighlightText : .appTextPrimary)
                                    .frame(width: 24, height: 24)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(L10n.t(isFavorite ? .removeFromFavorites : .addToFavorites))
                            .accessibilityLabel(L10n.t(isFavorite ? .removeFromFavorites : .addToFavorites))

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
                        .tag(selectionKey(for: song))
                        .listRowInsets(EdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 4))
                        .listRowSeparator(.hidden)
                        .listRowBackground(
                            rowBackground.overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(Color.appDivider)
                                    .frame(height: 1)
                                    .allowsHitTesting(false)
                            }
                        )
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
            playlistFooter(hasUnavailable: hasUnavailable)

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
            WindowHeightResizeHandle()
                .frame(height: 6)
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
            isSearchVisible = false
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

    private var playlistHeader: some View {
        HStack(spacing: 8) {
            playlistMenu

            Spacer(minLength: 8)

            Text(statusText)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.appTextSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(Color.appBackground)
    }

    private func playlistFooter(hasUnavailable: Bool) -> some View {
        VStack(spacing: 0) {
            if isSearchVisible {
                playlistSearchBar
                Divider().overlay(Color.appDivider)
            }

            HStack(spacing: 6) {
                footerButton(icon: "plus", tooltip: L10n.t(.add), action: openSongPanel)

                footerButton(
                    icon: "minus",
                    tooltip: L10n.t(.delete),
                    isDisabled: selection.isEmpty,
                    action: removeSelectedSongs
                )

                footerButton(
                    icon: "magnifyingglass",
                    tooltip: L10n.t(.searchPlaceholder),
                    isActive: isSearchVisible,
                    action: toggleSearch
                )

                contentModeMenu

                Spacer(minLength: 8)

                footerButton(
                    icon: "trash.slash",
                    tooltip: L10n.t(.removeMissing),
                    isDisabled: contentMode != .playlist || !hasUnavailable,
                    action: { viewModel.removeUnavailableSongs() }
                )

                footerButton(
                    icon: "trash",
                    tooltip: clearTooltip,
                    isDisabled: isClearDisabled,
                    action: requestClearCurrentView
                )
            }
            .padding(.horizontal, 8)
            .frame(height: 32)
            .background(Color.appSecondary.opacity(0.22))
        }
    }

    private var playlistMenu: some View {
        Menu {
            ForEach(viewModel.playlists) { playlist in
                let isActive = playlist.id == (viewModel.activePlaylistId ?? viewModel.playlists.first?.id)
                Button(action: {
                    contentMode = .playlist
                    searchText = ""
                    isSearchVisible = false
                    selection.removeAll()
                    if !isActive {
                        viewModel.switchPlaylist(to: playlist.id)
                    }
                }) {
                    Label(playlist.name, systemImage: isActive ? "checkmark" : "music.note.list")
                }
            }

            Divider()

            Button(action: {
                newPlaylistName = ""
                showCreatePlaylist = true
            }) {
                Label(L10n.t(.createPlaylist), systemImage: "plus")
            }

            if let active = viewModel.activePlaylist {
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
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.appTextSecondary)
                Text(activePlaylistName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.appTextPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.appTextSecondary.opacity(0.8))
            }
            .padding(.horizontal, 2)
            .frame(height: 18)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
        .frame(maxWidth: 150, alignment: .leading)
    }

    private var contentModeMenu: some View {
        TooltippedView(tooltip: contentMode.title) {
            Menu {
                ForEach(PlaylistContentMode.allCases, id: \.self) { mode in
                    let isActive = contentMode == mode
                    Button(action: {
                        contentMode = mode
                        searchText = ""
                        selection.removeAll()
                    }) {
                        Label(mode.title, systemImage: isActive ? "checkmark" : mode.icon)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: contentMode.icon)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(contentMode == .playlist ? .appTextSecondary : .appHighlightText)
                    Text(contentMode.title)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(contentMode == .playlist ? .appTextSecondary : .appTextPrimary)
                        .lineLimit(1)
                    Image(systemName: "chevron.up")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.appTextSecondary.opacity(0.8))
                }
                .padding(.horizontal, 2)
                .frame(height: 24)
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(.plain)
            .frame(minWidth: 72, maxWidth: 98, minHeight: 24)
        }
    }

    private func footerButton(
        icon: String,
        tooltip: String,
        isActive: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        TooltippedView(tooltip: tooltip) {
            Button(action: action) {
                footerIconLabel(icon: icon, isActive: isActive, isDisabled: isDisabled)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .disabled(isDisabled)
            .accessibilityLabel(tooltip)
        }
    }

    private func footerIconLabel(icon: String, isActive: Bool = false, isDisabled: Bool = false) -> some View {
        Image(systemName: icon)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(
                isDisabled
                    ? .appTextSecondary.opacity(0.35)
                    : (isActive ? .appControlActive : .appTextSecondary)
            )
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
            .background(isActive ? Color.appAccent.opacity(0.75) : Color.appBackground.opacity(0.35))
            .overlay(Rectangle().stroke(Color.appDivider, lineWidth: 1))
    }

    private var playlistSearchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundColor(.appTextSecondary)

            PlaylistSearchField(
                text: $searchText,
                isFocused: $isSearchFocused,
                focusRequest: searchFocusRequest,
                onCancel: clearSearchOrSelection
            )
            .frame(height: 18)

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
            .disabled(isSearchFocused)

            Button(action: createPlaylistFromShortcut) {
                EmptyView()
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button(action: selectAllVisibleSongs) {
                EmptyView()
            }
            .keyboardShortcut("a", modifiers: [.command])
            .disabled(isSearchFocused)

            Button(action: clearQueueFromShortcut) {
                EmptyView()
            }
            .keyboardShortcut(.delete, modifiers: [.command, .shift])
            .disabled(isSearchFocused)

            Button(action: clearSearchOrSelection) {
                EmptyView()
            }
            .keyboardShortcut(.cancelAction)

            Button(action: openSongPanel) {
                EmptyView()
            }
            .keyboardShortcut("o", modifiers: [.command])
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
        if isSearchVisible {
            searchFocusRequest += 1
        }
    }

    func focusSearch() {
        isSearchVisible = true
        searchFocusRequest += 1
    }

    func toggleSearch() {
        if isSearchVisible {
            searchText = ""
            isSearchFocused = false
            isSearchVisible = false
            return
        }

        focusSearch()
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
        isSearchVisible = false
        selection.removeAll()
    }

    func clearSearchOrSelection() {
        if isSearchVisible {
            if isFiltering {
                searchText = ""
                return
            }
            isSearchFocused = false
            isSearchVisible = false
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

private struct PlaylistSearchField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let focusRequest: Int
    let onCancel: () -> Void

    func makeNSView(context: Context) -> PlaylistSearchTextField {
        let field = PlaylistSearchTextField()
        field.delegate = context.coordinator
        field.isEditable = true
        field.isSelectable = true
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 10)
        field.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ field: PlaylistSearchTextField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text {
            field.stringValue = text
        }
        field.placeholderString = L10n.t(.searchPlaceholder)
        field.setAccessibilityLabel(L10n.t(.searchPlaceholder))
        field.textColor = .appTextPrimary
        field.requestFocus(focusRequest)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: PlaylistSearchField
        init(parent: PlaylistSearchField) { self.parent = parent }

        func controlTextDidBeginEditing(_ notification: Notification) {
            parent.isFocused = true
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            parent.isFocused = false
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onCancel()
                return true
            }
            return commandSelector == #selector(NSResponder.insertNewline(_:))
        }
    }
}

private final class PlaylistSearchTextField: NSTextField {
    private var lastFocusRequest: Int?
    private var hasPendingFocus = false

    override var acceptsFirstResponder: Bool { true }
    override var needsPanelToBecomeKey: Bool { true }

    func requestFocus(_ request: Int) {
        guard request != lastFocusRequest else { return }
        lastFocusRequest = request
        hasPendingFocus = true
        focusIfReady()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        focusIfReady()
    }

    private func focusIfReady() {
        guard hasPendingFocus, window != nil else { return }
        hasPendingFocus = false
        // Request once on opening/refocusing, never on each text update.
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(self)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        super.mouseDown(with: event)
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
