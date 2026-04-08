import SwiftUI

struct GlucoseGraphView: View {
    let entries: [GlucoseEntry]
    let lowThreshold: Double
    let highThreshold: Double
    let useMmol: Bool

    private let yLabelWidth: CGFloat = 40
    private let xLabelHeight: CGFloat = 18
    private let yStep: Double = 50  // mg/dL per grid line

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
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Y-axis labels column
                GeometryReader { yGeo in
                    ZStack {
                        ForEach(yLevels, id: \.self) { level in
                            Text(formatValue(level))
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.5))
                                .position(
                                    x: yGeo.size.width / 2,
                                    y: yPos(for: level, height: yGeo.size.height)
                                )
                        }
                    }
                    .frame(width: yGeo.size.width, height: yGeo.size.height)
                }
                .frame(width: yLabelWidth)

                // Graph area
                GeometryReader { graphGeo in
                    let w = graphGeo.size.width
                    let h = graphGeo.size.height

                    ZStack {
                        thresholdZones(width: w, height: h)
                        yGridLines(width: w, height: h)
                        thresholdLines(width: w, height: h)

                        if displayEntries.count > 1 {
                            Path { path in
                                for (i, entry) in displayEntries.enumerated() {
                                    let x = xPos(index: i, total: displayEntries.count, width: w)
                                    let y = yPos(for: entry.value, height: h)
                                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                                }
                            }
                            .stroke(Color.white, lineWidth: 2)

                            ForEach(Array(displayEntries.enumerated()), id: \.element.id) { i, entry in
                                let x = xPos(index: i, total: displayEntries.count, width: w)
                                let y = yPos(for: entry.value, height: h)
                                Circle()
                                    .fill(dotColor(for: entry.value))
                                    .frame(width: 5, height: 5)
                                    .position(x: x, y: y)
                            }
                        }
                    }
                    .frame(width: w, height: h)
                }
            }

            // X-axis time labels row
            HStack(spacing: 0) {
                Color.clear.frame(width: yLabelWidth, height: xLabelHeight)

                GeometryReader { xGeo in
                    ZStack {
                        ForEach(xTimeTicks(width: xGeo.size.width), id: \.index) { tick in
                            Text(tick.label)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.5))
                                .position(x: tick.x, y: xLabelHeight / 2)
                        }
                    }
                    .frame(width: xGeo.size.width, height: xLabelHeight)
                }
                .frame(height: xLabelHeight)
            }
        }
    }

    // MARK: - Positioning helpers

    private func xPos(index: Int, total: Int, width: CGFloat) -> CGFloat {
        guard total > 1 else { return 0 }
        return CGFloat(index) / CGFloat(total - 1) * width
    }

    private func yPos(for value: Double, height: CGFloat) -> CGFloat {
        let range = maxValue - minValue
        guard range > 0 else { return height / 2 }
        return height - CGFloat((value - minValue) / range) * height
    }

    // MARK: - Graph layers

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

    // MARK: - Helpers

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
        let x: CGFloat
        let label: String
    }

    private func xTimeTicks(width: CGFloat) -> [XTick] {
        let indexed = displayEntries.enumerated().compactMap { (i, e) -> (Int, Date)? in
            guard let d = e.timestamp else { return nil }
            return (i, d)
        }
        guard let firstDate = indexed.first?.1, let lastDate = indexed.last?.1 else { return [] }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let cal = Calendar.current

        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: firstDate)
        let minute = comps.minute ?? 0
        comps.minute = minute < 30 ? 30 : 0
        comps.second = 0
        if minute >= 30 { comps.hour = (comps.hour ?? 0) + 1 }
        guard var boundary = cal.date(from: comps) else { return [] }

        var allTicks: [XTick] = []
        var seen = Set<Int>()

        while boundary <= lastDate {
            if let closest = indexed.min(by: { abs($0.1.timeIntervalSince(boundary)) < abs($1.1.timeIntervalSince(boundary)) }),
               abs(closest.1.timeIntervalSince(boundary)) < 15 * 60,
               !seen.contains(closest.0) {
                let x = xPos(index: closest.0, total: displayEntries.count, width: width)
                allTicks.append(XTick(index: closest.0, x: x, label: formatter.string(from: boundary)))
                seen.insert(closest.0)
            }
            boundary = cal.date(byAdding: .minute, value: 30, to: boundary) ?? boundary.addingTimeInterval(1800)
        }

        // Thin out ticks dynamically to prevent label overlap.
        // Each "HH:mm" label is ~32 px wide at size 8; require 40 px minimum between centers.
        let minSpacing: CGFloat = 50
        var step = 1
        while step <= allTicks.count {
            let thinned = stride(from: 0, to: allTicks.count, by: step).map { allTicks[$0] }
            let fits = thinned.count <= 1 ||
                zip(thinned, thinned.dropFirst()).allSatisfy { $1.x - $0.x >= minSpacing }
            if fits { return thinned }
            step *= 2
        }
        return []
    }
}
