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

    private static func makeConfiguration() -> ShieldConfiguration {
        // Read fresh: the count may have changed since the last time this
        // extension was spawned.
        let state = BreakStore.loadState()
        let remaining = state.breaksRemaining
        let minutes = BreakRules.clampMinutes(state.preferredMinutes)

        let hasBreaks = remaining > 0
        let subtitle = hasBreaks
            ? "\(remaining) of \(BreakRules.breaksPerDay) breaks left today."
            : "No breaks left. They come back at midnight."

        let primaryLabel = hasBreaks
            ? "Take a \(minutes)-minute break"
            : "Blocked until tomorrow"

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 0.92),
            icon: UIImage(systemName: hasBreaks ? "hand.raised.fill" : "moon.zzz.fill"),
            title: ShieldConfiguration.Label(
                text: "Not right now",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: subtitle,
                color: UIColor.white.withAlphaComponent(0.65)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: primaryLabel,
                color: hasBreaks ? .white : UIColor.white.withAlphaComponent(0.4)
            ),
            primaryButtonBackgroundColor: hasBreaks
                ? UIColor(red: 0.29, green: 0.55, blue: 1.0, alpha: 1.0)
                : UIColor(white: 1.0, alpha: 0.12),
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Close",
                color: UIColor.white.withAlphaComponent(0.75)
            )
        )
    }
}
