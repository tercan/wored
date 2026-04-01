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
                
                Button(action: {
                    InfoPanelController.close()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.appTextSecondary)
                        .frame(width: 12, height: 12)
                }
                .buttonStyle(.plain)
                .focusable(false)
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
                    .zIndex(2)
                    
                    // EQ
                    SettingsRow(icon: "slider.vertical.3", title: L10n.t(.settingsEQ)) {
                        SquarePicker(selection: $viewModel.eqPreset, items: EQPreset.allCases, displayString: { $0.displayName })
                    }
                    .zIndex(1)
                }
                .zIndex(3)
                
                // Interface Section
                VStack(spacing: 8) {
                    SectionHeader(title: L10n.t(.settingsUI))
                    
                    SettingsRow(icon: "uiwindow.split.2x1", title: L10n.t(.settingsAlwaysOnTop)) {
                        Toggle("", isOn: $viewModel.alwaysOnTop)
                            .toggleStyle(SquareToggleStyle())
                            .labelsHidden()
                    }
                    .zIndex(2)
                    
                    SettingsRow(icon: "paintpalette", title: L10n.t(.settingsTheme)) {
                        SquarePicker(selection: $viewModel.appTheme, items: AppTheme.allCases, displayString: { $0.displayName })
                    }
                    .zIndex(1)
                }
                .zIndex(2)
                
                // System Section
                VStack(spacing: 8) {
                    SectionHeader(title: L10n.t(.settingsSystem))
                    
                    SettingsRow(icon: "power", title: L10n.t(.settingsLaunchAtStartup)) {
                        Toggle("", isOn: $viewModel.launchAtStartup)
                            .toggleStyle(SquareToggleStyle())
                            .labelsHidden()
                    }
                    .zIndex(2)
                    
                    SettingsRow(icon: "globe", title: L10n.t(.settingsLanguage)) {
                        SquarePicker(selection: $viewModel.appLanguage, items: AppLanguage.allCases, displayString: { $0.displayName })
                    }
                    .zIndex(1)
                }
                .zIndex(1)
                
                Divider().overlay(Color.appDivider.opacity(0.5))
                
                // Footer Info
                HStack {
                    Text("v0.5.0 (2026.04.02)")
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
    
    static func close() {
        shared.panel?.orderOut(nil)
        shared.stopKeyMonitor()
        shared.stopClickMonitor()
    }
    
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
        button.image?.size = NSSize(width: 8, height: 8)
        button.contentTintColor = .appHighlight
        button.target = context.coordinator
        button.action = #selector(Coordinator.clicked(_:))
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        button.frame = NSRect(x: 0, y: 0, width: 12, height: 12)
        button.imageScaling = .scaleProportionallyDown
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 12),
            button.heightAnchor.constraint(equalToConstant: 12)
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

// MARK: - Square Picker
struct SquarePicker<T: Hashable & Equatable>: View {
    @Binding var selection: T
    let items: [T]
    let displayString: (T) -> String
    @State private var isOpen = false
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isOpen.toggle()
            }
        }) {
            HStack {
                Text(displayString(selection))
                    .font(.system(size: 11))
                    .foregroundColor(.appTextPrimary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9))
                    .foregroundColor(.appTextSecondary)
            }
            .padding(.horizontal, 6)
            .frame(height: 18)
            .background(Color.appBackground)
            .border(Color.appDivider, width: 1)
        }
        .buttonStyle(.plain)
        .overlay(
            Group {
                if isOpen {
                    VStack(spacing: 0) {
                        ForEach(items, id: \.self) { item in
                            Button(action: {
                                selection = item
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    isOpen = false
                                }
                            }) {
                                HStack {
                                    Text(displayString(item))
                                        .font(.system(size: 11))
                                        .foregroundColor(selection == item ? .appHighlightText : .appTextPrimary)
                                        .padding(.leading, 6)
                                    Spacer()
                                    if selection == item {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.appHighlight)
                                            .padding(.trailing, 6)
                                    }
                                }
                                .frame(height: 20)
                                .background(selection == item ? Color.appSecondary : Color.appBackground)
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            // Provide hover effect
                            .onHover { isHover in
                                if isHover && selection != item {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                        }
                    }
                    .background(Color.appBackground)
                    .border(Color.appDivider, width: 1)
                    .offset(y: 19)
                }
            },
            alignment: .top
        )
        .frame(width: 100)
    }
}

// MARK: - Square Toggle Style
struct SquareToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            Rectangle()
                .fill(configuration.isOn ? Color.appHighlight : Color.appBackground)
                .border(Color.appDivider, width: 1)
                .frame(width: 32, height: 16)
                .overlay(
                    Rectangle()
                        .fill(configuration.isOn ? Color.appBackground : Color.appTextSecondary)
                        .frame(width: 14, height: 14)
                        .padding(1),
                    alignment: configuration.isOn ? .trailing : .leading
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        configuration.isOn.toggle()
                    }
                }
        }
    }
}
