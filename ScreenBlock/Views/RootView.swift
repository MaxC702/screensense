import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if model.isAuthorized {
                HomeView()
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
