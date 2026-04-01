import SwiftUI
import AppKit

// MARK: - Square Slider (minimal knob)
final class TrackingSlider: NSSlider {
    var onEditingChanged: ((Bool) -> Void)?
    
    override func mouseDown(with event: NSEvent) {
        onEditingChanged?(true)
        super.mouseDown(with: event)
        onEditingChanged?(false)
    }
}

final class SquareSliderCell: NSSliderCell {
    var knobSize: CGFloat = 6
    var knobColor: NSColor = .appHighlight
    var trackColor: NSColor = .appDivider
    var trackHeight: CGFloat = 2
    
    override func barRect(flipped: Bool) -> NSRect {
        guard let controlView = controlView else {
            let base = super.barRect(flipped: flipped)
            let height = trackHeight
            return NSRect(x: base.minX, y: base.midY - height / 2, width: base.width, height: height)
        }
        let bounds = controlView.bounds
        let height = trackHeight
        return NSRect(x: bounds.minX, y: bounds.midY - height / 2, width: bounds.width, height: height)
    }
    
    override func knobRect(flipped: Bool) -> NSRect {
        guard let controlView = controlView else {
            let base = super.knobRect(flipped: flipped)
            let bar = barRect(flipped: flipped)
            let size = knobSize
            return NSRect(
                x: base.midX - size / 2,
                y: bar.midY - size / 2,
                width: size,
                height: size
            )
        }
        let bounds = controlView.bounds
        let size = knobSize
        let minValue = minValue
        let maxValue = maxValue
        let ratio = maxValue > minValue ? (doubleValue - minValue) / (maxValue - minValue) : 0
        let x = bounds.minX + CGFloat(ratio) * (bounds.width - size)
        let y = bounds.midY - size / 2
        return NSRect(x: x, y: y, width: size, height: size)
    }
    
    override func drawKnob(_ knobRect: NSRect) {
        let rect = knobRect
        knobColor.setFill()
        rect.fill()
    }
    
    override func drawBar(inside rect: NSRect, flipped: Bool) {
        let bar = barRect(flipped: flipped)
        trackColor.setFill()
        bar.fill()
    }
}

struct SquareSlider: NSViewRepresentable {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var onEditingChanged: ((Bool) -> Void)? = nil
    var knobSize: CGFloat = 6
    
    func makeNSView(context: Context) -> TrackingSlider {
        let slider = TrackingSlider()
        let cell = SquareSliderCell()
        cell.knobSize = knobSize
        cell.knobColor = .appHighlight
        cell.trackColor = .appDivider
        cell.trackHeight = 2
        slider.cell = cell
        slider.minValue = range.lowerBound
        slider.maxValue = range.upperBound
        slider.doubleValue = value
        slider.isContinuous = true
        slider.target = context.coordinator
        slider.action = #selector(Coordinator.valueChanged(_:))
        slider.onEditingChanged = onEditingChanged
        slider.controlSize = .mini
        slider.focusRingType = .none
        return slider
    }
    
    func updateNSView(_ nsView: TrackingSlider, context: Context) {
        if nsView.minValue != range.lowerBound {
            nsView.minValue = range.lowerBound
        }
        if nsView.maxValue != range.upperBound {
            nsView.maxValue = range.upperBound
        }
        if nsView.doubleValue != value {
            nsView.doubleValue = value
        }
        nsView.onEditingChanged = onEditingChanged
        if let cell = nsView.cell as? SquareSliderCell {
            cell.knobSize = knobSize
            cell.trackColor = .appDivider
            cell.trackHeight = 2
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value)
    }
    
    final class Coordinator: NSObject {
        private var value: Binding<Double>
        
        init(value: Binding<Double>) {
            self.value = value
        }
        
        @objc func valueChanged(_ sender: NSSlider) {
            value.wrappedValue = sender.doubleValue
        }
    }
}
