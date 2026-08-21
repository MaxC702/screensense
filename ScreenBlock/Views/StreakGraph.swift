import SwiftUI

/// One point per day, height by level.
///
/// Drawn by hand rather than charted, for the same reason the break ring is: the
/// y axis here is five named rungs, not a number line. A chart would want to
/// label it 0 to 4, and 0 to 4 means nothing — the rungs carry their own colours
/// and their own names, and those are the whole legend.
///
/// Days the app was not watching leave a gap. The line stops and starts again
/// rather than sloping across them, because a straight line through days the
/// app knew nothing about is a claim it cannot make.
struct StreakGraph: View {
    let points: [AppModel.DayPoint]

    /// Room for the rung names down the right-hand side.
    private let labelWidth: CGFloat = 62
    /// Room for the day names along the bottom.
    private let dayLabelHeight: CGFloat = 20
    /// Keeps the first and last points off the edges, so their dots are whole
    /// and their day names have somewhere to sit.
    private let inset: CGFloat = 15

    private static let weekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }()

    var body: some View {
        GeometryReader { geo in
            let plotWidth = max(1, geo.size.width - labelWidth)
            let plotHeight = max(1, geo.size.height - dayLabelHeight)

            ZStack(alignment: .topLeading) {
                rungs(width: plotWidth, height: plotHeight)
                area(width: plotWidth, height: plotHeight)
                line(width: plotWidth, height: plotHeight)
                dots(width: plotWidth, height: plotHeight)
                labels(plotWidth: plotWidth, height: plotHeight)
                days(width: plotWidth, plotHeight: plotHeight)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
    }

    /// One name per day along the bottom. Today is called Today rather than by
    /// its weekday — it is the point everything else is read relative to, and
    /// counting back from "Fri" to work out which end you are looking at is
    /// exactly the work a label is supposed to save.
    private func days(width: CGFloat, plotHeight: CGFloat) -> some View {
        ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
            let isToday = index == points.count - 1
            Text(isToday ? "Today" : Self.weekday.string(from: point.date))
                .font(.system(size: 9, weight: isToday ? .bold : .regular))
                .foregroundColor(isToday ? Theme.streak : Theme.faint)
                .fixedSize()
                .position(x: x(index, in: width), y: plotHeight + dayLabelHeight / 2)
        }
    }

    // MARK: - Layers

    private func rungs(width: CGFloat, height: CGFloat) -> some View {
        ForEach(StreakLevel.allCases, id: \.rawValue) { rung in
            let y = self.y(for: rung, in: height)
            Path { path in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
            }
            .stroke(rung.tint.opacity(0.18), lineWidth: 1)
        }
    }

    /// A wash under the line, so a run near the top reads as a block of colour
    /// before any of the rungs have been read.
    private func area(width: CGFloat, height: CGFloat) -> some View {
        ForEach(Array(runs().enumerated()), id: \.offset) { _, run in
            Path { path in
                guard let first = run.first else { return }
                path.move(to: CGPoint(x: x(first, in: width), y: height))
                for index in run {
                    path.addLine(to: CGPoint(x: x(index, in: width), y: y(at: index, in: height)))
                }
                if let last = run.last {
                    path.addLine(to: CGPoint(x: x(last, in: width), y: height))
                }
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [Theme.streak.opacity(0.22), Theme.streak.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    private func line(width: CGFloat, height: CGFloat) -> some View {
        ForEach(Array(runs().enumerated()), id: \.offset) { _, run in
            Path { path in
                for (offset, index) in run.enumerated() {
                    let point = CGPoint(x: x(index, in: width), y: y(at: index, in: height))
                    if offset == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
            }
            .stroke(
                Theme.streak,
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func dots(width: CGFloat, height: CGFloat) -> some View {
        ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
            if let level = point.level {
                // Today is drawn larger: "where am I now" is the first thing
                // anyone looks for on a line that ends somewhere.
                let isToday = index == points.count - 1
                Circle()
                    .fill(level.tint)
                    .frame(width: isToday ? 10 : 5, height: isToday ? 10 : 5)
                    .position(x: x(index, in: width), y: y(at: index, in: height))
            }
        }
    }

    /// The rung names are the y axis. They sit in their own column to the right
    /// of the plot, on the same baselines as the lines they name.
    private func labels(plotWidth: CGFloat, height: CGFloat) -> some View {
        let column = labelWidth - 8
        return ForEach(StreakLevel.allCases, id: \.rawValue) { rung in
            Text(rung.name)
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundColor(rung.tint.opacity(0.75))
                .frame(width: column, alignment: .leading)
                .position(x: plotWidth + 8 + column / 2, y: y(for: rung, in: height))
        }
    }

    // MARK: - Geometry

    private func x(_ index: Int, in width: CGFloat) -> CGFloat {
        guard points.count > 1 else { return width / 2 }
        let span = max(1, width - inset * 2)
        return inset + span * CGFloat(index) / CGFloat(points.count - 1)
    }

    private func y(for level: StreakLevel, in height: CGFloat) -> CGFloat {
        let rungs = CGFloat(StreakLevel.allCases.count)
        // Half-steps, so the top and bottom rungs sit inside the frame rather
        // than clipped against its edges.
        return height * (1 - (CGFloat(level.rawValue) + 0.5) / rungs)
    }

    private func y(at index: Int, in height: CGFloat) -> CGFloat {
        y(for: points[index].level ?? .ember, in: height)
    }

    /// Indices grouped into unbroken stretches of days that have a level.
    private func runs() -> [[Int]] {
        var result: [[Int]] = []
        var current: [Int] = []
        for (index, point) in points.enumerated() {
            if point.level != nil {
                current.append(index)
            } else if !current.isEmpty {
                result.append(current)
                current = []
            }
        }
        if !current.isEmpty { result.append(current) }
        return result.filter { $0.count > 1 }
    }

    private var summary: String {
        let drawn = points.compactMap(\.level)
        guard let latest = drawn.last else { return "No days recorded yet" }
        return "\(drawn.count) days recorded, most recently at \(latest.name)"
    }
}
