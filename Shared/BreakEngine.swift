import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// The decision logic for starting, ending, and repairing breaks.
///
/// This deliberately lives in `Shared/` and takes no UI dependencies, because
/// three different processes call it: the app (user taps "Start break"), the
/// shield-action extension (user taps the button on the block screen), and the
/// monitor extension (a break's time or usage ran out).
enum BreakEngine {

    enum BreakError: LocalizedError {
        case noAppsSelected
        case noBreaksLeft(limit: Int)
        case alreadyOnBreak
        case coolingDown(secondsRemaining: TimeInterval)
        case schedulingFailed(String)

        var errorDescription: String? {
            switch self {
            case .noAppsSelected:
                return "Choose at least one app to block first."
            case .noBreaksLeft(let limit):
                return "You've used all \(limit) break\(limit == 1 ? "" : "s") today. They reset at midnight."
            case .alreadyOnBreak:
                return "A break is already running."
            case .coolingDown(let seconds):
                let minutes = BreakState.minutesRoundedUp(from: seconds)
                return "Cooling down. You can start another break in \(minutes) minute\(minutes == 1 ? "" : "s")."
            case .schedulingFailed(let reason):
                return "Couldn't schedule the break: \(reason)"
            }
        }
    }

    // MARK: - Start

    /// Spends one of the day's breaks and lifts the shield for the configured
    /// break length.
    ///
    /// Duration and allowance both come from `BreakSettings` rather than from
    /// the caller, so the app and the shield-action extension cannot disagree
    /// about how long a break lasts or how many are left.
    ///
    /// The shield is only cleared *after* monitoring is successfully armed. If
    /// arming failed and we had cleared first, the apps would be unblocked with
    /// nothing scheduled to ever block them again.
    @discardableResult
    static func startBreak(now: Date = .now) throws -> BreakState {
        var state = BreakStore.loadState(now: now)
        let settings = BreakStore.loadSettings()

        guard !state.isOnBreak(now: now) else { throw BreakError.alreadyOnBreak }
        guard !state.isCoolingDown(now: now) else {
            throw BreakError.coolingDown(secondsRemaining: state.remainingCooldownSeconds(now: now))
        }
        guard state.breaksRemaining(limit: settings.breaksPerDay) > 0 else {
            throw BreakError.noBreaksLeft(limit: settings.breaksPerDay)
        }

        let selection = BreakStore.loadSelection()
        guard !selection.isEmpty || PreviewEnvironment.isSimulator else {
            throw BreakError.noAppsSelected
        }

        let duration = BreakRules.clampMinutes(settings.breakMinutes)
        try armMonitoring(minutes: duration, selection: selection, now: now)

        state.breaksUsed += 1
        state.breakEndsAt = now.addingTimeInterval(TimeInterval(duration * 60))
        BreakStore.save(state)

        ShieldController.clearShield()
        return state
    }

    // MARK: - End

    /// Re-applies the shield, starts the cooldown, and tears down monitoring.
    ///
    /// Idempotent, because it can be called by the usage threshold, the interval
    /// backstop, and the app's foreground check — potentially all three for the
    /// same break.
    static func endBreak(now: Date = .now) {
        DeviceActivityCenter().stopMonitoring([.breakWindow])
        let settings = BreakStore.loadSettings()

        let state = BreakStore.mutate(now: now) { state in
            // Only arm a cooldown if a break was actually running. Without this
            // guard, the repeat calls described above would each push the
            // cooldown further out and it would never expire.
            guard let scheduledEnd = state.breakEndsAt else { return }

            // Anchor the cooldown to when the break *actually* ended, not to the
            // moment we noticed. Ending early makes `now` the real end; noticing
            // late (a reconcile hours after the fact) makes `scheduledEnd` the
            // real end. Using `now` unconditionally would silently extend the
            // cooldown by however long the app stayed closed.
            let actualEnd = min(scheduledEnd, now)
            state.cooldownUntil = actualEnd
                .addingTimeInterval(TimeInterval(settings.cooldownMinutes * 60))
            state.breakEndsAt = nil
        }

        guard state.blockingEnabled else { return }
        ShieldController.applyShield()
    }

    /// Cheap consistency check to run whenever the app comes to the foreground.
    ///
    /// It exists because the two out-of-process triggers can both miss: the
    /// usage threshold only fires if the user actually opens the blocked apps,
    /// and the interval backstop is padded to iOS's 15-minute floor. This closes
    /// a short break on wall-clock time the next time the user opens ScreenBlock.
    static func reconcile(now: Date = .now) {
        let state = BreakStore.loadState(now: now)

        guard state.blockingEnabled else {
            ShieldController.clearShield()
            return
        }

        if state.breakEndsAt != nil, !state.isOnBreak(now: now) {
            endBreak()
        } else if state.breakEndsAt == nil {
            ShieldController.applyShield()
        }
    }

    // MARK: - Scheduling

    private static func armMonitoring(
        minutes: Int,
        selection: FamilyActivitySelection,
        now: Date
    ) throws {
        // DeviceActivity refuses to schedule in the Simulator. Skipping it there
        // leaves the break running on wall clock alone, closed by the in-app
        // reconcile — enough to exercise the UI, and never reached on device.
        guard !PreviewEnvironment.isSimulator else { return }

        let center = DeviceActivityCenter()
        center.stopMonitoring([.breakWindow])

        let calendar = Calendar.current

        // Two independent triggers cover the break:
        //
        //  1. `threshold` — fires after `minutes` of *actual usage* of the
        //     blocked apps. This is the real enforcement, and it is the only
        //     mechanism that works below 15 minutes.
        //  2. The schedule interval — padded up to iOS's 15-minute minimum, it
        //     fires `intervalDidEnd` as a backstop so a break can never be left
        //     open forever if the threshold never trips.
        let windowMinutes = max(minutes, BreakRules.minimumScheduleMinutes) + 1
        let windowEnd = now.addingTimeInterval(TimeInterval(windowMinutes * 60))

        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.hour, .minute, .second], from: now),
            intervalEnd: calendar.dateComponents([.hour, .minute, .second], from: windowEnd),
            repeats: false
        )

        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: DateComponents(minute: minutes)
        )

        do {
            try center.startMonitoring(
                .breakWindow,
                during: schedule,
                events: [.breakUsage: event]
            )
        } catch {
            throw BreakError.schedulingFailed(error.localizedDescription)
        }
    }
}
