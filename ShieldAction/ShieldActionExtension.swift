import ManagedSettings
import UIKit

/// Handles taps on the block screen's buttons.
///
/// This is where ScreenBlock's main ergonomic win lives. An extension cannot
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

    // MARK: - Decision

    private func respond(to action: ShieldAction) -> ShieldActionResponse {
        switch action {
        case .primaryButtonPressed:
            let minutes = BreakStore.loadState().preferredMinutes
            do {
                try BreakEngine.startBreak(minutes: minutes)
                // `.none` dismisses the shield and lets the user through. The
                // tokens were already cleared by `startBreak`, so this is not a
                // one-time bypass — the app is genuinely unblocked until the
                // monitor extension puts the shield back.
                return .none
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
