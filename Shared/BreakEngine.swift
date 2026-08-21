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
        state.breakStartedAt = now
        state.breakEndsAt = now.addingTimeInterval(TimeInterval(duration * 60))
        BreakStore.save(state)

        ShieldController.clearShield()
        BreakLog.record(
            "break started, \(duration)m, ends \(Self.clock(state.breakEndsAt ?? now))",
            source: "app"
        )
        return state
    }

    // MARK: - End

    /// Re-applies the shield, starts the cooldown, and tears down monitoring.
    ///
    /// Idempotent, because it can be called by the usage threshold, the interval
    /// backstop, and the app's foreground check — potentially all three for the
    /// same break.
    static func endBreak(now: Date = .now, source: String = "app") {
        let existing = BreakStore.loadState(now: now)

        // Nothing running: don't re-apply, and above all don't tear down again.
        // `stopMonitoring` delivers `intervalDidEnd` for the activity it stops,
        // which calls straight back into here — so without this guard one expiry
        // ran the whole slow path twice.
        guard existing.breakEndsAt != nil else {
            BreakLog.record("endBreak (\(source)): no break was running", source: source)
            return
        }

        let settings = BreakStore.loadSettings()

        // The cooldown is recorded BEFORE the shield goes up, because putting the
        // shield up is what makes the system ask `ShieldConfig` to draw the block
        // screen — and the system caches that answer for as long as the shield
        // stands. Applying first meant the block screen was always drawn from a
        // state where the cooldown did not exist yet, so it offered "Take a
        // 5-minute break" for the whole cooldown and never said how long the wait
        // was.
        //
        // This also clears `breakEndsAt` ahead of `stopMonitoring` below, so the
        // re-entrant call that teardown provokes hits the guard at the top and
        // returns immediately.
        BreakStore.mutate(now: now) { state in
            guard let scheduledEnd = state.breakEndsAt else { return }

            // Anchor the cooldown to when the break *actually* ended, not to the
            // moment we noticed. Ending early makes `now` the real end; noticing
            // late (a reconcile hours after the fact) makes `scheduledEnd` the
            // real end. Using `now` unconditionally would silently extend the
            // cooldown by however long the app stayed closed.
            let actualEnd = min(scheduledEnd, now)
            state.cooldownUntil = actualEnd
                .addingTimeInterval(TimeInterval(settings.cooldownMinutes * 60))

            // Charge the time actually taken. Breaks written by a build that
            // predates `breakStartedAt` have no start to measure from, so they
            // fall back to the length that was scheduled — the same number the
            // old build would have implied.
            let startedAt = state.breakStartedAt
                ?? scheduledEnd.addingTimeInterval(-TimeInterval(settings.breakMinutes * 60))
            let elapsed = max(0, actualEnd.timeIntervalSince(startedAt))
            state.recordUnblocked(
                minutes: Int((elapsed / 60).rounded()),
                startedOn: BreakState.dayKey(for: startedAt)
            )

            state.breakStartedAt = nil
            state.breakEndsAt = nil
        }

        // Now the shield, which is the only step the user is waiting for. What
        // must stay below it is `stopMonitoring`: tearing down two DeviceActivity
        // registrations measured 31 seconds inside the monitor extension, and
        // doing that first is what once made a 1-minute break run for a minute
        // and a half. The write above is a single defaults round trip.
        //
        // Being killed between the write and this line would leave the apps open
        // with the state saying the break is over. `reconcile` re-applies on the
        // next foreground, which is the same net that covers a missed trigger.
        if existing.blockingEnabled {
            ShieldController.applyShield(source: source)
        } else {
            BreakLog.record("endBreak (\(source)): blocking is off, nothing to re-apply", source: source)
        }

        DeviceActivityCenter().stopMonitoring([.breakWindow, .breakEnd])
    }

    /// `HH:mm:ss`, which is the only part of a timestamp that matters when you are
    /// checking whether something fired on time.
    static func clock(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        return String(format: "%02d:%02d:%02d", parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0)
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

        // Blocking is on, so a run is in progress by definition. It won't be
        // recorded yet for anyone upgrading from a build that predates streaks,
        // and a switch that is plainly on next to a streak of zero reads as a
        // bug — so start the count from the first foreground instead.
        if state.streakStartedOn == nil {
            BreakStore.mutate(now: now) { $0.beginStreakIfNeeded(now: now) }
        }

        // A paid-off penalty is only ever *computed* as spent; clear the record
        // too, so the stored state stops claiming a debt that no longer exists.
        if state.levelPenaltyRungs > 0, state.activeLevelPenalty(now: now) == 0 {
            BreakStore.mutate(now: now) { $0.levelPenaltyRungs = 0 }
        }

        if state.breakEndsAt != nil, !state.isOnBreak(now: now) {
            BreakLog.record("reconcile: found an expired break still open", source: "app/reconcile")
            endBreak(source: "app/reconcile")
        } else if state.breakEndsAt == nil {
            ShieldController.applyShield(source: "app/reconcile", log: false)
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
        center.stopMonitoring([.breakWindow, .breakEnd])

        let calendar = Calendar.current
        let components: (Date) -> DateComponents = {
            calendar.dateComponents([.hour, .minute, .second], from: $0)
        }

        // Primary trigger: an interval that *begins* when the break's wall clock
        // expires. `intervalDidStart` then fires at that moment, whatever the
        // user happens to be doing.
        //
        // This exists because the usage threshold below cannot be trusted to be
        // punctual. iOS accounts usage in coarse batches, so a 1-minute
        // threshold can land minutes late or, if the user never opens a blocked
        // app, never at all — leaving the break open until the padded window
        // closed it a quarter of an hour later.
        let breakEnd = now.addingTimeInterval(TimeInterval(minutes * 60))
        let resumeSchedule = DeviceActivitySchedule(
            intervalStart: components(breakEnd),
            intervalEnd: components(
                breakEnd.addingTimeInterval(TimeInterval(BreakRules.minimumScheduleMinutes * 60))
            ),
            repeats: false
        )

        do {
            try center.startMonitoring(.breakEnd, during: resumeSchedule)
            BreakLog.record("armed resume interval for \(Self.clock(breakEnd))", source: "app")
        } catch {
            BreakLog.record("resume interval FAILED: \(error.localizedDescription)", source: "app")
            throw BreakError.schedulingFailed(error.localizedDescription)
        }

        // Secondary trigger: usage threshold, plus the padded interval as a
        // backstop that fires `intervalDidEnd`. Both now only matter if the
        // resume interval above fails to fire; `endBreak` is idempotent, so
        // whichever arrives first wins and the rest are no-ops.
        let windowMinutes = max(minutes, BreakRules.minimumScheduleMinutes) + 1
        let windowEnd = now.addingTimeInterval(TimeInterval(windowMinutes * 60))

        let schedule = DeviceActivitySchedule(
            intervalStart: components(now),
            intervalEnd: components(windowEnd),
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
            // Don't leave the resume trigger armed for a break that never began.
            center.stopMonitoring([.breakEnd])
            throw BreakError.schedulingFailed(error.localizedDescription)
        }
    }
}
