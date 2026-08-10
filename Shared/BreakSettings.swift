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

    init(
        breaksPerDay: Int = BreakRules.defaultBreaksPerDay,
        breakMinutes: Int = BreakRules.defaultBreakMinutes
    ) {
        self.breaksPerDay = BreakRules.clampBreaksPerDay(breaksPerDay)
        self.breakMinutes = BreakRules.clampMinutes(breakMinutes)
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
    }
}
