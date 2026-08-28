import Foundation

/// How demanding the budget behind a streak is, as a five-step ladder.
///
/// A streak is only worth what it costs to keep. Three 5-minute breaks a day
/// leaves 15 minutes of unblocked time; three 10-minute breaks leaves twice
/// that, and five 5-minute breaks leaves nearly twice that — all for the same
/// unbroken run of days. The level is what tells those runs apart.
///
/// Derived from `BreakSettings` rather than stored, so there is no fourth thing
/// for the four processes to keep in sync and nothing to migrate. The cost of
/// that choice is that tightening the budget promotes an already-running streak
/// on the spot, rather than only counting from the next day. That is the right
/// trade for an app whose whole purpose is to make asking more of yourself feel
/// worth doing.
enum StreakLevel: Int, CaseIterable, Comparable {
    case ember = 0
    case flame
    case blaze
    case whiteHeat
    case blueFlame

    /// Names climb the heat a real fire does, which is also the order the tints
    /// climb: dull red, amber, gold, white, blue.
    var name: String {
        switch self {
        case .ember: return "Ember"
        case .flame: return "Flame"
        case .blaze: return "Blaze"
        case .whiteHeat: return "White heat"
        case .blueFlame: return "Blue flame"
        }
    }

    /// What fraction of a day's old usage this level tolerates.
    ///
    /// `nil` for Ember, which is the bottom of the ladder and catches everything
    /// looser than Flame — including the 150 minutes a day that five 30-minute
    /// breaks come to.
    ///
    /// A share rather than a number of minutes, because the same forty minutes
    /// is a triumph for one person and barely a dent for another. Fifths, tenths
    /// and twentieths are coarse on purpose: the baseline behind them is a
    /// bucket someone picked in a second, and cutting it any finer would be
    /// arithmetic pretending to be measurement.
    var share: Double? {
        switch self {
        case .ember: return nil
        case .flame: return 0.20
        case .blaze: return 0.10
        case .whiteHeat: return 0.05
        case .blueFlame: return 0.02
        }
    }

    /// Most unblocked minutes a day this level tolerates, for someone who used
    /// to spend `baseline` minutes a day in these apps.
    ///
    /// Never returns zero: a rung nobody can reach is not a rung, and rounding
    /// alone should not be able to close one off for a light user.
    func ceiling(baseline: Int) -> Int? {
        guard let share else { return nil }
        return max(1, Int((Double(baseline) * share).rounded()))
    }

    var next: StreakLevel? { StreakLevel(rawValue: rawValue + 1) }
    /// The looser rung, the one a level falls to. `nil` at the bottom.
    var previous: StreakLevel? { StreakLevel(rawValue: rawValue - 1) }

    // MARK: - Position within a rung

    /// The strict end of this level's band — the ceiling of the rung above it,
    /// which is the point at which you stop being this level and start being a
    /// better one. Zero for the top rung, which has nowhere further to go.
    func floor(baseline: Int) -> Int { next?.ceiling(baseline: baseline) ?? 0 }

    /// How much is left in the tank at `minutes` a day: 1 at the strict end of
    /// the band, 0 sitting on the ceiling with one more minute about to cost a
    /// rung.
    ///
    /// Ember reads full, because Ember is the floor of the ladder and there is
    /// nothing under it to fall to. The gauge measures the drop, and at the
    /// bottom there is no drop — the dull red it is drawn in is what says this
    /// is not somewhere to be pleased about being.
    func chargeFraction(atDailyMinutes minutes: Double, baseline: Int) -> Double {
        guard let ceiling = ceiling(baseline: baseline) else { return 1 }
        let span = Double(ceiling - floor(baseline: baseline))
        guard span > 0 else { return 1 }
        return min(1, max(0, (Double(ceiling) - minutes) / span))
    }

    /// Minutes a day that could still be spent before this level gives way;
    /// `nil` at the bottom, where nothing gives way.
    func headroom(atDailyMinutes minutes: Double, baseline: Int) -> Double? {
        guard let ceiling = ceiling(baseline: baseline) else { return nil }
        return max(0, Double(ceiling) - minutes)
    }

    // MARK: - Losing a run

    /// Days of a new run needed to burn off what a lost one leaves behind.
    ///
    /// Short on purpose. The penalty exists to make a loss register, not to put
    /// the ladder out of reach — three days is long enough to be felt and near
    /// enough to be worth starting.
    static let relightDays = 3

    /// A run has to have survived a midnight before losing it costs a rung.
    ///
    /// Switching blocking on and straight off again while picking apps is not a
    /// lost streak, and docking someone for it would make the ladder look
    /// arbitrary the very first time they touched it.
    static let minimumRunToPenalise = 2

    /// This level with `rungs` knocked off, floored at the bottom of the ladder.
    func lowered(by rungs: Int) -> StreakLevel {
        guard rungs > 0 else { return self }
        return StreakLevel(rawValue: max(0, rawValue - rungs)) ?? .ember
    }

    /// The whole basis of the ladder: breaks per day times how long each one
    /// runs. Deliberately ignores the wait between breaks, which changes how
    /// the time is *shaped* but not how much of it there is — folding it in
    /// would buy a little more fairness at the price of a rule nobody could
    /// work out from the numbers on the screen.
    static func dailyMinutes(for settings: BreakSettings) -> Int {
        settings.breaksPerDay * settings.breakMinutes
    }

    /// The tightest ceiling a figure of unblocked minutes a day still fits under.
    static func level(forDailyMinutes minutes: Double, baseline: Int) -> StreakLevel {
        allCases.reversed().first { level in
            guard let ceiling = level.ceiling(baseline: baseline) else { return true }
            return minutes <= Double(ceiling)
        } ?? .ember
    }

    /// What the budget alone is worth — the level you would sit at if you spent
    /// every minute you allowed yourself. The floor under the earned level, and
    /// what a brand new streak is judged by until it has a finished day on the
    /// board.
    static func level(for settings: BreakSettings) -> StreakLevel {
        level(
            forDailyMinutes: Double(dailyMinutes(for: settings)),
            baseline: settings.effectiveBaselineMinutes
        )
    }

    /// Minutes a day that would have to come off the budget to reach the next
    /// level up; `nil` at the top, where there is nothing left to reach.
    static func minutesToNextLevel(from settings: BreakSettings) -> Int? {
        guard
            let next = level(for: settings).next,
            let ceiling = next.ceiling(baseline: settings.effectiveBaselineMinutes)
        else { return nil }
        return max(1, dailyMinutes(for: settings) - ceiling)
    }

    static func < (lhs: StreakLevel, rhs: StreakLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
