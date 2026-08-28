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
    case underTwo = 0
    case twoToThree
    case threeToSix
    case overSix

    var title: String {
        switch self {
        case .underTwo: return "Under 2 hours"
        case .twoToThree: return "2 to 3 hours"
        case .threeToSix: return "3 to 6 hours"
        case .overSix: return "More than 6 hours"
        }
    }

    /// The same answer as it reads inside a sentence, where the button's own
    /// wording ("Up to 3 hours") turns into "the up to 3 hours you started at".
    var phrase: String {
        switch self {
        case .underTwo: return "under 2 hours a day"
        case .twoToThree: return "2 to 3 hours a day"
        case .threeToSix: return "3 to 6 hours a day"
        case .overSix: return "over 6 hours a day"
        }
    }

    /// The figure the rungs are cut from.
    ///
    /// A single number per band rather than the range itself, because a ladder
    /// that shifted continuously with a slider would make two people's Blazes
    /// incomparable and invite gaming the one input nobody can check. Picked
    /// towards the top of each bounded band — someone who has gone as far as
    /// installing a blocker is rarely at the floor of the answer they gave — and
    /// a shade above the floor of the open-ended one for the same reason.
    ///
    /// These are identifiers as much as figures: the ladder itself is a table
    /// per band, and this is only what gets stored and mapped back. They are
    /// spaced so that 120 — every answer of the old three-band "up to 3 hours" —
    /// still lands on `twoToThree` rather than being quietly demoted onto the
    /// stricter ladder that now sits underneath it.
    var baselineMinutes: Int {
        switch self {
        case .underTwo: return 80
        case .twoToThree: return 150
        case .threeToSix: return 240
        case .overSix: return 420
        }
    }

    /// Most unblocked minutes a day each rung tolerates, Flame first and Blue
    /// flame last. Ember is everything looser than the first number.
    ///
    /// A hand-set table rather than one percentage applied to everybody, because
    /// a flat share cannot be right at both ends of the ladder at once. The
    /// lower rungs *should* scale with where you started — forty minutes is a
    /// failure from two hours and a real gain from seven, which is the whole
    /// point of asking. The top rung should not. Someone down to ten minutes a
    /// day has effectively stopped, and that is equally true whether they came
    /// from two hours or seven; scaling it would have put Blue flame at two
    /// minutes a day for a light user, which is not a rung, it is a taunt.
    ///
    /// So the bands fan out at the bottom and converge at the top: 22 through 90
    /// for Flame, but 6 through 12 for Blue flame. The ladder still says a heavy
    /// user's forty minutes is worth more — it just stops pretending the summit
    /// is a different mountain for each of them.
    var rungCeilings: [Int] {
        switch self {
        case .underTwo: return [22, 14, 10, 6]
        case .twoToThree: return [35, 22, 14, 8]
        case .threeToSix: return [60, 35, 20, 10]
        case .overSix: return [90, 50, 28, 12]
        }
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
