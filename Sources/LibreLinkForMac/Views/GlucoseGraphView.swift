import SwiftUI

struct GlucoseGraphView: View {
    let entries: [GlucoseEntry]
    let lowThreshold: Double
    let highThreshold: Double
    let useMmol: Bool

    private let yLabelWidth: CGFloat = 34
    private let xLabelHeight: CGFloat = 16
    private let yStep: Double = 50  // mg/dL step for Y-axis grid

    private var displayEntries: [GlucoseEntry] {
        entries.suffix(48)
    }

    private var minValue: Double {
        let raw = max(40, (displayEntries.map(\.value).min() ?? 40) - 10)
        return floor(raw / yStep) * yStep
    }

    private var maxValue: Double {
        let raw = min(400, (displayEntries.map(\.value).max() ?? 400) + 10)
        return ceil(raw / yStep) * yStep
    }

    private var yLevels: [Double] {
        var levels: [Double] = []
        var v = minValue
        while v <= maxValue {
            levels.append(v)
            v += yStep
        }
        return levels
    }

    var body: some View {
        GeometryReader { geo in
            let graphWidth = geo.size.width - yLabelWidth
            let graphHeight = geo.size.height - xLabelHeight

            ZStack(alignment: .topLeading) {
                // Graph area (shifted right by yLabelWidth)
                ZStack {
                    thresholdZones(width: graphWidth, height: graphHeight)
                    yGridLines(width: graphWidth, height: graphHeight)
                    thresholdLines(width: graphWidth, height: graphHeight)

                    if displayEntries.count > 1 {
                        Path { path in
                            for (index, entry) in displayEntries.enumerated() {
                                let x = xPos(index: index, total: displayEntries.count, width: graphWidth)
                                let y = yPos(for: entry.value, height: graphHeight)
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(Color.white, lineWidth: 2)

                        ForEach(Array(displayEntries.enumerated()), id: \.element.id) { index, entry in
                            let x = xPos(index: index, total: displayEntries.count, width: graphWidth)
                            let y = yPos(for: entry.value, height: graphHeight)
                            Circle()
                                .fill(dotColor(for: entry.value))
                                .frame(width: 5, height: 5)
                                .position(x: x, y: y)
                        }
                    }
                }
                .frame(width: graphWidth, height: graphHeight)
                .offset(x: yLabelWidth, y: 0)

                // Y-axis labels
                ForEach(yLevels, id: \.self) { level in
                    let y = yPos(for: level, height: graphHeight)
                    Text(formatValue(level))
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.45))
                        .frame(width: yLabelWidth - 4, alignment: .trailing)
                        .position(x: (yLabelWidth - 4) / 2, y: y)
                }

                // X-axis time labels
                if displayEntries.count > 1 {
                    ForEach(xTimeTicks(), id: \.index) { tick in
                        let x = xPos(index: tick.index, total: displayEntries.count, width: graphWidth) + yLabelWidth
                        Text(tick.label)
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.45))
                            .position(x: x, y: graphHeight + xLabelHeight / 2)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func xPos(index: Int, total: Int, width: CGFloat) -> CGFloat {
        guard total > 1 else { return 0 }
        return CGFloat(index) / CGFloat(total - 1) * width
    }

    private func yPos(for value: Double, height: CGFloat) -> CGFloat {
        let range = maxValue - minValue
        guard range > 0 else { return height / 2 }
        return height - CGFloat((value - minValue) / range) * height
    }

    private func thresholdZones(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            let highY = yPos(for: highThreshold, height: height)
            Rectangle()
                .fill(Color.orange.opacity(0.1))
                .frame(width: width, height: max(0, highY))
                .position(x: width / 2, y: highY / 2)

            let lowY = yPos(for: lowThreshold, height: height)
            Rectangle()
                .fill(Color.red.opacity(0.1))
                .frame(width: width, height: max(0, height - lowY))
                .position(x: width / 2, y: (height + lowY) / 2)
        }
    }

    private func yGridLines(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            ForEach(yLevels, id: \.self) { level in
                Path { path in
                    let y = yPos(for: level, height: height)
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
                .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            }
        }
    }

    private func thresholdLines(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Path { path in
                let y = yPos(for: highThreshold, height: height)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
            }
            .stroke(Color.orange.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4]))

            Path { path in
                let y = yPos(for: lowThreshold, height: height)
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

    // MARK: - X-axis time ticks at 30-min boundaries

    private struct XTick {
        let index: Int
        let label: String
    }

    private func xTimeTicks() -> [XTick] {
        let indexed = displayEntries.enumerated().compactMap { (i, e) -> (Int, Date)? in
            guard let d = e.timestamp else { return nil }
            return (i, d)
        }
        guard let firstDate = indexed.first?.1, let lastDate = indexed.last?.1 else { return [] }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let cal = Calendar.current

        // Snap to first 30-min boundary after firstDate
        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: firstDate)
        let minute = comps.minute ?? 0
        comps.minute = minute < 30 ? 30 : 0
        comps.second = 0
        if minute >= 30 {
            comps.hour = (comps.hour ?? 0) + 1
        }
        guard var boundary = cal.date(from: comps) else { return [] }

        var ticks: [XTick] = []
        var seen = Set<Int>()  // avoid duplicate entries

        while boundary <= lastDate {
            // Find the entry closest to this boundary
            if let closest = indexed.min(by: { abs($0.1.timeIntervalSince(boundary)) < abs($1.1.timeIntervalSince(boundary)) }),
               abs(closest.1.timeIntervalSince(boundary)) < 10 * 60,  // within 10 min
               !seen.contains(closest.0) {
                ticks.append(XTick(index: closest.0, label: formatter.string(from: boundary)))
                seen.insert(closest.0)
            }
            boundary = cal.date(byAdding: .minute, value: 30, to: boundary) ?? boundary.addingTimeInterval(1800)
        }

        return ticks
    }
}
