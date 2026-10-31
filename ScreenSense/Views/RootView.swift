import SwiftUI
import UIKit

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

    init() {
        // The tab bar has no SwiftUI handle for its unselected colour or its
        // top rule, so it is set once here, before the first one is drawn.
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterialDark)
        appearance.backgroundColor = UIColor(Theme.background).withAlphaComponent(0.9)
        appearance.shadowColor = UIColor(Theme.hairline)
        let item = appearance.stackedLayoutAppearance
        item.normal.iconColor = UIColor(Theme.faint)
        item.normal.titleTextAttributes = [.foregroundColor: UIColor(Theme.faint)]
        item.selected.iconColor = UIColor(Theme.foreground)
        item.selected.titleTextAttributes = [.foregroundColor: UIColor(Theme.foreground)]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
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
                        .tabItem { Label("Streak", systemImage: "flame") }
                        .tag(Tab.streak)
                }
            } else {
                PermissionView()
            }
        }
        .foregroundColor(Theme.foreground)
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
///
/// A study desk rather than a dashboard: warm graphite, paper-white ink, and one
/// ember colour kept back for the streak. Nothing on a screen is coloured unless
/// it is the streak or it is telling you blocking is on, so the colour that is
/// there gets read.
enum Theme {
    static let background = Color(red: 0.059, green: 0.059, blue: 0.055)
    /// A step up from the background, for the disabled button and anything else
    /// that has to sit on the page without being part of it.
    static let surface = Color(red: 0.094, green: 0.094, blue: 0.086)
    /// The secondary button's fill — visible against the page, quieter than ink.
    static let raised = Color(red: 0.133, green: 0.133, blue: 0.122)
    static let hairline = Color(red: 0.165, green: 0.165, blue: 0.153)
    static let foreground = Color(red: 0.925, green: 0.922, blue: 0.902)
    static let muted = Color(red: 0.608, green: 0.604, blue: 0.576)
    static let faint = Color(red: 0.400, green: 0.396, blue: 0.373)
    /// The streak's own colour, and the only warm thing in the palette, so it is
    /// a different currency from everything else on screen at a glance. Doubles
    /// as the Flame rung of `StreakLevel`.
    static let streak = Color(red: 0.910, green: 0.573, blue: 0.353)
    /// Blocking is on. Green so it means what a status light means, and muted so
    /// it does not compete with the streak for being the colour on the screen.
    static let ok = Color(red: 0.561, green: 0.749, blue: 0.541)

    /// Display face for the wordmark, headings and big numerals.
    ///
    /// New York, the serif that ships with iOS, so this bundles no font files and
    /// needs no licence. Headings and figures set in it read as a page someone
    /// wrote rather than as a control panel — which is the entire reason for it,
    /// since SF is what every other app on the phone already looks like. Body
    /// text, values and captions stay on SF Pro, where legibility at small sizes
    /// matters more than character.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// The big figures — breaks left, a countdown, the streak. Light and
    /// fixed-width, so a ticking clock does not shuffle sideways every second.
    static func numeral(_ size: CGFloat) -> Font {
        .system(size: size, weight: .light, design: .serif).monospacedDigit()
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
        case .ember: return Color(red: 0.851, green: 0.384, blue: 0.290)
        case .flame: return Theme.streak
        case .blaze: return Color(red: 0.929, green: 0.761, blue: 0.369)
        case .whiteHeat: return Color(red: 0.961, green: 0.937, blue: 0.867)
        case .blueFlame: return Color(red: 0.459, green: 0.792, blue: 0.918)
        }
    }
}

// MARK: - Streak

/// The five-rung heat bar, lit up to `level`, with each rung named under it.
///
/// Each rung carries its own tint rather than the current level's, so the bar
/// shows the ladder itself — where this streak sits on it, and what the colour
/// above it will be. Rungs already climbed past are dimmed, so the eye lands on
/// the one being held.
struct StreakLadder: View {
    let level: StreakLevel
    /// What the budget already earns, when that is higher than what is lit.
    /// Rungs between the two are drawn as ghosts — the gap a lost run opened up,
    /// and exactly what relighting gives back.
    var target: StreakLevel?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(StreakLevel.allCases, id: \.rawValue) { rung in
                    Capsule()
                        .fill(fill(for: rung))
                        .frame(height: 3)
                }
            }
            HStack(spacing: 4) {
                ForEach(StreakLevel.allCases, id: \.rawValue) { rung in
                    Text(rung.name)
                        .font(.system(size: 11))
                        .foregroundColor(rung == level ? rung.tint : Theme.faint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private func fill(for rung: StreakLevel) -> Color {
        if rung == level { return rung.tint }
        if rung < level { return rung.tint.opacity(0.5) }
        if let target, rung <= target { return rung.tint.opacity(0.22) }
        return Theme.hairline
    }

    private var label: String {
        let base = "\(level.name), level \(level.rawValue + 1) of \(StreakLevel.allCases.count)"
        guard let target, target > level else { return base }
        return base + ", down from \(target.name)"
    }
}

/// The flame in its three states: lit, never started, and broken.
///
/// The broken one is not just the unlit one in grey. Losing a run and never
/// having had one are different facts, and until the day rolls over they are the
/// only two things a zero can mean — so the badge says which by being visibly
/// split rather than merely dark.
struct StreakFlame: View {
    let size: CGFloat
    let lit: Bool
    /// A run was lost today. Ignored while `lit`, which cannot happen on the
    /// same day as a loss.
    var broken = false
    /// The level's colour, which only a lit flame takes. A broken one is grey by
    /// definition — there is no rung being held to show the colour of.
    var tint: Color = Theme.faint

    var body: some View {
        if lit {
            symbol("flame.fill", tint)
        } else if broken {
            BrokenFlame(size: size)
        } else {
            symbol("flame", Theme.faint)
        }
    }

    private func symbol(_ name: String, _ colour: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: size, weight: .semibold))
            .foregroundColor(colour)
    }
}

/// A filled flame cracked down the middle, the two halves hinged apart at the
/// bottom like a shell.
///
/// Filled rather than outlined, because the break has to be read as a break: a
/// gap through a hollow glyph is just another gap in an outline, whereas a gap
/// through a solid one is a thing that has come apart. The halves are cut from
/// the same symbol, so the crack is the space between them rather than a line
/// drawn over the top — which means it stays a crack against any background the
/// badge sits on.
struct BrokenFlame: View {
    let size: CGFloat
    var tint: Color = Theme.faint

    /// How far each half swings open, in degrees, turned about its foot.
    ///
    /// A rotation rather than a slide, which is the whole difference between a
    /// crack and a cut. Something that splits stays joined at one end and gapes
    /// at the other, so the break is widest at the tip — where a flame is
    /// thinnest and the loss shows most — and closes to nothing at the base.
    private var swing: Double { 4.5 }

    /// A hair of daylight along the rest of the seam, so the two halves read as
    /// separated all the way down rather than merely hinged.
    private var parting: CGFloat { size * 0.018 }

    var body: some View {
        ZStack {
            half(leading: true)
                .rotationEffect(.degrees(-swing), anchor: .bottom)
                .offset(x: -parting)
            half(leading: false)
                .rotationEffect(.degrees(swing), anchor: .bottom)
                .offset(x: parting)
        }
        .accessibilityHidden(true)
    }

    private func half(leading: Bool) -> some View {
        Image(systemName: "flame.fill")
            .font(.system(size: size, weight: .semibold))
            .foregroundColor(tint)
            .mask { Crack(leading: leading) }
    }

    /// Everything on one side of the zigzag. The seam runs past the top and
    /// bottom of the box so the cut reaches the glyph however the symbol is
    /// inset, and the half is closed off well outside the frame for the same reason.
    private struct Crack: Shape {
        let leading: Bool

        /// Fractions of the icon's box, top to bottom. It wanders either side of
        /// the middle rather than zigzagging evenly: a break follows whatever
        /// line the material gives it, and a regular sawtooth reads as a
        /// decoration rather than as damage.
        private static let seam: [CGPoint] = [
            CGPoint(x: 0.52, y: -0.30),
            CGPoint(x: 0.46, y: 0.18),
            CGPoint(x: 0.55, y: 0.38),
            CGPoint(x: 0.47, y: 0.60),
            CGPoint(x: 0.53, y: 0.82),
            CGPoint(x: 0.50, y: 1.30),
        ]

        func path(in rect: CGRect) -> Path {
            let points = Crack.seam.map {
                CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height)
            }
            let edge = leading ? rect.minX - rect.width : rect.maxX + rect.width

            var path = Path()
            path.move(to: points[0])
            for point in points.dropFirst() { path.addLine(to: point) }
            path.addLine(to: CGPoint(x: edge, y: points[points.count - 1].y))
            path.addLine(to: CGPoint(x: edge, y: points[0].y))
            path.closeSubpath()
            return path
        }
    }
}

/// The figure the ladder is cut from, and the way back to changing it.
///
/// Shown in both places the level is explained: the Streak tab, which reports
/// what was earned, and Settings, which sets what is allowed. A baseline that
/// could only be answered once would go stale in exactly the case the app is
/// built to produce — someone who really does get from six hours down to two
/// keeps being judged against the six, and keeps being handed a top rung they
/// have outgrown.
struct BaselineRow: View {
    let band: ScreenTimeBand
    let hasChosen: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            (Text("Starting point ").foregroundColor(Theme.muted)
             + Text(hasChosen ? band.phrase : "a guess so far").foregroundColor(Theme.foreground))
                .font(.system(size: 14))
            Spacer(minLength: 0)
            Button(action: action) {
                Text(hasChosen ? "Change" : "Answer")
                    .font(.system(size: 14, weight: .medium))
                    .underline(color: Theme.faint)
                    .foregroundColor(Theme.foreground)
            }
            .buttonStyle(.plain)
        }
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

// MARK: - Page

/// The large serif heading every screen opens with, in place of a navigation
/// bar title. The bar above it keeps only its back button.
struct ScreenTitle: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Theme.display(34))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
            .padding(.bottom, 24)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Groups rows under a quiet heading, so a screen reads as a few subjects —
/// what is blocked, and what it costs to get in — rather than as one
/// undifferentiated list.
struct SectionLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(Theme.faint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A hairline, the page's only divider. Sections are separated by rules and
/// space rather than by being boxed, so nothing on screen looks like a card
/// that might be tapped when it is only a heading.
struct Rule: View {
    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1)
    }
}

/// A stack of rows with a rule above the first and under every one — a ledger
/// rather than a set of cards.
struct RuledList<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Rule()
            content
        }
    }
}

extension View {
    /// A pushed screen's bar: its back button and nothing else, because the
    /// screen's own `ScreenTitle` is the heading. The title is still set, so the
    /// back button on the screen after this one is labelled with it.
    func pushedScreen(_ title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { Text("") } }
            .toolbarBackground(Theme.background, for: .navigationBar)
    }

    /// One row of a `RuledList`: its vertical padding and the rule beneath it.
    func ruledRow(padding: CGFloat = 16) -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, padding)
            .overlay(alignment: .bottom) { Rule() }
    }
}

// MARK: - Controls

/// The full-width capsule every action on a screen uses.
///
/// Primary is ink on paper, for the one thing a screen is there to do. Secondary
/// is quieter, for the ways out — ending a break, ending a session — which
/// should be easy to find and not look like the point. Disabled goes flat into
/// the page, because the label it carries is still a readout worth reading.
struct PillButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }

    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        Pill(configuration: configuration, kind: kind)
    }

    private struct Pill: View {
        let configuration: Configuration
        let kind: Kind
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: 15, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(fill, in: Capsule())
                .foregroundColor(text)
                .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
        }

        private var fill: Color {
            guard isEnabled else { return Theme.surface }
            return kind == .primary ? Theme.foreground : Theme.raised
        }

        private var text: Color {
            guard isEnabled else { return Theme.faint }
            return kind == .primary ? Theme.background : Theme.foreground
        }
    }
}

/// One of a row of mutually exclusive capsules — a study length, a number of
/// breaks. The chosen one is filled, so the row reads as a setting with a value
/// rather than as a row of buttons waiting to be pressed.
struct ChoiceChip: View {
    let title: String
    let selected: Bool
    /// Drawn with a dashed edge, for the chip that opens something rather than
    /// picking a value.
    var opensMore = false
    var height: CGFloat = 38
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .foregroundColor(selected ? Theme.background : Theme.muted)
                .background(selected ? Theme.foreground : Color.clear, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(
                        selected ? Theme.foreground : Theme.hairline,
                        style: StrokeStyle(lineWidth: 1, dash: opensMore && !selected ? [3, 3] : [])
                    )
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A switch drawn in the page's own ink: paper track and a dark knob when on, a
/// raised track and a grey knob when off. The system switch only takes a track
/// colour, and a paper-white track under its white knob makes the knob vanish.
struct InkToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Switch(configuration: configuration)
    }

    private struct Switch: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            HStack(spacing: 16) {
                configuration.label
                Spacer(minLength: 0)
                Capsule()
                    .fill(configuration.isOn ? Theme.foreground : Theme.raised)
                    .frame(width: 46, height: 28)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(configuration.isOn ? Theme.background : Theme.muted)
                            .frame(width: 22, height: 22)
                            .padding(3)
                    }
                    .animation(.easeOut(duration: 0.2), value: configuration.isOn)
            }
            .contentShape(Rectangle())
            .onTapGesture { if isEnabled { configuration.isOn.toggle() } }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(configuration.isOn ? "On" : "Off")
            .accessibilityAction { if isEnabled { configuration.isOn.toggle() } }
        }
    }
}

// MARK: - Ring

/// The one number a screen is about, inside a thin ring.
///
/// It replaces a row of dots, which stopped being countable past four and could
/// not also express a countdown. The same ring shows breaks remaining when idle,
/// time remaining during a break, and a session's clock while studying, so the
/// eye returns to one place.
struct HeroRing<Content: View>: View {
    let fraction: Double
    var size: CGFloat = 216
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.hairline, lineWidth: 2)

            if fraction > 0 {
                Circle()
                    .trim(from: 0, to: min(max(fraction, 0), 1))
                    .stroke(Theme.foreground, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }

            content
        }
        .padding(1.5)
        .frame(width: size, height: size)
        .frame(maxWidth: .infinity)
    }
}
