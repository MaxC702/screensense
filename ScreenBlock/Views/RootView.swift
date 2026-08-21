import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var tab: Tab = .breaks

    /// Two tabs, not three. Settings stays behind the gear on the home screen,
    /// because it holds the switch that turns blocking off — and putting that a
    /// thumb's reach from every screen would undo the point of moving it there.
    enum Tab: Hashable {
        case breaks
        case streak
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if model.isAuthorized {
                TabView(selection: $tab) {
                    HomeView(onShowStreak: { tab = .streak })
                        .tabItem { Label("Breaks", systemImage: "hourglass") }
                        .tag(Tab.breaks)

                    StreakView()
                        .tabItem { Label("Streak", systemImage: "flame.fill") }
                        .tag(Tab.streak)
                }
            } else {
                PermissionView()
            }
        }
        .alert(
            "Hold on",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            ),
            actions: { Button("OK", role: .cancel) { model.errorMessage = nil } },
            message: { Text(model.errorMessage ?? "") }
        )
    }
}

/// Small palette so the app and the shield extension read as the same product.
enum Theme {
    static let background = Color(red: 0.043, green: 0.035, blue: 0.071)
    static let card = Color(red: 0.090, green: 0.078, blue: 0.122)
    static let accent = Color(red: 0.486, green: 0.361, blue: 1.0)
    static let accentEnd = Color(red: 0.290, green: 0.549, blue: 1.0)
    /// Legible on top of `card`; the accent itself is too dark for small text.
    static let accentSoft = Color(red: 0.722, green: 0.647, blue: 1.0)
    static let muted = Color.white.opacity(0.55)
    static let faint = Color.white.opacity(0.35)
    static let hairline = Color.white.opacity(0.07)
    /// The streak's own colour. Warm on purpose: it is a different currency from
    /// the break budget, and reusing the purple accent would make the two read as
    /// one meter. System orange goes muddy on this background, so this is a
    /// lifted amber. Doubles as the Flame rung of `StreakLevel`.
    static let streak = Color(red: 1.0, green: 0.596, blue: 0.251)

    static let gradient = LinearGradient(
        colors: [accent, accentEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Display face for the wordmark, headings and the ring's numerals.
    ///
    /// Avenir Next ships with iOS, so this bundles no font files and needs no
    /// licence. It is geometric and airy where SF Pro is neutral — which is the
    /// entire reason for using it, since SF is what every other app on the phone
    /// already looks like. Body text, values and captions stay on SF Pro, where
    /// legibility at small sizes matters more than character.
    static func display(_ size: CGFloat, _ weight: DisplayWeight = .regular) -> Font {
        .custom(weight.postScriptName, size: size)
    }

    enum DisplayWeight {
        case ultraLight, regular, medium, demiBold

        var postScriptName: String {
            switch self {
            case .ultraLight: return "AvenirNext-UltraLight"
            case .regular: return "AvenirNext-Regular"
            case .medium: return "AvenirNext-Medium"
            case .demiBold: return "AvenirNext-DemiBold"
            }
        }
    }
}

/// The ladder's tints, kept out of `StreakLevel` itself because that type is
/// compiled into all four targets and `Theme` only exists in the app.
///
/// They run the way a fire actually heats — dull red, amber, gold, white, blue —
/// so climbing the ladder looks like climbing it, and the flame in the header
/// says how hard a streak is before its name is read anywhere.
extension StreakLevel {
    var tint: Color {
        switch self {
        case .ember: return Color(red: 0.878, green: 0.353, blue: 0.235)
        case .flame: return Theme.streak
        case .blaze: return Color(red: 1.0, green: 0.788, blue: 0.243)
        case .whiteHeat: return Color(red: 1.0, green: 0.965, blue: 0.878)
        // Cyan rather than a true blue, which at this size is indistinguishable
        // from the accent that ends the app's own gradient.
        case .blueFlame: return Color(red: 0.361, green: 0.871, blue: 1.0)
        }
    }
}

/// The five-rung heat bar, lit up to `level`.
///
/// Each rung carries its own tint rather than the current level's, so the bar
/// shows the ladder itself — where this streak sits on it, and what the colour
/// above it will be.
struct StreakLadder: View {
    let level: StreakLevel
    /// What the budget already earns, when that is higher than what is lit.
    /// Rungs between the two are drawn as ghosts — the gap a lost run opened up,
    /// and exactly what relighting gives back.
    var target: StreakLevel?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(StreakLevel.allCases, id: \.rawValue) { rung in
                Capsule()
                    .fill(fill(for: rung))
                    .frame(height: 5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private func fill(for rung: StreakLevel) -> Color {
        if rung <= level { return rung.tint }
        if let target, rung <= target { return rung.tint.opacity(0.22) }
        return Color.white.opacity(0.10)
    }

    private var label: String {
        let base = "\(level.name), level \(level.rawValue + 1) of \(StreakLevel.allCases.count)"
        guard let target, target > level else { return base }
        return base + ", down from \(target.name)"
    }
}

/// How much is left in the current rung, drawn as a little upright cell.
///
/// The ladder says which rung you are on; this says where you are standing on
/// it. Full means the minutes sit at the strict end of the band and the rung is
/// not going anywhere. Nearly empty means one more break's worth of average and
/// the flame drops.
///
/// Every part of it — fill, track and outline — is the current level's own
/// colour rather than the usual green-to-red of a battery, because red already
/// means Ember here and a red gauge on a gold Blaze would be reading out two
/// different things at once.
struct LevelBattery: View {
    let charge: Double
    let tint: Color
    var size = CGSize(width: 8, height: 19)

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 2.5, style: .continuous) }

    var body: some View {
        ZStack(alignment: .bottom) {
            // The unfilled part stays tinted rather than going grey, so the rung's
            // colour reads off the gauge even when there is barely any charge in
            // it — a nearly empty Blaze should still look like Blaze.
            shape.fill(tint.opacity(0.22))
            // A sliver at the bottom even when empty, so it reads as "almost
            // gone" rather than as something that failed to draw.
            shape.fill(tint)
                .frame(height: max(1.5, size.height * min(1, max(0, charge))))
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .overlay(shape.stroke(tint.opacity(0.6), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rung \(Int((min(1, max(0, charge)) * 100).rounded())) percent")
    }
}

/// Reusable rounded container.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// Groups cards under a quiet all-caps heading, so the screen reads as two
/// subjects — what is blocked, and what it costs to get in — rather than as one
/// undifferentiated stack.
struct SectionLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .kerning(1.2)
            .foregroundColor(Theme.faint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.top, 6)
    }
}

/// Tinted rounded square holding a symbol. Gives each card a fixed anchor on the
/// left so headers line up down the screen.
struct IconTile: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Theme.accentSoft)
            .frame(width: 34, height: 34)
            .background(
                Theme.accent.opacity(0.16),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
    }
}

/// Small capsule for a value that belongs to a card's header rather than its body.
struct Pill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.14), in: Capsule())
    }
}

/// The break budget as an arc.
///
/// It replaces a row of dots, which stopped being countable past four and could
/// not also express a countdown. The same ring shows breaks remaining when idle
/// and time remaining during a break, so the eye returns to one place.
struct BreakRing<Content: View>: View {
    let fraction: Double
    /// On the gradient card the arc is drawn white; on a flat card it carries
    /// the gradient itself, which would be invisible against its own background.
    let onGradient: Bool
    @ViewBuilder var content: Content

    private let lineWidth: CGFloat = 10

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    Color.white.opacity(onGradient ? 0.25 : 0.08),
                    lineWidth: lineWidth
                )

            arc

            content
        }
        .frame(width: 134, height: 134)
    }

    @ViewBuilder
    private var arc: some View {
        let trimmed = Circle().trim(from: 0, to: min(max(fraction, 0), 1))
        let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round)

        if onGradient {
            trimmed.stroke(Color.white, style: style).rotationEffect(.degrees(-90))
        } else {
            trimmed.stroke(Theme.gradient, style: style).rotationEffect(.degrees(-90))
        }
    }
}
