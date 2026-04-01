import SwiftUI
import AppKit

// MARK: - Popover Window Accessor (remove corner radius)
struct PopoverWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { self.apply(to: view) }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { self.apply(to: nsView) }
    }
    
    private func apply(to view: NSView) {
        guard let window = view.window else { return }
        window.hasShadow = false
        window.isOpaque = true
        window.backgroundColor = .appSecondary
        if let contentView = window.contentView {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = 0
            contentView.layer?.masksToBounds = true
        }
    }
}

// MARK: - Scroll Event Handler
struct ScrollableView<Content: View>: NSViewRepresentable {
    let content: Content
    var onVerticalScroll: ((CGFloat) -> Void)?
    var onHorizontalScroll: ((CGFloat) -> Void)?
    
    init(@ViewBuilder content: () -> Content,
         onVerticalScroll: ((CGFloat) -> Void)? = nil,
         onHorizontalScroll: ((CGFloat) -> Void)? = nil) {
        self.content = content()
        self.onVerticalScroll = onVerticalScroll
        self.onHorizontalScroll = onHorizontalScroll
    }
    
    func makeNSView(context: Context) -> NSHostingView<Content> {
        let hostingView = ScrollableHostingView(rootView: content)
        hostingView.onVerticalScroll = onVerticalScroll
        hostingView.onHorizontalScroll = onHorizontalScroll
        return hostingView
    }
    
    func updateNSView(_ nsView: NSHostingView<Content>, context: Context) {
        nsView.rootView = content
        if let scrollable = nsView as? ScrollableHostingView<Content> {
            scrollable.onVerticalScroll = onVerticalScroll
            scrollable.onHorizontalScroll = onHorizontalScroll
        }
    }
}

class ScrollableHostingView<Content: View>: NSHostingView<Content> {
    var onVerticalScroll: ((CGFloat) -> Void)?
    var onHorizontalScroll: ((CGFloat) -> Void)?
    
    override func scrollWheel(with event: NSEvent) {
        if abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) {
            onVerticalScroll?(event.scrollingDeltaY)
        } else if abs(event.scrollingDeltaX) > 0 {
            onHorizontalScroll?(event.scrollingDeltaX)
        }
    }
}
