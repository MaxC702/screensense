import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

extension ManagedSettingsStore.Name {
    /// A named store keeps ScreenSense's restrictions in their own namespace, so
    /// clearing our shield never disturbs restrictions set by Apple's own Screen
    /// Time or by another app.
    static let screenBlock = Self("screenBlock")
}

extension DeviceActivityName {
    static let breakWindow = Self("screenblock.breakWindow")

    /// An interval that *starts* the instant a break's wall clock runs out, so
    /// `intervalDidStart` gives us a callback at an arbitrary time. iOS's
    /// 15-minute floor constrains how long an interval may be, not how far ahead
    /// it may begin — which is the loophole that makes a 1-minute break
    /// enforceable at all.
    static let breakEnd = Self("screenblock.breakEnd")
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
    /// `log: false` for the steady-state re-assert on every foreground, which is
    /// correct but happens constantly and buried everything interesting.
    static func applyShield(source: String = "app", log: Bool = true) {
        let selection = BreakStore.loadSelection()
        guard !selection.isEmpty else {
            // If this ever fires from an extension it is the bug: the extension
            // could not read the selection, so it *clears* the block instead of
            // applying it, and the apps stay open.
            BreakLog.record("applyShield: selection is EMPTY — clearing instead", source: source)
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

        if log {
            BreakLog.record(
                "shield applied: \(selection.applicationTokens.count) apps, \(selection.categoryTokens.count) categories, \(selection.webDomainTokens.count) sites",
                source: source
            )
        }
    }

    static func clearShield() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
    }
}
