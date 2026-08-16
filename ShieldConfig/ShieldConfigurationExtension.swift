import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Draws the screen the user actually hits when they open a blocked app.
///
/// The system renders this; we only describe it. Note what is *not* available:
/// there is no way to show the blocked app's name or icon, because all this
/// process receives is an opaque token.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        Self.makeConfiguration()
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        Self.makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        Self.makeConfiguration()
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        Self.makeConfiguration()
    }

    // MARK: - Presentation

    /// "a 5-minute break" but "an 8-minute break". Within the 1...30 range the
    /// only numbers that read with a leading vowel sound are 8, 11 and 18.
    private static func article(for minutes: Int) -> String {
        [8, 11, 18].contains(minutes) ? "an" : "a"
    }

    private static func symbol(coolingDown: Bool, hasBreaks: Bool) -> String {
        if coolingDown { return "hourglass" }
        return hasBreaks ? "hand.raised.fill" : "moon.zzz.fill"
    }

    private static func makeConfiguration() -> ShieldConfiguration {
        // Read fresh: the count may have changed since the last time this
        // extension was spawned.
        let state = BreakStore.loadState()
        let settings = BreakStore.loadSettings()
        let remaining = state.breaksRemaining(limit: settings.breaksPerDay)
        let minutes = BreakRules.clampMinutes(settings.breakMinutes)

        // A break can be unavailable for two different reasons, and saying which
        // one matters: "come back in 12 minutes" is actionable, "no breaks left"
        // is not. Cooling down is checked first because it's the temporary one.
        let coolingDown = state.isCoolingDown()
        let hasBreaks = remaining > 0
        let canStart = hasBreaks && !coolingDown

        // The title carries the same distinction as the button. "Not right now"
        // is a *wait* — it only makes sense while the cooldown is running, when
        // coming back shortly does work. Saying it to someone with a break in
        // hand is wrong (they can go right now), and saying it to someone out of
        // breaks is a false promise (nothing changes until midnight).
        let title: String
        let subtitle: String
        let primaryLabel: String

        if coolingDown {
            let wait = BreakState.minutesRoundedUp(from: state.remainingCooldownSeconds())
            title = "Not right now"
            subtitle = "\(remaining) of \(settings.breaksPerDay) breaks left today."
            primaryLabel = "Next break in \(wait) minute\(wait == 1 ? "" : "s")"
        } else if hasBreaks {
            title = "You blocked this"
            subtitle = "\(remaining) of \(settings.breaksPerDay) breaks left today."
            primaryLabel = "Take \(Self.article(for: minutes)) \(minutes)-minute break"
        } else {
            title = "Done for today"
            subtitle = "No breaks left. They come back at midnight."
            primaryLabel = "Blocked until tomorrow"
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 0.92),
            icon: UIImage(systemName: Self.symbol(coolingDown: coolingDown, hasBreaks: hasBreaks)),
            title: ShieldConfiguration.Label(
                text: title,
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: subtitle,
                color: UIColor.white.withAlphaComponent(0.65)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: primaryLabel,
                color: canStart ? .white : UIColor.white.withAlphaComponent(0.4)
            ),
            primaryButtonBackgroundColor: canStart
                ? UIColor(red: 0.29, green: 0.55, blue: 1.0, alpha: 1.0)
                : UIColor(white: 1.0, alpha: 0.12),
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Close",
                color: UIColor.white.withAlphaComponent(0.75)
            )
        )
    }
}
