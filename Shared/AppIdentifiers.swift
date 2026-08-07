import Foundation

/// The App Group is the seam between the four processes that make up ScreenBlock.
/// The container app writes state; the monitor, shield, and shield-action
/// extensions read (and sometimes write) it from their own sandboxes.
///
/// The identifier is injected into every target's Info.plist from
/// `Config/Signing.xcconfig`, so there is exactly one place to change it.
enum AppIdentifiers {
    /// Fallback matches the default in Config/Signing.xcconfig. It is only ever
    /// used if the Info.plist key went missing, which means a build-config bug.
    private static let fallbackAppGroup = "group.com.screenblock.app"

    static let appGroup: String = {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String,
            !value.isEmpty,
            !value.hasPrefix("$(")
        else {
            assertionFailure("AppGroupIdentifier missing from Info.plist — check Config/Signing.xcconfig")
            return fallbackAppGroup
        }
        return value
    }()
}

extension UserDefaults {
    /// Shared container. If this ever falls back to `.standard` the extensions
    /// stop seeing the app's state, which is exactly the bug that makes a break
    /// counter appear to reset at random — so it asserts loudly in debug.
    static let shared: UserDefaults = {
        guard let defaults = UserDefaults(suiteName: AppIdentifiers.appGroup) else {
            assertionFailure("App Group \(AppIdentifiers.appGroup) is not provisioned for this target")
            return .standard
        }
        return defaults
    }()
}
