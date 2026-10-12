import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

extension ManagedSettingsStore.Name {
    /// A named store keeps ScreenSense's restrictions in their own namespace, so
    /// clearing our shield never disturbs restrictions set by Apple's own Screen
    /// Time or by another app.
    static let screenBlock = Self("screenBlock")

    /// The other half of the pair `ShieldController` alternates between.
    static let screenBlockAlternate = Self("screenBlockAlternate")
}

extension DeviceActivityName {
    static let breakWindow = Self("screenblock.breakWindow")

    /// An interval that *starts* the instant a break's wall clock runs out, so
    /// `intervalDidStart` gives us a callback at an arbitrary time. iOS's
    /// 15-minute floor constrains how long an interval may be, not how far ahead
    /// it may begin — which is the loophole that makes a 1-minute break
    /// enforceable at all.
    static let breakEnd = Self("screenblock.breakEnd")

    /// The same trick as `breakEnd`, for the end of a study session.
    static let studyEnd = Self("screenblock.studyEnd")
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
    /// Two stores, used in turn: each time the shield goes back up after being
    /// cleared, it goes into the store that did not hold it last time.
    ///
    /// iOS 27 keeps the block screen it last drew for an app and shows it again
    /// when the shield comes back while that app is not on screen — without
    /// asking `ShieldConfig` for a new one. Clearing and re-applying the same
    /// store is not enough to make it ask, so a break that ended in the
    /// background left the pre-break screen up: the old break count, and a
    /// "Take a break" button in the middle of the cooldown. A shield arriving
    /// from a different store is a new shield as far as the system is concerned.
    private static let stores = [
        ManagedSettingsStore(named: .screenBlock),
        ManagedSettingsStore(named: .screenBlockAlternate),
    ]

    /// Applies the user's saved selection. Safe to call repeatedly.
    /// `log: false` for the steady-state re-assert on every foreground, which is
    /// correct but happens constantly and buried everything interesting.
    ///
    /// `redraw: true` moves a shield that is already up into the other store,
    /// for when what the block screen says has changed without the shield ever
    /// coming down — a study session starting or ending. Left where it was, the
    /// shield would go on showing the screen iOS drew before the change.
    static func applyShield(source: String = "app", log: Bool = true, redraw: Bool = false) {
        let selection = BreakStore.loadSelection()
        guard !selection.isEmpty else {
            // If this ever fires from an extension it is the bug: the extension
            // could not read the selection, so it *clears* the block instead of
            // applying it, and the apps stay open.
            BreakLog.record("applyShield: selection is EMPTY — clearing instead", source: source)
            clearShield()
            return
        }

        // A shield that is already up is re-asserted where it is — that is the
        // steady state on every foreground, and moving it would make iOS redraw
        // for nothing. Only a shield going back up after a clear, which is what
        // the end of a break is, swaps to the other store.
        let active = stores.firstIndex(where: \.isShielding)
        let index: Int
        if let active, !redraw {
            index = active
        } else {
            index = 1 - (active ?? lastStoreIndex)
            lastStoreIndex = index
        }
        let store = stores[index]

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

        // Only once the new store holds the shield, so there is no instant at
        // which neither does.
        if let active, active != index { stores[active].clearShieldSettings() }

        if log {
            BreakLog.record(
                "shield applied: \(selection.applicationTokens.count) apps, \(selection.categoryTokens.count) categories, \(selection.webDomainTokens.count) sites",
                source: source
            )
        }
    }

    static func clearShield() {
        stores.forEach { $0.clearShieldSettings() }
    }

    /// Which store the shield last went into. Kept in its own file rather than
    /// in `BreakState`, because the processes that apply the shield would
    /// otherwise each need a read-modify-write of the whole state to flip one bit.
    private static var lastStoreIndex: Int {
        get {
            guard let url = storeIndexURL,
                  let text = try? String(contentsOf: url, encoding: .utf8),
                  let index = Int(text), stores.indices.contains(index)
            else { return 0 }
            return index
        }
        set {
            guard let url = storeIndexURL else { return }
            try? String(newValue).write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private static var storeIndexURL: URL? {
        BreakStore.containerURL?.appendingPathComponent("shield-store.v1", isDirectory: false)
    }
}

private extension ManagedSettingsStore {
    var isShielding: Bool {
        shield.applications != nil
            || shield.applicationCategories != nil
            || shield.webDomains != nil
            || shield.webDomainCategories != nil
    }

    func clearShieldSettings() {
        shield.applications = nil
        shield.applicationCategories = nil
        shield.webDomains = nil
        shield.webDomainCategories = nil
    }
}
