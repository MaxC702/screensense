import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

extension ManagedSettingsStore.Name {
    /// A named store keeps ScreenBlock's restrictions in their own namespace, so
    /// clearing our shield never disturbs restrictions set by Apple's own Screen
    /// Time or by another app.
    static let screenBlock = Self("screenBlock")
}

extension DeviceActivityName {
    static let breakWindow = Self("screenblock.breakWindow")
}

extension DeviceActivityEvent.Name {
    static let breakUsage = Self("screenblock.breakUsage")
}

/// The only place that writes shield tokens into ManagedSettings.
///
/// Writing `store.shield.applications` is what actually puts the block screen in
/// front of an app. The write is instantaneous and persists across reboots until
/// something clears it, so this is also the thing that must be cleared carefully.
enum ShieldController {
    static let store = ManagedSettingsStore(named: .screenBlock)

    /// Applies the user's saved selection. Safe to call repeatedly.
    static func applyShield() {
        let selection = BreakStore.loadSelection()
        guard !selection.isEmpty else {
            clearShield()
            return
        }

        // Passing an empty set is not the same as passing nil: nil means "no
        // restriction", an empty set means "restrict nothing", and mixing them
        // up leaves stale tokens behind.
        store.shield.applications = selection.applicationTokens.isEmpty
            ? nil
            : selection.applicationTokens

        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)

        store.shield.webDomains = selection.webDomainTokens.isEmpty
            ? nil
            : selection.webDomainTokens

        store.shield.webDomainCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
    }

    static func clearShield() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
    }
}
