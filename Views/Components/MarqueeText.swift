import SwiftUI

// MARK: - Marquee Text
struct MarqueeWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color
    let speed: Double
    let delay: Double
    let spacing: CGFloat
    var isScrollingEnabled = true
    var lineHeight: CGFloat = 14
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var textWidth: CGFloat = 0
    @State private var animate = false
    
    var body: some View {
        GeometryReader { geo in
            let containerWidth = geo.size.width
            ZStack(alignment: .leading) {
                // Always measure text width, even when not scrolling.
                marqueeText(measure: true)
                    .opacity(0)
                if !isScrollingEnabled || reduceMotion || textWidth <= containerWidth || containerWidth <= 0 {
                    Text(text)
                        .font(font)
                        .foregroundColor(color)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    HStack(spacing: spacing) {
                        marqueeText(measure: true)
                        marqueeText(measure: false)
                    }
                    .offset(x: animate ? -(textWidth + spacing) : 0)
                    .animation(
                        .linear(duration: max((textWidth + spacing) / speed, 2))
                            .delay(delay)
                            .repeatForever(autoreverses: false),
                        value: animate
                    )
                    .onAppear { restartAnimation() }
                    .onChange(of: textWidth) { _, _ in restartAnimation() }
                    .onChange(of: containerWidth) { _, _ in restartAnimation() }
                    .onChange(of: text) { _, _ in restartAnimation() }
                }
            }
            .frame(width: containerWidth, height: geo.size.height, alignment: .leading)
            .clipped()
            .onPreferenceChange(MarqueeWidthPreferenceKey.self) { width in
                if abs(textWidth - width) > 0.5 {
                    textWidth = width
                }
            }
        }
        .frame(height: lineHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
    
    private func marqueeText(measure: Bool) -> some View {
        Text(text)
            .font(font)
            .foregroundColor(color)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: MarqueeWidthPreferenceKey.self,
                        value: measure ? proxy.size.width : 0
                    )
                }
            )
    }
    
    private func restartAnimation() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            animate = false
        }
        DispatchQueue.main.async {
            animate = true
        }
    }
}
