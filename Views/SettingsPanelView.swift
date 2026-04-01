import SwiftUI
import AppKit

// MARK: - Settings Panel View
struct SettingsPanelView: View {
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
                    Text("v0.3.0 (2026.04.01)")
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

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.appTextSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 2)
    }
}

struct SettingsRow<Content: View>: View {
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

final class InfoPanelController: NSObject, NSWindowDelegate {
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

struct InfoPanelButton: NSViewRepresentable {
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
