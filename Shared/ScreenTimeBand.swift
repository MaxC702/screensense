import Foundation

/// Roughly how long the user was spending in these apps before any of this.
///
/// The ladder used to be five fixed numbers of minutes, which quietly assumed
/// everyone starts from the same place. They do not. Someone on six hours a day
/// who gets down to forty minutes has done something remarkable and would have
/// been told they were on the second rung from the bottom; someone on ninety
/// minutes who spends forty has barely moved and would have been told the same.
/// One of those two is being insulted and the other is being flattered, by the
/// same number.
///
/// So the rungs are cut as a share of this figure instead. What the ladder
/// measures is how far you have come down from your own starting point, which is
/// the only version of the question that means the same thing to both of them.
///
/// Asked rather than measured. `DeviceActivityReport` could read the real
/// figure, but only inside its own extension, which cannot hand the number back
/// to the app — the whole point of that API is that usage data never leaves the
/// report. Three buckets someone picks in a second are worth more than an exact
/// figure the app can never see.
enum ScreenTimeBand: Int, CaseIterable, Codable {
    case upToThree = 0
    case threeToSix
    case overSix

    var title: String {
        switch self {
        case .upToThree: return "Up to 3 hours"
        case .threeToSix: return "3 to 6 hours"
        case .overSix: return "More than 6 hours"
        }
    }

    /// The same answer as it reads inside a sentence, where the button's own
    /// wording ("Up to 3 hours") turns into "the up to 3 hours you started at".
    var phrase: String {
        switch self {
        case .upToThree: return "under 3 hours a day"
        case .threeToSix: return "3 to 6 hours a day"
        case .overSix: return "over 6 hours a day"
        }
    }

    var detail: String {
        switch self {
        case .upToThree: return "A habit, not a hole. There is less to give back."
        case .threeToSix: return "The usual answer, and the hardest one to admit."
        case .overSix: return "Most of a working day. Coming down is worth more here."
        }
    }

    /// The figure the rungs are cut from.
    ///
    /// A single number per band rather than the range itself, because a ladder
    /// that shifted continuously with a slider would make two people's Blazes
    /// incomparable and invite gaming the one input nobody can check. Picked at
    /// the middle of the two bounded bands, and a shade above the floor of the
    /// open-ended one — someone answering "more than six" is rarely at six.
    var baselineMinutes: Int {
        switch self {
        case .upToThree: return 120
        case .threeToSix: return 240
        case .overSix: return 420
        }
    }

    /// What the top rung asks of someone in this band, for the sheet to show.
    /// A ladder is easier to agree to when the hardest rung is named up front.
    var topRungMinutes: Int {
        StreakLevel.blueFlame.ceiling(baseline: baselineMinutes) ?? 0
    }

    /// Used until the question has been answered.
    ///
    /// The middle band on purpose: its rungs are within a minute of the fixed
    /// ladder this replaced, so nobody who never answers sees their flame move.
    static let unanswered = ScreenTimeBand.threeToSix

    /// The band a stored baseline came from, for showing which one is chosen.
    /// Falls to the nearest band rather than failing, so a figure written by a
    /// build with different numbers still lands somewhere sensible.
    static func band(forBaselineMinutes minutes: Int) -> ScreenTimeBand {
        allCases.min { a, b in
            abs(a.baselineMinutes - minutes) < abs(b.baselineMinutes - minutes)
        } ?? unanswered
    }
}
