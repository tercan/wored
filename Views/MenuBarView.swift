import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var viewModel: AudioPlayerViewModel
    let onShowPlaylist: () -> Void
    let onShowPlayer: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.currentSongTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.appTextPrimary)
                .lineLimit(1)
            
            if !viewModel.artist.isEmpty {
                Text(viewModel.artist)
                    .font(.system(size: 10))
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(1)
            }
            
            HStack(spacing: 8) {
                transportButton(icon: "backward.end.fill", label: .previousTrack, action: viewModel.previousSong)
                transportButton(icon: viewModel.isPlaying ? "pause.fill" : "play.fill", label: viewModel.isPlaying ? .pause : .play, action: viewModel.togglePlayPause)
                transportButton(icon: "forward.end.fill", label: .nextTrack, action: viewModel.nextSong)
                Spacer(minLength: 0)
            }
            
            Divider()
                .overlay(Color.appDivider)
            
            Button(action: onShowPlaylist) {
                Label(L10n.t(.playlist), systemImage: "music.note.list")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 24)
                    .contentShape(Rectangle())
            }
            Button(action: onShowPlayer) {
                Label("Wored", systemImage: "play.rectangle")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 24)
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 11))
        .foregroundColor(.appTextPrimary)
        .padding(12)
        .frame(width: 240)
        .background(Color.appBackground)
        .overlay(Rectangle().strokeBorder(Color.appDivider, lineWidth: 1).allowsHitTesting(false))
        .tint(.appControlActive)
    }

    private func transportButton(icon: String, label: L10n.Key, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.appControlDefault)
                .frame(width: 28, height: 28)
                .background(Color.appSecondary)
                .contentShape(Rectangle())
        }
        .help(L10n.t(label))
        .accessibilityLabel(L10n.t(label))
    }
}

final class MenuBarController: NSObject, NSWindowDelegate {
    static let shared = MenuBarController()
    var openWindow: ((String) -> Void)?

    private var statusItem: NSStatusItem?
    private var panel: MenuBarPanel?
    private var hostingView: NSHostingView<MenuBarPanelContent>?
    private var localMonitor: Any?
    private var globalMonitor: Any?

    func install() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let icon = NSImage(named: "WoredStatusIcon")
        icon?.size = NSSize(width: 20, height: 20)
        icon?.isTemplate = true
        item.button?.image = icon
        item.button?.title = icon == nil ? "W" : ""
        item.button?.setAccessibilityLabel("Wored")
        item.button?.toolTip = "Wored"
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        statusItem = item
    }

    @objc private func togglePanel() {
        if panel?.isVisible == true {
            close()
        } else {
            show()
        }
    }

    private func show() {
        guard let button = statusItem?.button, let statusWindow = button.window else { return }
        let panel = self.panel ?? makePanel()
        guard let hostingView else { return }
        panel.appearance = AudioPlayerViewModel.shared.appTheme.nsAppearance
        let size = hostingView.fittingSize
        panel.setContentSize(size)
        let anchor = statusWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screenFrame = (statusWindow.screen ?? NSScreen.main)?.visibleFrame ?? anchor
        let x = min(max(anchor.midX - size.width / 2, screenFrame.minX), screenFrame.maxX - size.width)
        panel.setFrameOrigin(NSPoint(x: x, y: max(screenFrame.minY, anchor.minY - size.height)))
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        startMonitors()
    }

    private func makePanel() -> MenuBarPanel {
        let panel = MenuBarPanel(contentRect: NSRect(x: 0, y: 0, width: 240, height: 190), styleMask: [.borderless], backing: .buffered, defer: false)
        panel.identifier = NSUserInterfaceItemIdentifier("wored.menuBarPanel")
        panel.isReleasedWhenClosed = false
        panel.isOpaque = true
        panel.backgroundColor = .appBackground
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = true
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.delegate = self
        let content = MenuBarPanelContent(viewModel: AudioPlayerViewModel.shared, onShowPlaylist: { [weak self] in self?.showPlaylist() }, onShowPlayer: { [weak self] in self?.showPlayer() })
        let hosting = NSHostingView(rootView: content)
        hosting.sizingOptions = []
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = 0
        hosting.layer?.masksToBounds = true
        panel.contentView = hosting
        self.hostingView = hosting
        self.panel = panel
        return panel
    }

    func close() {
        stopMonitors()
        panel?.orderOut(nil)
    }

    func showPlayer() {
        close()
        let manager = WindowManager.shared
        if manager.playerWindow == nil { openWindow?("player") }
        manager.showPlayerWindows()
    }

    private func showPlaylist() {
        showPlayer()
        let manager = WindowManager.shared
        if manager.playlistWindow != nil {
            manager.showPlaylist()
        } else {
            manager.togglePlaylist()
        }
    }

    func windowDidResignKey(_ notification: Notification) { close() }

    private func startMonitors() {
        stopMonitors()
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown {
                if event.keyCode == 53, event.window === self.panel {
                    self.close()
                    return nil
                }
            } else if event.window !== self.panel && event.window !== self.statusItem?.button?.window {
                self.close()
            }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    private func stopMonitors() {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil
        globalMonitor = nil
    }
}

private final class MenuBarPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct MenuBarPanelContent: View {
    @ObservedObject var viewModel: AudioPlayerViewModel
    let onShowPlaylist: () -> Void
    let onShowPlayer: () -> Void

    var body: some View {
        MenuBarView(viewModel: viewModel, onShowPlaylist: onShowPlaylist, onShowPlayer: onShowPlayer)
            .preferredColorScheme(viewModel.appTheme.colorScheme)
    }
}
