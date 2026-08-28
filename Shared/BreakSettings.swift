import Foundation

/// User-configurable limits.
///
/// Kept separate from `BreakState` (which tracks what has been *spent*) because
/// these are read by all four processes but written only by the app's settings
/// screen. The shield extension in particular needs `breakMinutes` to label its
/// button, and it has no UI of its own to ask with.
struct BreakSettings: Codable, Equatable {
    var breaksPerDay: Int
    var breakMinutes: Int
    /// Enforced wait after a break ends before another may start.
    var cooldownMinutes: Int
    /// Minutes a day the user reckons they were spending in these apps before
    /// any of this. The figure the ladder's rungs are cut from.
    ///
    /// Optional because "not asked yet" is a real state and has to be told apart
    /// from any particular answer — it is what makes the Streak tab put the
    /// question the first time it is opened. Until then the ladder runs on
    /// `ScreenTimeBand.unanswered`, whose rungs are within a minute of the fixed
    /// ones this replaced.
    var baselineMinutes: Int?

    /// The figure to actually cut rungs from, answered or not.
    var effectiveBaselineMinutes: Int {
        baselineMinutes ?? ScreenTimeBand.unanswered.baselineMinutes
    }

    init(
        breaksPerDay: Int = BreakRules.defaultBreaksPerDay,
        breakMinutes: Int = BreakRules.defaultBreakMinutes,
        cooldownMinutes: Int = BreakRules.defaultCooldownMinutes,
        baselineMinutes: Int? = nil
    ) {
        self.breaksPerDay = BreakRules.clampBreaksPerDay(breaksPerDay)
        self.breakMinutes = BreakRules.clampMinutes(breakMinutes)
        self.cooldownMinutes = BreakRules.clampCooldownMinutes(cooldownMinutes)
        self.baselineMinutes = baselineMinutes.map(BreakRules.clampBaselineMinutes)
    }

    /// Decoded field-by-field with `decodeIfPresent` so that adding a setting in
    /// a later version doesn't make every previously-saved payload fail to
    /// decode — which would silently reset the user's configuration.
    ///
    /// Values are re-clamped on the way in: a payload written by a build with
    /// different limits should be pulled into range, not trusted.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        breaksPerDay = BreakRules.clampBreaksPerDay(
            try container.decodeIfPresent(Int.self, forKey: .breaksPerDay)
                ?? BreakRules.defaultBreaksPerDay
        )
        breakMinutes = BreakRules.clampMinutes(
            try container.decodeIfPresent(Int.self, forKey: .breakMinutes)
                ?? BreakRules.defaultBreakMinutes
        )
        // Added after the first release of this struct. Settings saved before
        // cooldowns existed simply fall back to the default here rather than
        // failing to decode and wiping the whole configuration.
        cooldownMinutes = BreakRules.clampCooldownMinutes(
            try container.decodeIfPresent(Int.self, forKey: .cooldownMinutes)
                ?? BreakRules.defaultCooldownMinutes
        )
        // Absent means never asked, which is exactly what the optional is for —
        // there is no default to fall back on here, only a question to put.
        baselineMinutes = try container
            .decodeIfPresent(Int.self, forKey: .baselineMinutes)
            .map(BreakRules.clampBaselineMinutes)
    }
}
