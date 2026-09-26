import SwiftUI
import AppKit
import UniformTypeIdentifiers

private enum TagEditorField: Hashable {
    case title
    case artist
    case album
    case genre
    case year
    case trackNumber
    case discNumber
}

struct SongInfoPanelView: View {
    let song: Song
    let artwork: NSImage?
    let startEditing: Bool
    let onClose: () -> Void
    let onShowInFinder: () -> Void
    let onSaveTags: (SongTagDraft) async -> String?

    @State private var isEditing: Bool
    @State private var isSaving = false
    @State private var draft: SongTagDraft
    @State private var draftArtwork: NSImage?
    @State private var editError: String?
    @State private var focusedField: TagEditorField?

    init(
        song: Song,
        artwork: NSImage?,
        startEditing: Bool = false,
        onClose: @escaping () -> Void,
        onShowInFinder: @escaping () -> Void,
        onSaveTags: @escaping (SongTagDraft) async -> String?
    ) {
        self.song = song
        self.artwork = artwork
        self.startEditing = startEditing
        self.onClose = onClose
        self.onShowInFinder = onShowInFinder
        self.onSaveTags = onSaveTags
        _isEditing = State(initialValue: startEditing)
        _draft = State(initialValue: SongTagDraft(song: song))
        _draftArtwork = State(initialValue: artwork)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider().overlay(Color.appDivider)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if isEditing {
                        editForm
                    } else {
                        section(title: L10n.t(.songInfoMetadata), rows: metadataRows)
                        section(title: L10n.t(.songInfoTechnical), rows: technicalRows)
                        section(title: L10n.t(.songInfoFile), rows: fileRows)
                    }
                }
                .padding(10)
            }
            .frame(maxHeight: 300)

            Divider().overlay(Color.appDivider)

            HStack(spacing: 8) {
                Button(action: onShowInFinder) {
                    Label(L10n.t(.showInFinder), systemImage: "folder")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.appHighlightText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.appSecondary)
                        .border(Color.appDivider, width: 1)
                }
                .buttonStyle(.plain)
                .focusable(false)

                Spacer()

                if isEditing {
                    Button(action: cancelEditing) {
                        Text(L10n.t(.cancel))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.appHighlightText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.appSecondary)
                            .border(Color.appDivider, width: 1)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .disabled(isSaving)

                    Button(action: saveEditing) {
                        Text(isSaving ? L10n.t(.saving) : L10n.t(.save))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.appHighlightText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isSaving ? Color.appAccent : Color.appHighlight)
                            .border(Color.appDivider, width: 1)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .disabled(isSaving)
                } else {
                    Button(action: beginEditing) {
                        Text(L10n.t(.editTags))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.appHighlightText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.appSecondary)
                            .border(Color.appDivider, width: 1)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)

                    Button(action: onClose) {
                        Text(L10n.t(.ok))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.appHighlightText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.appHighlight)
                            .border(Color.appDivider, width: 1)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }
            }
            .padding(10)
            .background(Color.appBackground.opacity(0.4))
        }
        .frame(width: 300)
        .background(Color.appSecondary.opacity(0.98))
        .border(Color.appDivider, width: 1)
        .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
        .onChange(of: song) { _, newValue in
            guard !isEditing else { return }
            draft = SongTagDraft(song: newValue)
            draftArtwork = artwork
        }
        .onAppear {
            focusFirstFieldIfNeeded()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            artworkPreview(image: isEditing ? draftArtwork : artwork, size: 58, iconSize: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t(.songInfoTitle).uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.1)
                    .foregroundColor(.appTextSecondary)

                Text(song.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.appTextPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(song.artist.isEmpty ? L10n.t(.unknownArtist) : song.artist)
                    .font(.system(size: 10))
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.appTextSecondary)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .accessibilityLabel(L10n.t(.cancel))
        }
        .padding(10)
        .background(Color.appBackground.opacity(0.35))
    }

    private var metadataRows: [SongInfoRowData] {
        [
            SongInfoRowData(label: L10n.t(.songInfoArtist), value: displayValue(song.artist)),
            SongInfoRowData(label: L10n.t(.songInfoAlbum), value: displayValue(song.album)),
            SongInfoRowData(label: L10n.t(.songInfoGenre), value: displayValue(song.genre)),
            SongInfoRowData(label: L10n.t(.songInfoYear), value: displayValue(song.year)),
            SongInfoRowData(label: L10n.t(.songInfoTrackNumber), value: displayValue(song.trackNumber)),
            SongInfoRowData(label: L10n.t(.songInfoDiscNumber), value: displayValue(song.discNumber)),
            SongInfoRowData(label: L10n.t(.songInfoDuration), value: formatDuration(song.duration))
        ]
    }

    private var editForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t(.tagEditorTitle).uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.9)
                .foregroundColor(.appTextSecondary)

            artworkEditor

            editField(label: L10n.t(.songInfoTrackTitle), text: $draft.title, field: .title)
            editField(label: L10n.t(.songInfoArtist), text: $draft.artist, field: .artist)
            editField(label: L10n.t(.songInfoAlbum), text: $draft.album, field: .album)
            editField(label: L10n.t(.songInfoGenre), text: $draft.genre, field: .genre)
            editField(label: L10n.t(.songInfoYear), text: $draft.year, field: .year)
            editField(label: L10n.t(.songInfoTrackNumber), text: $draft.trackNumber, field: .trackNumber)
            editField(label: L10n.t(.songInfoDiscNumber), text: $draft.discNumber, field: .discNumber)

            if let editError {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.appHighlight)
                    Text(editError)
                        .font(.system(size: 10))
                        .foregroundColor(.appTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
                .background(Color.appBackground.opacity(0.35))
                .border(Color.appDivider, width: 1)
            }
        }
    }

    private var artworkEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.t(.songInfoArtwork))
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.appTextSecondary)

            HStack(alignment: .top, spacing: 8) {
                artworkPreview(image: draftArtwork, size: 52, iconSize: 16)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        artworkButton(
                            title: L10n.t(.chooseArtwork),
                            systemImage: "photo",
                            action: selectArtwork
                        )

                        artworkButton(
                            title: L10n.t(.removeArtwork),
                            systemImage: "trash",
                            action: removeArtwork
                        )
                        .disabled(isSaving || (draftArtwork == nil && !draft.artworkChange.shouldRewriteArtwork))
                    }

                    if draft.artworkChange.shouldRewriteArtwork {
                        artworkButton(
                            title: L10n.t(.resetArtwork),
                            systemImage: "arrow.uturn.backward",
                            action: resetArtwork
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
            .background(Color.appBackground.opacity(0.35))
            .border(Color.appDivider, width: 1)
        }
    }

    private func artworkPreview(image: NSImage?, size: CGFloat, iconSize: CGFloat) -> some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Rectangle()
                        .fill(Color.appBackground)
                    Image(systemName: "music.note")
                        .font(.system(size: iconSize))
                        .foregroundColor(.appHighlight)
                }
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .border(Color.appDivider, width: 1)
    }

    private func artworkButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.appHighlightText)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(Color.appSecondary)
                .border(Color.appDivider, width: 1)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(isSaving)
    }

    private func editField(label: String, text: Binding<String>, field: TagEditorField) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.appTextSecondary)

            TagEditorTextField(
                placeholder: label,
                text: text,
                focusedField: $focusedField,
                field: field,
                isDisabled: isSaving,
                onSubmit: {
                    focusNextField(after: field)
                }
            )
            .frame(height: 14)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.appBackground.opacity(0.35))
                .border(Color.appDivider, width: 1)
        }
    }

    private var technicalRows: [SongInfoRowData] {
        [
            SongInfoRowData(label: L10n.t(.songInfoFormat), value: displayValue(song.formatName)),
            SongInfoRowData(label: L10n.t(.songInfoBitRate), value: formatBitRate(song.bitRate)),
            SongInfoRowData(label: L10n.t(.songInfoSampleRate), value: formatSampleRate(song.sampleRate)),
            SongInfoRowData(label: L10n.t(.songInfoChannels), value: formatChannels(song.channelCount))
        ]
    }

    private var fileRows: [SongInfoRowData] {
        [
            SongInfoRowData(label: L10n.t(.songInfoFileName), value: song.url.lastPathComponent),
            SongInfoRowData(label: L10n.t(.songInfoFileSize), value: formatFileSize(song.fileSize)),
            SongInfoRowData(label: L10n.t(.songInfoModified), value: formatDate(song.modificationDate)),
            SongInfoRowData(label: L10n.t(.songInfoFilePath), value: song.url.path, isMonospaced: true)
        ]
    }

    private func section(title: String, rows: [SongInfoRowData]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.9)
                .foregroundColor(.appTextSecondary)

            VStack(spacing: 0) {
                ForEach(rows) { row in
                    SongInfoRow(row: row)
                    if row.id != rows.last?.id {
                        Divider().overlay(Color.appDivider.opacity(0.7))
                    }
                }
            }
            .border(Color.appDivider, width: 1)
        }
    }

    private func displayValue(_ value: String?) -> String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return L10n.t(.unknownValue)
        }
        return value
    }

    private func formatDuration(_ time: TimeInterval) -> String {
        guard time > 0 else { return L10n.t(.unknownValue) }
        let seconds = Int(time)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    private func formatFileSize(_ size: Int64?) -> String {
        guard let size, size > 0 else { return L10n.t(.unknownValue) }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return L10n.t(.unknownValue) }
        return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
    }

    private func formatBitRate(_ bitRate: Int?) -> String {
        guard let bitRate, bitRate > 0 else { return L10n.t(.unknownValue) }
        return "\(max(1, Int(round(Double(bitRate) / 1000)))) kbps"
    }

    private func formatSampleRate(_ sampleRate: Double?) -> String {
        guard let sampleRate, sampleRate > 0 else { return L10n.t(.unknownValue) }
        return String(format: "%.1f kHz", sampleRate / 1000)
    }

    private func formatChannels(_ channelCount: Int?) -> String {
        guard let channelCount, channelCount > 0 else { return L10n.t(.unknownValue) }
        return "\(channelCount)"
    }

    private func beginEditing() {
        draft = SongTagDraft(song: song)
        draftArtwork = artwork
        editError = nil
        isEditing = true
        focusFirstFieldIfNeeded()
    }

    private func cancelEditing() {
        draft = SongTagDraft(song: song)
        draftArtwork = artwork
        editError = nil
        focusedField = nil
        isEditing = false
    }

    private func selectArtwork() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        var allowedTypes: [UTType] = [.jpeg, .png, .tiff]
        if let heicType = UTType(filenameExtension: "heic") {
            allowedTypes.append(heicType)
        }
        panel.allowedContentTypes = allowedTypes

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let payload = try artworkPayload(from: url)
            guard let image = NSImage(data: payload.data) else {
                editError = L10n.t(.tagEditorUnsupportedArtwork)
                return
            }
            draft.artworkChange = .replace(payload)
            draftArtwork = image
            editError = nil
        } catch {
            editError = error.localizedDescription
        }
    }

    private func removeArtwork() {
        draft.artworkChange = .remove
        draftArtwork = nil
        editError = nil
    }

    private func resetArtwork() {
        draft.artworkChange = .keep
        draftArtwork = artwork
        editError = nil
    }

    private func saveEditing() {
        guard !isSaving else { return }
        isSaving = true
        focusedField = nil
        editError = nil
        let currentDraft = draft
        Task {
            let error = await onSaveTags(currentDraft)
            await MainActor.run {
                isSaving = false
                if let error {
                    editError = error
                } else {
                    var savedDraft = currentDraft
                    savedDraft.artworkChange = .keep
                    isEditing = false
                    draft = savedDraft
                    focusedField = nil
                }
            }
        }
    }

    private func focusFirstFieldIfNeeded() {
        guard isEditing else { return }
        DispatchQueue.main.async {
            focusedField = .title
        }
    }

    private func focusNextField(after field: TagEditorField) {
        switch field {
        case .title:
            focusedField = .artist
        case .artist:
            focusedField = .album
        case .album:
            focusedField = .genre
        case .genre:
            focusedField = .year
        case .year:
            focusedField = .trackNumber
        case .trackNumber:
            focusedField = .discNumber
        case .discNumber:
            focusedField = nil
        }
    }

    private func artworkPayload(from url: URL) throws -> SongArtworkPayload {
        let data = try Data(contentsOf: url)
        guard NSImage(data: data) != nil else {
            throw SongInfoPanelError.unsupportedArtwork
        }

        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg":
            return SongArtworkPayload(data: data, mimeType: "image/jpeg")
        case "png":
            return SongArtworkPayload(data: data, mimeType: "image/png")
        default:
            guard let image = NSImage(data: data),
                  let jpegData = image.jpegData(compression: 0.88) else {
                throw SongInfoPanelError.unsupportedArtwork
            }
            return SongArtworkPayload(data: jpegData, mimeType: "image/jpeg")
        }
    }
}

final class SongInfoPanelController: NSObject, NSWindowDelegate {
    static let shared = SongInfoPanelController()

    private var panel: SongInfoPanelWindow?
    private var hostingView: NSHostingView<SongInfoPanelHostView>?
    private var keyMonitor: Any?

    static func close() {
        shared.close()
    }

    func show(song: Song, startEditing: Bool) {
        AudioPlayerViewModel.shared.prepareSongInfo(for: song)

        let rootView = SongInfoPanelHostView(
            viewModel: AudioPlayerViewModel.shared,
            initialSong: song,
            startEditing: startEditing,
            identity: UUID()
        )

        let panel = self.panel ?? makePanel()
        if let hostingView {
            hostingView.rootView = rootView
        } else {
            let hostingView = NSHostingView(rootView: rootView)
            hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: 440)
            hostingView.autoresizingMask = [.width, .height]
            hostingView.wantsLayer = true
            hostingView.layer?.cornerRadius = 0
            hostingView.layer?.masksToBounds = true
            panel.contentView = hostingView
            self.hostingView = hostingView
        }

        position(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panel = panel
        startKeyMonitor()
    }

    private func makePanel() -> SongInfoPanelWindow {
        let panel = SongInfoPanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 440),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.delegate = self
        return panel
    }

    private func position(_ panel: NSPanel) {
        let panelSize = panel.frame.size
        guard let anchorWindow = anchorWindow() else {
            panel.center()
            return
        }

        let anchorFrame = anchorWindow.frame
        let visibleFrame = anchorWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? anchorFrame
        let margin: CGFloat = 12
        var x = anchorFrame.maxX + margin
        if x + panelSize.width > visibleFrame.maxX {
            x = anchorFrame.minX - panelSize.width - margin
        }
        if x < visibleFrame.minX {
            x = min(max(visibleFrame.minX, anchorFrame.midX - panelSize.width / 2), visibleFrame.maxX - panelSize.width)
        }

        var y = anchorFrame.midY - panelSize.height / 2
        y = min(max(y, visibleFrame.minY), visibleFrame.maxY - panelSize.height)

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func anchorWindow() -> NSWindow? {
        if let playlistWindow = WindowManager.shared.playlistWindow, playlistWindow.isVisible {
            return playlistWindow
        }
        if let playerWindow = WindowManager.shared.playerWindow, playerWindow.isVisible {
            return playerWindow
        }
        return NSApp.keyWindow
    }

    private func close() {
        panel?.orderOut(nil)
        stopKeyMonitor()
    }

    func windowWillClose(_ notification: Notification) {
        stopKeyMonitor()
    }

    private func startKeyMonitor() {
        stopKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard event.keyCode == 53, event.window === self.panel else { return event }
            self.close()
            return nil
        }
    }

    private func stopKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }
}

private final class SongInfoPanelWindow: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}

private struct SongInfoPanelHostView: View {
    @ObservedObject var viewModel: AudioPlayerViewModel
    let initialSong: Song
    let startEditing: Bool
    let identity: UUID

    private var song: Song {
        let targetPath = normalizedPath(for: initialSong.url)
        return viewModel.queue.first { normalizedPath(for: $0.url) == targetPath } ?? initialSong
    }

    var body: some View {
        let currentSong = song
        SongInfoPanelView(
            song: currentSong,
            artwork: viewModel.artwork(for: currentSong),
            startEditing: startEditing,
            onClose: {
                SongInfoPanelController.close()
            },
            onShowInFinder: {
                NSWorkspace.shared.activateFileViewerSelecting([currentSong.url])
            },
            onSaveTags: { draft in
                await viewModel.saveTags(for: currentSong, draft: draft)
            }
        )
        .id(identity)
    }

    private func normalizedPath(for url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}

private enum SongInfoPanelError: LocalizedError {
    case unsupportedArtwork

    var errorDescription: String? {
        switch self {
        case .unsupportedArtwork:
            return L10n.t(.tagEditorUnsupportedArtwork)
        }
    }
}

private struct TagEditorTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    @Binding var focusedField: TagEditorField?
    let field: TagEditorField
    let isDisabled: Bool
    let onSubmit: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let textField = FocusableTagTextField()
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = .systemFont(ofSize: 10, weight: .medium)
        textField.textColor = .appTextPrimary
        textField.placeholderString = placeholder
        textField.isEditable = true
        textField.isSelectable = true
        textField.lineBreakMode = .byTruncatingTail
        textField.usesSingleLineMode = true
        textField.cell?.isScrollable = true
        return textField
    }

    func updateNSView(_ textField: NSTextField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.focusedField = $focusedField
        context.coordinator.field = field
        context.coordinator.onSubmit = onSubmit

        if textField.stringValue != text {
            textField.stringValue = text
        }

        textField.placeholderString = placeholder
        textField.isEnabled = !isDisabled
        textField.textColor = isDisabled ? .appTextSecondary : .appTextPrimary

        guard focusedField == field, !isDisabled else { return }
        DispatchQueue.main.async {
            guard let window = textField.window else { return }
            window.makeKey()
            let responder = window.firstResponder
            if responder !== textField && responder !== textField.currentEditor() {
                window.makeFirstResponder(textField)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            focusedField: $focusedField,
            field: field,
            onSubmit: onSubmit
        )
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var focusedField: Binding<TagEditorField?>
        var field: TagEditorField
        var onSubmit: () -> Void

        init(
            text: Binding<String>,
            focusedField: Binding<TagEditorField?>,
            field: TagEditorField,
            onSubmit: @escaping () -> Void
        ) {
            self.text = text
            self.focusedField = focusedField
            self.field = field
            self.onSubmit = onSubmit
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            focusedField.wrappedValue = field
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            text.wrappedValue = textField.stringValue
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            text.wrappedValue = textField.stringValue
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                text.wrappedValue = textView.string
                onSubmit()
                return true
            }
            return false
        }
    }
}

private final class FocusableTagTextField: NSTextField {
    override var acceptsFirstResponder: Bool {
        true
    }

    override var needsPanelToBecomeKey: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
}

private struct SongInfoRowData: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    var isMonospaced = false
}

private struct SongInfoRow: View {
    let row: SongInfoRowData

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(row.label)
                .font(.system(size: 10))
                .foregroundColor(.appTextSecondary)
                .frame(width: 88, alignment: .leading)

            Text(row.value)
                .font(row.isMonospaced ? .system(size: 9, design: .monospaced) : .system(size: 10, weight: .medium))
                .foregroundColor(.appTextPrimary)
                .textSelection(.enabled)
                .lineLimit(row.isMonospaced ? 3 : 2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.appBackground.opacity(0.25))
    }
}

private extension NSImage {
    func jpegData(compression: CGFloat) -> Data? {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compression])
    }
}
