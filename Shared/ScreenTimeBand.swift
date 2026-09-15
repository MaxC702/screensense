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

    /// The one scale every band's rungs are cut from, loosest first.
    ///
    /// Each step is roughly half again the one below it, which is what makes the
    /// difference between rungs feel like a difference. Minutes are not linear
    /// in effort: going from 80 a day to 55 is a smaller act of will than going
    /// from 20 to 10, and a ladder with even spacing would have priced those the
    /// same.
    private static let scale = [10, 20, 35, 55, 80, 110, 140]

    /// Most unblocked minutes a day each rung tolerates, Flame first and Blue
    /// flame last. Ember is everything looser than the first number.
    ///
    /// Each band is a four-rung window onto `scale`, slid one step further out
    /// for every band up. That is the whole design: **stepping down a band makes
    /// every rung exactly one rung harder**, and the summit of one difficulty is
    /// the middle of the next one down.
    ///
    /// An earlier version converged the top rungs — 6, 8, 10, 12 across the four
    /// bands — on the reasoning that ten minutes a day is quitting no matter
    /// where you came from. That reasoning was sound and the result was useless:
    /// two minutes between one person's summit and another's is not a difference
    /// anybody can feel, and it made the bands cosmetic. Somebody dropping from
    /// six hours to under one has done an enormous thing and should be told so,
    /// and Blue flame for them is 55 minutes a day, not 12.
    ///
    /// What stops that being a gift is the next paragraph of the design rather
    /// than a number: reaching Blue flame is the signal to move down a band. The
    /// easiest ladder is meant to be beaten and left. Only `underTwo` is a place
    /// to stay, and its Blue flame — ten minutes a day — is the real summit.
    var rungCeilings: [Int] {
        // Flame, Blaze, White heat, Blue flame: the window read outwards-in.
        let top = rawValue + 3
        return (0...3).map { ScreenTimeBand.scale[top - $0] }
    }

    /// Where `minutes` a day on this ladder would sit on `other`: the same rung,
    /// the same distance through it.
    ///
    /// This is what lets a day keep the level it earned after the ladder under
    /// it has changed. Changing band is a decision about today, so a week of
    /// Blaze stays a week of Blaze — but the flame averages *minutes*, and
    /// yesterday's minutes read against today's ceilings would land a rung off.
    /// Moved across first, they average as what they were.
    ///
    /// Piecewise across the rungs rather than a single ratio, because the bands
    /// are not scaled copies of each other and a ratio would carry a day over a
    /// rung boundary. Ember has no ceiling to measure through, so above Flame
    /// the Flame ceilings alone set the scale.
    func equivalentMinutes(_ minutes: Double, on other: ScreenTimeBand) -> Double {
        guard other != self else { return minutes }
        // Blue flame's floor, then each ceiling on the way down to Flame.
        let from = [0] + rungCeilings.reversed()
        let to = [0] + other.rungCeilings.reversed()
        for index in 1..<from.count where minutes <= Double(from[index]) {
            let through = (minutes - Double(from[index - 1])) / Double(from[index] - from[index - 1])
            return Double(to[index - 1]) + through * Double(to[index] - to[index - 1])
        }
        return minutes * Double(to[to.count - 1]) / Double(from[from.count - 1])
    }

    /// The next difficulty up, which is the band *below* this one — the ladder
    /// gets harder as the starting point gets lighter. `nil` at `underTwo`,
    /// where there is nothing left to graduate to.
    var harder: ScreenTimeBand? { ScreenTimeBand(rawValue: rawValue - 1) }

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
