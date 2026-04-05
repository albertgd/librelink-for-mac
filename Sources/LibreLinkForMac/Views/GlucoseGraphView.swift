import SwiftUI

struct GlucoseGraphView: View {
    let entries: [GlucoseEntry]
    let lowThreshold: Double
    let highThreshold: Double
    let useMmol: Bool

    private var displayEntries: [GlucoseEntry] {
        entries.suffix(48) // ~4 hours of data at 5-min intervals
    }

    private var minValue: Double {
        max(40, (displayEntries.map(\.value).min() ?? 40) - 10)
    }

    private var maxValue: Double {
        min(400, (displayEntries.map(\.value).max() ?? 400) + 10)
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            ZStack {
                // Background zones
                thresholdZones(width: width, height: height)

                // Threshold lines
                thresholdLines(width: width, height: height)

                // Glucose line
                if displayEntries.count > 1 {
                    Path { path in
                        for (index, entry) in displayEntries.enumerated() {
                            let x = CGFloat(index) / CGFloat(displayEntries.count - 1) * width
                            let y = yPosition(for: entry.value, height: height)
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.white, lineWidth: 2)

                    // Data points
                    ForEach(Array(displayEntries.enumerated()), id: \.element.id) { index, entry in
                        let x = CGFloat(index) / CGFloat(displayEntries.count - 1) * width
                        let y = yPosition(for: entry.value, height: height)
                        Circle()
                            .fill(dotColor(for: entry.value))
                            .frame(width: 5, height: 5)
                            .position(x: x, y: y)
                    }
                }

                // Y-axis labels
                VStack {
                    Text(formatValue(maxValue))
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Text(formatValue(minValue))
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 2)
            }
        }
    }

    private func yPosition(for value: Double, height: CGFloat) -> CGFloat {
        let range = maxValue - minValue
        guard range > 0 else { return height / 2 }
        return height - CGFloat((value - minValue) / range) * height
    }

    private func thresholdZones(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // High zone
            let highY = yPosition(for: highThreshold, height: height)
            Rectangle()
                .fill(Color.orange.opacity(0.1))
                .frame(width: width, height: max(0, highY))
                .position(x: width / 2, y: highY / 2)

            // Low zone
            let lowY = yPosition(for: lowThreshold, height: height)
            Rectangle()
                .fill(Color.red.opacity(0.1))
                .frame(width: width, height: max(0, height - lowY))
                .position(x: width / 2, y: (height + lowY) / 2)
        }
    }

    private func thresholdLines(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // High threshold
            Path { path in
                let y = yPosition(for: highThreshold, height: height)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
            }
            .stroke(Color.orange.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4]))

            // Low threshold
            Path { path in
                let y = yPosition(for: lowThreshold, height: height)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
            }
            .stroke(Color.red.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4]))
        }
    }

    private func dotColor(for value: Double) -> Color {
        switch GlucoseRange.from(value: value) {
        case .low: return .red
        case .normal: return .green
        case .high: return .orange
        }
    }

    private func formatValue(_ value: Double) -> String {
        if useMmol {
            return String(format: "%.1f", value / 18.0)
        }
        return "\(Int(value))"
    }
}
