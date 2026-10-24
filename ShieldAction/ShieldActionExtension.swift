import ManagedSettings
import UIKit

/// Handles taps on the block screen's buttons.
///
/// This is where ScreenSense's main ergonomic win lives. An extension cannot
/// launch its container app, so most blockers make you quit, hunt down their
/// icon, and tap through a menu just to get five minutes. Because this process
/// shares the App Group and holds the Family Controls entitlement, it can spend
/// a break and lift the shield in place — you stay in the app you opened.
class ShieldActionExtension: ShieldActionDelegate {

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(respond(to: action))
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(respond(to: action))
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(respond(to: action))
    }

    // MARK: - Lifting

    /// Safe to call when the shield is already down.
    private static func liftShieldForBreak() {
        guard BreakStore.loadState().isOnBreak(), ShieldController.isShielding else { return }
        ShieldController.clearShield()
        BreakLog.record("shield lifted for break", source: "shieldaction")
    }

    // MARK: - Decision

    private func respond(to action: ShieldAction) -> ShieldActionResponse {
        switch action {
        case .primaryButtonPressed:
            do {
                // Length and allowance are read from BreakSettings inside the
                // engine, so this stays correct when the user changes them.
                try BreakEngine.startBreak(liftShield: false)
                // iOS 27 keeps the last screen it drew for an app and shows it
                // again when the shield returns, so lifting the shield straight
                // away left this screen — "Take a break" — waiting at the end of
                // the break, and only a refused tap brought up the cooldown.
                //
                // So the shield stays up for a moment and `.defer` makes iOS
                // redraw it. `ShieldConfig` sees the break and draws the screen
                // as it will look when the break ends; then the shield is lifted
                // here, which lets the user through. Here and not in
                // `ShieldConfig`, whose sandbox lets it neither write to the App
                // Group nor post a notification saying it has drawn.
                //
                // The redraw lands 14–16 ms after this returns, and must land
                // before the lift: lifting first left iOS keeping its own
                // "Restricted" placeholder for the end of the break. Whatever is
                // on the shield as it lifts shows for a moment, so the wait is
                // as short as that allows. `reconcile` lifts the shield if this
                // never runs.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                    Self.liftShieldForBreak()
                }
                return .defer
            } catch {
                // Out of breaks, or scheduling failed. `.defer` leaves the block
                // screen up rather than silently letting the user in.
                return .defer
            }

        case .secondaryButtonPressed:
            return .close

        @unknown default:
            return .close
        }
    }
}
