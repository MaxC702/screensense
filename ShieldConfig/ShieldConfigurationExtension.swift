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

    /// Out of breaks outranks cooling down: when both are true the cooldown is
    /// irrelevant, because nothing it is counting towards exists.
    ///
    /// The moon is only honest late on. "They come back at midnight" reads as a
    /// sleep cue at 22:00 and as a non sequitur at 14:00, so before 21:00 the
    /// spent budget gets a lock instead — same message, no implication that the
    /// user should be in bed.
    private static func symbol(coolingDown: Bool, hasBreaks: Bool, now: Date = .now) -> String {
        if !hasBreaks {
            let hour = Calendar.current.component(.hour, from: now)
            return hour >= 21 ? "moon.zzz.fill" : "lock.fill"
        }
        return coolingDown ? "hourglass" : "hand.raised.fill"
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
        // is not.
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
        // Optional: with the budget spent there is nothing to offer, and a button
        // is a control. Leaving one there — even an inert one — invites a tap and
        // then refuses it. Only "Close" remains.
        let primaryLabel: String?

        // Spending the last break puts you in both states at once. Out-of-breaks
        // has to be tested first, or the cooldown branch wins and offers a "next
        // break" that will not exist until midnight.
        if !hasBreaks {
            title = "Done for today"
            subtitle = "No breaks left."
            primaryLabel = nil
        } else if coolingDown {
            let wait = BreakState.minutesRoundedUp(from: state.remainingCooldownSeconds())
            title = "Not right now"
            subtitle = "\(remaining) of \(settings.breaksPerDay) breaks left today."
            primaryLabel = "Next break in \(wait) minute\(wait == 1 ? "" : "s")"
        } else {
            title = "You blocked this"
            subtitle = "\(remaining) of \(settings.breaksPerDay) breaks left today."
            primaryLabel = "Take \(Self.article(for: minutes)) \(minutes)-minute break"
        }

        // Recorded so Diagnostics can tell the two failure modes apart: a stale
        // count with no line here means the system never asked and is showing a
        // cached screen; a stale count *with* one means this process read the
        // wrong thing.
        BreakLog.record(
            "shield drawn: \(remaining) of \(settings.breaksPerDay) left, cooling down: \(coolingDown)",
            source: "shield"
        )

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.043, green: 0.035, blue: 0.071, alpha: 0.93),
            icon: UIImage(systemName: Self.symbol(coolingDown: coolingDown, hasBreaks: hasBreaks)),
            title: ShieldConfiguration.Label(
                text: title,
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: subtitle,
                color: UIColor.white.withAlphaComponent(0.65)
            ),
            primaryButtonLabel: primaryLabel.map {
                ShieldConfiguration.Label(
                    text: $0,
                    color: canStart ? .white : UIColor.white.withAlphaComponent(0.4)
                )
            },
            primaryButtonBackgroundColor: primaryLabel == nil
                ? nil
                : (canStart
                   ? UIColor(red: 0.486, green: 0.361, blue: 1.0, alpha: 1.0)
                   : UIColor(white: 1.0, alpha: 0.12)),
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Close",
                color: UIColor.white.withAlphaComponent(0.75)
            )
        )
    }
}
