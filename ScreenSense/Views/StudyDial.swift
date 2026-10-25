import SwiftUI
import UIKit

/// A kitchen-timer dial for a study length: drag the knob round the ring, one
/// lap an hour, in 5-minute clicks.
///
/// Laps rather than one sweep for the whole range, because four hours on one
/// circle would put 5 minutes at 7.5° — too fine to hit with a thumb. At an hour
/// a lap a click is 30°, and the common lengths fall where a clock face would
/// put them.
struct StudyDial: View {
    @Binding var minutes: Int

    /// Unsnapped minutes under the finger, so a slow drag still adds up to a
    /// click instead of rounding back to where it started on every update.
    @State private var dragMinutes: Double?
    @State private var lastAngle: Double?

    private let size: CGFloat = 264
    private let lineWidth: CGFloat = 18
    private let haptics = UISelectionFeedbackGenerator()

    private var hours: Int { minutes / 60 }

    /// Where the ring and knob are drawn: under the finger while dragging, and
    /// on the snapped length otherwise. Counted in total minutes rather than
    /// minutes into the lap, so passing an hour animates on round the circle
    /// instead of sweeping all the way back to 12.
    private var shownMinutes: Double { dragMinutes ?? Double(minutes) }

    var body: some View {
        ZStack {
            ticks

            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: lineWidth)

            // Hours already wound sit underneath as a full, quieter ring, so
            // 1 h 15 min reads as "a lap and a quarter" rather than as 15 min.
            WoundHours(minutes: shownMinutes)
                .stroke(Theme.accent.opacity(0.35), lineWidth: lineWidth)

            LapArc(minutes: shownMinutes)
                .stroke(Theme.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            knob

            readout
        }
        .frame(width: size, height: size)
        // Room for the ticks, which sit outside the ring.
        .padding(20)
        .contentShape(Circle())
        .gesture(drag)
        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.85), value: shownMinutes)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Session length")
        .accessibilityValue(BreakRules.studyLengthText(minutes))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: set(minutes + BreakRules.studyMinuteStep)
            case .decrement: set(minutes - BreakRules.studyMinuteStep)
            @unknown default: break
            }
        }
    }

    // MARK: - Parts

    /// A tick a minute, a longer one every five — the clicks the knob lands on.
    private var ticks: some View {
        ForEach(0..<60, id: \.self) { minute in
            let major = minute % BreakRules.studyMinuteStep == 0
            Capsule()
                .fill(Color.white.opacity(major ? 0.3 : 0.12))
                .frame(width: major ? 2 : 1, height: major ? 9 : 5)
                .offset(y: -(size / 2 + 10))
                .rotationEffect(.degrees(Double(minute) * 6))
        }
    }

    private var knob: some View {
        Circle()
            .fill(Color.white)
            .frame(width: lineWidth + 12, height: lineWidth + 12)
            .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
            .offset(y: -size / 2)
            .rotationEffect(.degrees(shownMinutes * 6))
    }

    private var readout: some View {
        VStack(spacing: 4) {
            Text(clockText)
                .font(Theme.display(54, .ultraLight))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(hours == 0 ? "minutes" : "hours")
                .font(.system(size: 11, weight: .bold))
                .kerning(1.2)
                .textCase(.uppercase)
                .foregroundColor(Theme.faint)
            Text("Ends at \(Date.now.addingTimeInterval(TimeInterval(minutes * 60)).formatted(date: .omitted, time: .shortened))")
                .font(.system(size: 12))
                .foregroundColor(Theme.muted)
                .padding(.top, 6)
        }
    }

    /// "25" under the 60-minute mark, "1:15" past it — the face a timer shows.
    private var clockText: String {
        hours == 0 ? "\(minutes)" : String(format: "%d:%02d", hours, minutes % 60)
    }

    // MARK: - Dragging

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let angle = Self.angle(of: value.location, in: size + 40)
                if let lastAngle {
                    // The shorter way round from the last point, so crossing
                    // 12 o'clock goes on into the next lap instead of jumping
                    // back a whole hour.
                    var delta = angle - lastAngle
                    if delta > 180 { delta -= 360 }
                    if delta < -180 { delta += 360 }
                    let range = BreakRules.studyMinuteRange
                    let raw = (dragMinutes ?? Double(minutes)) + delta / 6
                    let clamped = min(max(raw, Double(range.lowerBound)), Double(range.upperBound))
                    dragMinutes = clamped
                    set(Int(clamped.rounded()))
                } else {
                    dragMinutes = Double(minutes)
                    haptics.prepare()
                }
                lastAngle = angle
            }
            .onEnded { _ in
                // Settles from under the finger onto the snapped length.
                dragMinutes = nil
                lastAngle = nil
            }
    }

    private func set(_ value: Int) {
        let snapped = BreakRules.validStudyMinutes(value)
        guard snapped != minutes else { return }
        minutes = snapped
        haptics.selectionChanged()
    }

    /// Degrees clockwise from 12 o'clock, 0..<360.
    private static func angle(of point: CGPoint, in size: CGFloat) -> Double {
        let dx = point.x - size / 2, dy = point.y - size / 2
        let degrees = atan2(dx, -dy) * 180 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }
}

/// The current lap's arc, from 12 o'clock round to `minutes` past the hour.
///
/// A shape rather than a trimmed circle so it animates the total: going from
/// 55 to 65 minutes runs on through 12 instead of shrinking back from 55 to 5.
private struct LapArc: Shape {
    var minutes: Double

    var animatableData: Double {
        get { minutes }
        set { minutes = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let lap = minutes.truncatingRemainder(dividingBy: 60) / 60
        var path = Path()
        guard lap > 0 else { return path }
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: min(rect.width, rect.height) / 2,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + lap * 360),
            clockwise: false
        )
        return path
    }
}

/// A full ring once at least an hour is wound, nothing before. Animated off the
/// same total as `LapArc`, so the two hand over at the same instant.
private struct WoundHours: Shape {
    var minutes: Double

    var animatableData: Double {
        get { minutes }
        set { minutes = newValue }
    }

    func path(in rect: CGRect) -> Path {
        minutes >= 60 ? Circle().path(in: rect) : Path()
    }
}
