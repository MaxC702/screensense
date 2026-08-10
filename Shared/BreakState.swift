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

    /// iOS rejects a `DeviceActivitySchedule` whose interval is shorter than
    /// 15 minutes, so a 1-minute break cannot be expressed as a schedule.
    /// Short breaks are enforced by a usage *event threshold* instead, and the
    /// padded interval below exists only as a backstop that closes the window.
    static let minimumScheduleMinutes = 15

    static func clampMinutes(_ minutes: Int) -> Int {
        min(max(minutes, minMinutes), maxMinutes)
    }

    static func clampBreaksPerDay(_ count: Int) -> Int {
        min(max(count, minBreaksPerDay), maxBreaksPerDay)
    }
}

/// Everything the four processes need to agree on, small enough to round-trip
/// through `UserDefaults` on every read.
struct BreakState: Codable, Equatable {
    var dayKey: String
    var breaksUsed: Int
    /// Wall-clock deadline for the running break; `nil` when no break is active.
    var breakEndsAt: Date?
    /// User-facing on/off switch. Blocking is never applied unless this is true.
    var blockingEnabled: Bool

    init(
        dayKey: String = BreakState.dayKey(for: .now),
        breaksUsed: Int = 0,
        breakEndsAt: Date? = nil,
        blockingEnabled: Bool = false
    ) {
        self.dayKey = dayKey
        self.breaksUsed = breaksUsed
        self.breakEndsAt = breakEndsAt
        self.blockingEnabled = blockingEnabled
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
