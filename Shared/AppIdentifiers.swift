import Foundation

/// The App Group is the seam between the four processes that make up ScreenSense.
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

extension UserDefaults {
    /// Reads the shared container, defeating this process's own cache.
    ///
    /// `UserDefaults` serves reads from an in-process cache that another
    /// process's write does not invalidate. The system keeps a shield extension
    /// warm between the times it draws the block screen, so that process goes on
    /// reporting whatever it read when it was first spawned — which is how the
    /// block screen came to offer a break budget that had already been spent.
    func freshData(forKey key: String) -> Data? {
        synchronize()
        return data(forKey: key)
    }

    /// Writes the shared container and doesn't return until the value is there.
    ///
    /// `set` hands the value to `cfprefsd` asynchronously. The shield-action
    /// extension spends a break and is killed within milliseconds of returning
    /// its response — early enough to lose the increment, so the break was taken
    /// but never counted.
    ///
    /// This is the case `synchronize()` still exists for. It is discouraged, not
    /// deprecated, and there is no replacement for an App Group shared between a
    /// long-lived app and processes the system may kill at any moment.
    func setDurable(_ value: Any?, forKey key: String) {
        if let value {
            set(value, forKey: key)
        } else {
            removeObject(forKey: key)
        }
        synchronize()
    }
}
