import Foundation

/// The hard limits, in one place. What the user picks *within* these limits
/// lives in `BreakSettings`.
enum BreakRules {
    static let minBreaksPerDay = 1
    static let maxBreaksPerDay = 5
    static let defaultBreaksPerDay = 3

    static let minMinutes = 1
    static let maxMinutes = 30
    static let defaultBreakMinutes = 5
    static let minuteRange = minMinutes...maxMinutes
    static let breaksRange = minBreaksPerDay...maxBreaksPerDay

    /// Enforced wait between the end of one break and the start of the next,
    /// so the daily allowance can't be spent in one continuous sitting.
    static let minCooldownMinutes = 5
    static let maxCooldownMinutes = 60
    static let defaultCooldownMinutes = 15
    static let cooldownRange = minCooldownMinutes...maxCooldownMinutes

    /// iOS rejects a `DeviceActivitySchedule` whose interval is shorter than
    /// 15 minutes, so a 1-minute break cannot be expressed as one interval's
    /// length. The floor constrains duration, not start time, so a break is
    /// instead ended by a second interval scheduled to *begin* when it expires.
    /// This constant is that interval's length, and the padding on the usage
    /// window that backs it up.
    static let minimumScheduleMinutes = 15

    static func clampMinutes(_ minutes: Int) -> Int {
        min(max(minutes, minMinutes), maxMinutes)
    }

    static func clampBreaksPerDay(_ count: Int) -> Int {
        min(max(count, minBreaksPerDay), maxBreaksPerDay)
    }

    static func clampCooldownMinutes(_ minutes: Int) -> Int {
        min(max(minutes, minCooldownMinutes), maxCooldownMinutes)
    }
}

/// Everything the four processes need to agree on, small enough to round-trip
/// through `UserDefaults` on every read.
struct BreakState: Codable, Equatable {
    var dayKey: String
    var breaksUsed: Int
    /// Wall-clock deadline for the running break; `nil` when no break is active.
    var breakEndsAt: Date?
    /// Wall clock instant before which no new break may start. Set when a break
    /// ends. Optional on purpose: Swift's synthesized decoder uses
    /// `decodeIfPresent` for optionals, so payloads saved before cooldowns
    /// existed still decode instead of silently resetting the user's state.
    var cooldownUntil: Date?
    /// User-facing on/off switch. Blocking is never applied unless this is true.
    var blockingEnabled: Bool
    /// Instant at which the current unbroken run of blocking began; `nil` when
    /// blocking is off.
    ///
    /// A start date rather than a counter incremented at midnight, because
    /// nothing of ours is guaranteed to run at midnight. Deriving the length by
    /// subtraction means a streak stays correct across days when the app was
    /// never opened — which is precisely the streak this app wants to reward.
    var streakStartedOn: Date?
    /// Longest run reached so far, so breaking a streak leaves something to aim
    /// at rather than erasing the evidence that it happened.
    var bestStreak: Int
    /// Rungs currently docked from the ladder because a run was lost; zero when
    /// nothing is owed.
    ///
    /// Stored rather than derived, because the level itself is derived from
    /// settings the user can change at will — a penalty living in the settings
    /// could be wiped out by dragging a slider, which is the one place it must
    /// not be reachable from.
    var levelPenaltyRungs: Int

    init(
        dayKey: String = BreakState.dayKey(for: .now),
        breaksUsed: Int = 0,
        breakEndsAt: Date? = nil,
        cooldownUntil: Date? = nil,
        blockingEnabled: Bool = false,
        streakStartedOn: Date? = nil,
        bestStreak: Int = 0,
        levelPenaltyRungs: Int = 0
    ) {
        self.dayKey = dayKey
        self.breaksUsed = breaksUsed
        self.breakEndsAt = breakEndsAt
        self.cooldownUntil = cooldownUntil
        self.blockingEnabled = blockingEnabled
        self.streakStartedOn = streakStartedOn
        self.bestStreak = bestStreak
        self.levelPenaltyRungs = levelPenaltyRungs
    }

    /// Hand-written for the same reason as `BreakSettings`: the synthesized
    /// decoder calls `decode` for non-optional properties, so introducing one —
    /// `bestStreak` — would make every payload written by an earlier build
    /// throw. `BreakStore` turns a throw into a fresh default state, so that
    /// would quietly wipe today's usage and the running break on upgrade.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dayKey = try container.decodeIfPresent(String.self, forKey: .dayKey)
            ?? BreakState.dayKey(for: .now)
        breaksUsed = try container.decodeIfPresent(Int.self, forKey: .breaksUsed) ?? 0
        breakEndsAt = try container.decodeIfPresent(Date.self, forKey: .breakEndsAt)
        cooldownUntil = try container.decodeIfPresent(Date.self, forKey: .cooldownUntil)
        blockingEnabled = try container.decodeIfPresent(Bool.self, forKey: .blockingEnabled) ?? false
        streakStartedOn = try container.decodeIfPresent(Date.self, forKey: .streakStartedOn)
        bestStreak = max(0, try container.decodeIfPresent(Int.self, forKey: .bestStreak) ?? 0)
        levelPenaltyRungs = max(0, try container.decodeIfPresent(Int.self, forKey: .levelPenaltyRungs) ?? 0)
    }

    // MARK: - Derived

    /// Takes the daily allowance as a parameter rather than reading it, because
    /// the allowance is user-configurable and lives in `BreakSettings`.
    ///
    /// Floors at zero on purpose: lowering the allowance below what's already
    /// been spent today leaves you at none-left rather than going negative.
    func breaksRemaining(limit: Int) -> Int {
        max(0, limit - breaksUsed)
    }

    func isOnBreak(now: Date = .now) -> Bool {
        guard let breakEndsAt else { return false }
        return breakEndsAt > now
    }

    func remainingBreakSeconds(now: Date = .now) -> TimeInterval {
        guard let breakEndsAt else { return 0 }
        return max(0, breakEndsAt.timeIntervalSince(now))
    }

    /// Cooldowns are wall clock, deliberately unlike breaks. A usage-based
    /// cooldown could be waited out inside a blocked app, which defeats it.
    func isCoolingDown(now: Date = .now) -> Bool {
        guard let cooldownUntil else { return false }
        return cooldownUntil > now
    }

    func remainingCooldownSeconds(now: Date = .now) -> TimeInterval {
        guard let cooldownUntil else { return 0 }
        return max(0, cooldownUntil.timeIntervalSince(now))
    }

    /// `mm:ss` for live countdowns.
    static func countdown(from seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Coarser phrasing for one-shot messages, where a ticking clock would be
    /// stale by the time it's read.
    static func minutesRoundedUp(from seconds: TimeInterval) -> Int {
        max(1, Int((seconds / 60).rounded(.up)))
    }

    // MARK: - Streak

    /// Days blocking has been left on, counting today. Zero when blocking is off.
    ///
    /// Today counts from the moment the switch goes on rather than once the day
    /// has been survived: a streak reading "0" beside a switch that is plainly
    /// on looks broken, and the day is only ever lost by switching off — which
    /// is what `endStreak` is for.
    func streakDays(now: Date = .now, calendar: Calendar = .current) -> Int {
        guard let streakStartedOn else { return 0 }
        let elapsed = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: streakStartedOn),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        // A clock moved backwards, or a flight west, shouldn't read as negative.
        return max(0, elapsed) + 1
    }

    /// Called when blocking is switched on. An existing run is left alone, so
    /// that a repair pass or a second write can't quietly restart the count.
    mutating func beginStreakIfNeeded(now: Date = .now) {
        guard streakStartedOn == nil else { return }
        streakStartedOn = now
    }

    /// Switching blocking off is the one action that costs a streak.
    ///
    /// Spending a break deliberately does not. Breaks are the sanctioned way
    /// through the block, and charging a streak for using them would push people
    /// towards the switch instead — which removes the block entirely.
    mutating func endStreak(now: Date = .now, calendar: Calendar = .current) {
        let lost = streakDays(now: now, calendar: calendar)
        bestStreak = max(bestStreak, lost)

        // The days alone were not enough of a consequence. A run that ends goes
        // straight back to 1 while the flame keeps exactly the same colour and
        // the same name, which reads as though nothing was actually lost. Taking
        // a rung with it means the badge shows the loss in both dimensions.
        if lost >= StreakLevel.minimumRunToPenalise {
            levelPenaltyRungs = 1
        }

        streakStartedOn = nil
    }

    /// The penalty still in force, which is not always the one on record.
    ///
    /// Paid off in days on a new run rather than in wall clock, so it cannot be
    /// sat out: `streakDays` is zero for the entire time blocking is off, so the
    /// debt simply waits there until you start again.
    func activeLevelPenalty(now: Date = .now, calendar: Calendar = .current) -> Int {
        guard levelPenaltyRungs > 0 else { return 0 }
        let days = streakDays(now: now, calendar: calendar)
        return days >= StreakLevel.relightDays ? 0 : levelPenaltyRungs
    }

    /// Days of the current run still to go before the rung comes back.
    func daysToRelight(now: Date = .now, calendar: Calendar = .current) -> Int {
        max(0, StreakLevel.relightDays - streakDays(now: now, calendar: calendar))
    }

    // MARK: - Day rollover

    /// A local-calendar day stamp. Comparing stamps means the daily allowance
    /// resets at the user's own midnight without needing a scheduled job — the
    /// reset happens lazily on the first read of the new day.
    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    mutating func rollDayIfNeeded(now: Date = .now) {
        let today = BreakState.dayKey(for: now)
        guard today != dayKey else { return }
        dayKey = today
        breaksUsed = 0
    }
}
