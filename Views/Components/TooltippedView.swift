import SwiftUI
import AppKit

// MARK: - Tooltip Wrapper (reliable even when disabled)
final class TooltipHostingView: NSView {
    var hostingView: NSHostingView<AnyView>?
}

struct TooltippedView<Content: View>: NSViewRepresentable {
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
