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

    /// Days of per-day usage kept on disk. Thirty is enough to draw a graph
    /// with room to spare, and thirty small integers is nothing next to the
    /// payload this already round-trips on every read.
    static let usageHistoryDays = 30

    /// Days of finished usage the flame's level is averaged over.
    ///
    /// A single day would make the ladder thrash — every morning starts at zero
    /// minutes, which is a perfect score nobody has earned yet, and every
    /// afternoon would demote you for spending what you are allowed. A week is
    /// long enough that one heavy day does not undo a good run, and short enough
    /// that a change in habit shows up while you still remember making it.
    static let usageWindowDays = 7

    /// How early a trigger may arrive and still be believed.
    ///
    /// Small on purpose: it covers clock jitter around a deadline, nothing more.
    /// Anything earlier than this is not a break ending, it is a trigger
    /// misfiring — see `BreakEngine.endBreak`.
    static let endTriggerTolerance: TimeInterval = 2

    static func clampMinutes(_ minutes: Int) -> Int {
        min(max(minutes, minMinutes), maxMinutes)
    }

    static func clampBreaksPerDay(_ count: Int) -> Int {
        min(max(count, minBreaksPerDay), maxBreaksPerDay)
    }

    static func clampCooldownMinutes(_ minutes: Int) -> Int {
        min(max(minutes, minCooldownMinutes), maxCooldownMinutes)
    }

    /// Bounds on the usage figure the ladder is scaled against. Half an hour is
    /// below anything worth blocking for; sixteen hours is more waking day than
    /// anyone has. Neither is a number the UI can produce — they are here to
    /// stop a payload from another build cutting an absurd ladder.
    static let minBaselineMinutes = 30
    static let maxBaselineMinutes = 16 * 60

    static func clampBaselineMinutes(_ minutes: Int) -> Int {
        min(max(minutes, minBaselineMinutes), maxBaselineMinutes)
    }
}

/// Everything the four processes need to agree on, small enough to round-trip
/// through `UserDefaults` on every read.
struct BreakState: Codable, Equatable {
    var dayKey: String
    var breaksUsed: Int
    /// Wall-clock deadline for the running break; `nil` when no break is active.
    var breakEndsAt: Date?
    /// When the running break began, so what gets charged is the time actually
    /// taken rather than the length that was scheduled. Ending a break early
    /// still spends the break — it just costs fewer minutes, which is the whole
    /// difference between a budget and a record of what you did.
    var breakStartedAt: Date?
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
    /// The day the last run was lost on; `nil` when none has been.
    ///
    /// The day a streak dies is spent. Without this, switching blocking off and
    /// straight back on reads as a fresh day one within seconds of losing the
    /// old one, which makes the loss cost nothing at all — the count is back and
    /// the flame is lit before you have put the phone down.
    var streakBrokenOn: Date?
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
    /// Minutes actually unblocked, per day.
    ///
    /// Keyed by day stamp rather than kept as an array, so a day on which no
    /// break was taken simply has no entry and reads as zero. There is no gap to
    /// align and nothing to write at midnight.
    var unblockedMinutes: [String: Int]

    init(
        dayKey: String = BreakState.dayKey(for: .now),
        breaksUsed: Int = 0,
        breakEndsAt: Date? = nil,
        breakStartedAt: Date? = nil,
        cooldownUntil: Date? = nil,
        blockingEnabled: Bool = false,
        streakStartedOn: Date? = nil,
        streakBrokenOn: Date? = nil,
        bestStreak: Int = 0,
        levelPenaltyRungs: Int = 0,
        unblockedMinutes: [String: Int] = [:]
    ) {
        self.dayKey = dayKey
        self.breaksUsed = breaksUsed
        self.breakEndsAt = breakEndsAt
        self.breakStartedAt = breakStartedAt
        self.cooldownUntil = cooldownUntil
        self.blockingEnabled = blockingEnabled
        self.streakStartedOn = streakStartedOn
        self.streakBrokenOn = streakBrokenOn
        self.bestStreak = bestStreak
        self.levelPenaltyRungs = levelPenaltyRungs
        self.unblockedMinutes = unblockedMinutes
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
        breakStartedAt = try container.decodeIfPresent(Date.self, forKey: .breakStartedAt)
        cooldownUntil = try container.decodeIfPresent(Date.self, forKey: .cooldownUntil)
        blockingEnabled = try container.decodeIfPresent(Bool.self, forKey: .blockingEnabled) ?? false
        streakStartedOn = try container.decodeIfPresent(Date.self, forKey: .streakStartedOn)
        streakBrokenOn = try container.decodeIfPresent(Date.self, forKey: .streakBrokenOn)
        bestStreak = max(0, try container.decodeIfPresent(Int.self, forKey: .bestStreak) ?? 0)
        levelPenaltyRungs = max(0, try container.decodeIfPresent(Int.self, forKey: .levelPenaltyRungs) ?? 0)
        unblockedMinutes = try container.decodeIfPresent([String: Int].self, forKey: .unblockedMinutes) ?? [:]
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

    /// Whether a trigger claiming this break is over arrived too early to be
    /// believed. False when no break is running, which the caller handles first.
    ///
    /// Lives here rather than inside `BreakEngine` so the rule can be exercised
    /// without a `DeviceActivityCenter` to hand.
    func endTriggerIsEarly(now: Date = .now) -> Bool {
        guard let breakEndsAt else { return false }
        return now < breakEndsAt - BreakRules.endTriggerTolerance
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

        // A run begun on the day an earlier one died does not get to claim that
        // day: it is already spent. Counting from the break rather than from the
        // switch is what holds the number at zero for the rest of the day and
        // lets it read 1 tomorrow.
        if let streakBrokenOn, startedInsideBrokenDay(calendar: calendar) {
            let since = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: streakBrokenOn),
                to: calendar.startOfDay(for: now)
            ).day ?? 0
            return max(0, since)
        }

        let elapsed = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: streakStartedOn),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        // A clock moved backwards, or a flight west, shouldn't read as negative.
        return max(0, elapsed) + 1
    }

    /// Whether the run in progress was begun on or before the day the last one
    /// was lost — the case where its opening day has already been spent.
    private func startedInsideBrokenDay(calendar: Calendar) -> Bool {
        guard let streakStartedOn, let streakBrokenOn else { return false }
        return calendar.startOfDay(for: streakStartedOn) <= calendar.startOfDay(for: streakBrokenOn)
    }

    /// Whether a run was lost today. The flame stays out and the count stays at
    /// zero for the rest of the day however quickly blocking goes back on, so
    /// this is what the screens ask when they need to say *why*.
    func streakBrokenToday(now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let streakBrokenOn else { return false }
        return calendar.isDate(streakBrokenOn, inSameDayAs: now)
    }

    /// Called when blocking is switched on. An existing run is left alone, so
    /// that a repair pass or a second write can't quietly restart the count.
    mutating func beginStreakIfNeeded(now: Date = .now, calendar: Calendar = .current) {
        guard streakStartedOn == nil else { return }
        // A loss from an earlier day has already been served. Carrying it into
        // this run would dock it a day it does not owe.
        if let streakBrokenOn, !calendar.isDate(streakBrokenOn, inSameDayAs: now) {
            self.streakBrokenOn = nil
        }
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
        streakBrokenOn = now
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
        pruneUsageHistory(now: now)
    }

    // MARK: - What the days actually cost

    /// Charges `minutes` to the day the break *started* on.
    ///
    /// A break running across midnight belongs to the evening it began, not to
    /// the small hours it finished in — that is the day whose habit it describes.
    mutating func recordUnblocked(minutes: Int, startedOn key: String) {
        guard minutes > 0 else { return }
        unblockedMinutes[key, default: 0] += minutes
    }

    func unblocked(on key: String) -> Int { unblockedMinutes[key] ?? 0 }

    mutating func pruneUsageHistory(now: Date = .now, calendar: Calendar = .current) {
        let keep = Set(BreakState.dayKeys(endingAt: now, count: BreakRules.usageHistoryDays, calendar: calendar))
        unblockedMinutes = unblockedMinutes.filter { keep.contains($0.key) }
    }

    /// Day stamps for the last `count` days, oldest first, ending with `now`.
    static func dayKeys(
        endingAt now: Date,
        count: Int,
        calendar: Calendar = .current
    ) -> [String] {
        stride(from: count - 1, through: 0, by: -1).compactMap { back in
            calendar.date(byAdding: .day, value: -back, to: now)
                .map { dayKey(for: $0, calendar: calendar) }
        }
    }

    /// Average unblocked minutes across the days of the current run, up to a
    /// week of them, today included.
    ///
    /// Today counts from the first minute, which is what makes the flame a
    /// reading of what has actually been spent rather than a report on last
    /// week. Take one ten-minute break, end it halfway, and five minutes is what
    /// the day is worth — immediately.
    ///
    /// The cost of that is a flame that runs hot in the morning, when a day with
    /// nothing spent on it genuinely is a day with nothing spent on it, and
    /// cools as the budget goes. That is the honest way round: the alternative
    /// credits you now for restraint you have not shown yet.
    ///
    /// `nil` only when no run is in progress, since then there are no days of it
    /// to average.
    func averageUnblockedMinutes(now: Date = .now, calendar: Calendar = .current) -> Double? {
        let window = min(streakDays(now: now, calendar: calendar), BreakRules.usageWindowDays)
        guard window > 0 else { return nil }

        let keys = (0..<window).compactMap { back in
            calendar.date(byAdding: .day, value: -back, to: now)
                .map { BreakState.dayKey(for: $0, calendar: calendar) }
        }
        guard !keys.isEmpty else { return nil }
        return Double(keys.reduce(0) { $0 + unblocked(on: $1) }) / Double(keys.count)
    }

    /// Whether a day is one this app can speak for: either something was spent
    /// on it, or it falls inside the run that is currently going.
    ///
    /// Days before any of that are not zero-minute triumphs, they are days the
    /// app was not watching — and drawing them at the top of the graph would
    /// credit the user for a week they spent on their phone.
    func hasRecord(for date: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        if unblockedMinutes[BreakState.dayKey(for: date, calendar: calendar)] != nil { return true }
        guard let streakStartedOn else { return false }
        return calendar.startOfDay(for: date) >= calendar.startOfDay(for: streakStartedOn)
            && calendar.startOfDay(for: date) <= calendar.startOfDay(for: now)
    }
}
