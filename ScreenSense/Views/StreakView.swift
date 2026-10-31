import SwiftUI

/// The streak's own tab: where it stands, how it got there, and what moves it.
///
/// The flame on the home screen is a single number, and a single number cannot
/// show a habit changing. The graph can — which is the reason this is a tab and
/// not the sheet it started as.
struct StreakView: View {
    @EnvironmentObject private var model: AppModel

    /// A week, which is also the window the level is averaged over — so the
    /// graph shows exactly the days the flame is currently being judged on, and
    /// leaves each of them enough width to be labelled and read individually.
    private let window = 7

    @State private var isAskingBaseline = false
    /// Asked at most once per launch. The sheet is dismissible, and re-opening
    /// it every time this tab is touched would turn one question into nagging.
    @State private var hasOfferedBaseline = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenTitle("Streak")
                hero
                graphSection
                sourceSection
                rules
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear {
            guard !model.hasChosenBaseline, !hasOfferedBaseline else { return }
            hasOfferedBaseline = true
            isAskingBaseline = true
        }
        .sheet(isPresented: $isAskingBaseline) {
            BaselineSheet().environmentObject(model)
        }
    }

    // MARK: - Hero

    private var hero: some View {
        let days = model.streakDays
        let level = model.streakLevel

        return VStack(alignment: .leading, spacing: 0) {
            if days > 0 {
                // The number is the page's headline; what it is a number *of*
                // sits beside it rather than above, so it reads as one phrase.
                HStack(alignment: .bottom, spacing: 12) {
                    Text("\(days)")
                        .font(Theme.numeral(88))
                        .padding(.bottom, -10)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(days == 1 ? "day" : "days")
                            .foregroundColor(Theme.foreground)
                        HStack(spacing: 4) {
                            StreakFlame(size: 13, lit: true, tint: level.tint)
                            Text(heroSubtitle)
                        }
                        .foregroundColor(level.tint)
                    }
                    .font(.system(size: 15))
                    .padding(.bottom, 4)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(days) day \(level.name) streak")
            } else {
                HStack(alignment: .center, spacing: 14) {
                    StreakFlame(size: 30, lit: false, broken: model.streakBrokenToday)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(heroTitle)
                            .font(Theme.display(28))
                        Text(heroSubtitle)
                            .font(.system(size: 15))
                            .foregroundColor(Theme.muted)
                    }
                }
            }

            StreakLadder(level: level, target: model.earnedStreakLevel)
                .padding(.top, 24)

            if days > 0 {
                Text(chargeCaption)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
            }

            if model.isRelighting {
                Text("Relighting — \(model.daysToRelight) more day\(model.daysToRelight == 1 ? "" : "s") back to \(model.earnedStreakLevel.name).")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.muted)
                    .padding(.top, 6)
            }
        }
        .padding(.top, 8)
    }

    /// The day a run is lost is not a day with no streak on it — it is a day
    /// with a streak *missing* from it, and the difference is the whole point of
    /// holding the count at zero until midnight.
    private var heroTitle: String {
        if model.streakDays > 0 { return "\(model.streakDays) day\(model.streakDays == 1 ? "" : "s")" }
        return model.streakBrokenToday ? "Streak broken" : "No streak yet"
    }

    private var heroSubtitle: String {
        if model.streakDays > 0 { return "at \(model.streakLevel.name)" }
        guard model.streakBrokenToday else { return "Switch blocking on to start one" }
        return model.state.blockingEnabled
            ? "Day 1 starts tomorrow"
            : "Switch blocking on; day 1 starts tomorrow"
    }

    /// Says what the gauge in the badge means, in the one place there is room to.
    private var chargeCaption: String {
        guard let headroom = model.levelHeadroom, let below = model.streakLevel.previous else {
            return "Nothing below \(model.streakLevel.name) to drop to."
        }
        let room = headroom < 10 ? String(format: "%.1f", headroom) : "\(Int(headroom.rounded()))"
        return "\(room) more min a day and \(model.streakLevel.name) gives way to \(below.name)."
    }

    // MARK: - Graph

    private var graphSection: some View {
        let points = model.dailyLevels(days: window)

        return VStack(alignment: .leading, spacing: 0) {
            SectionLabel("Last \(window) days")
            Rule()

            StreakGraph(points: points, current: model.streakLevel)
                .frame(height: 156)
                .padding(.top, 20)

            // No caption. The rungs are named down the side and the days are
            // named along the bottom, which is the whole of what a sentence
            // under it used to say.
            if points.allSatisfy({ $0.level == nil }) {
                Text("Nothing to plot yet — the line starts once a day is behind you.")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.faint)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
            }
        }
        .padding(.top, 48)
    }

    // MARK: - What the rungs are cut from

    /// The rungs are a share of what these apps used to take, so the figure they
    /// are a share *of* has to be visible and changeable. Sat under the card that
    /// explains the level rather than buried in Settings, which is the screen for
    /// what you are allowed rather than for what you are measured against.
    private var baselineRow: some View {
        BaselineRow(band: model.baselineBand, hasChosen: model.hasChosenBaseline) {
            isAskingBaseline = true
        }
    }

    // MARK: - Where the level comes from

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("Daily average")
            Rule()

            Group {
                if let average = model.averageUnblockedMinutes {
                    let counted = min(model.streakDays, window)
                    figure(
                        minutes(average),
                        counted == 1 ? "min a day, today so far" : "min a day, over \(counted) days",
                        level: model.earnedStreakLevel
                    )
                    paragraph("What you actually unblocked, not what you allowed yourself. Today counts as it goes — \(model.minutesUsedToday) min so far, and ending a break early costs you less of it.")
                    // Otherwise the minutes and the level beside them can look
                    // as if they disagree with the ladder note underneath, which
                    // is read on the band set now.
                    if model.weekSpansBaselineChange {
                        paragraph("Days before you changed where you started keep the level they earned then.")
                    }
                } else {
                    figure("\(model.dailyUnblockedMinutes)", "min a day, your budget at most", level: model.configuredStreakLevel)
                    paragraph(model.streakBrokenToday
                              ? "A lost run costs the rest of the day, so there is nothing here to average yet. The flame relights on tomorrow's minutes."
                              : "Nothing running to measure. Switch blocking on and the flame follows what you actually spend.")
                }
            }
            .padding(.top, 20)

            Text(ladderNote)
                .font(.system(size: 13))
                .lineSpacing(2)
                .foregroundColor(Theme.faint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            RuledList {
                baselineRow.ruledRow(padding: 14)
            }
            .padding(.top, 20)

            if let harder = model.harderBand {
                Label(
                    "Blue flame for \(model.daysAtSummit) days — too easy now. Tap Change and pick \(harder.title.lowercased()): Blue flame would then mean cutting \(summitDrop(to: harder)) more minutes a day, down to \(StreakLevel.blueFlame.ceiling(band: harder) ?? 0) from \(StreakLevel.blueFlame.ceiling(band: model.baselineBand) ?? 0).",
                    systemImage: "arrow.up.right"
                )
                .font(.system(size: 13))
                .foregroundColor(Theme.foreground)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
            }
        }
        .padding(.top, 48)
    }

    // MARK: - What it costs

    private var rules: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("How it works")
            Rule()

            VStack(alignment: .leading, spacing: 16) {
                fact("cup.and.saucer", "Breaks don't cost the streak — only the minutes count.")
                fact(
                    "power",
                    "Turning blocking off does: the day is spent, the count restarts tomorrow, and the flame drops a rung. \(StreakLevel.relightDays) days of blocking wins the rung back."
                )
                if model.bestStreak > 0 {
                    fact("trophy", "Best run: \(model.bestStreak) day\(model.bestStreak == 1 ? "" : "s").")
                }
            }
            .padding(.top, 20)
        }
        .padding(.top, 48)
    }

    // MARK: - Pieces

    private func minutes(_ value: Double) -> String {
        value < 10 ? String(format: "%.1f", value) : "\(Int(value.rounded()))"
    }

    /// Minutes a day that would have to come *off* to hold Blue flame on a
    /// harder band. Named as a cut rather than left for the reader to subtract:
    /// "Blue flame would need 35 min a day" can be read as thirty-five *more*,
    /// which says the opposite of what is meant.
    private func summitDrop(to harder: ScreenTimeBand) -> Int {
        let here = StreakLevel.blueFlame.ceiling(band: model.baselineBand) ?? 0
        let there = StreakLevel.blueFlame.ceiling(band: harder) ?? 0
        return max(0, here - there)
    }

    /// Spells out what the rung on show currently costs in minutes. The number
    /// moves with the baseline, so leaving it implicit would make the ladder look
    /// like it had changed its mind.
    private var ladderNote: String {
        let level = model.earnedStreakLevel
        guard let ceiling = level.ceiling(baseline: model.baselineMinutes) else {
            return "Ember is the bottom of the ladder — there is nothing below it to fall to."
        }
        return "\(level.name) means \(ceiling) min a day or less for a starting point of \(model.baselineBand.phrase)."
    }

    /// The average, big, with what it is an average of and the level it earns
    /// beside it — the level named in its own colour rather than boxed, since
    /// the colour is the label.
    private func figure(_ value: String, _ unit: String, level: StreakLevel) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(value)
                .font(Theme.numeral(44))
            Text(unit)
                .font(.system(size: 15))
                .foregroundColor(Theme.muted)
            Spacer(minLength: 4)
            Text(level.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(level.tint)
        }
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .lineSpacing(3)
            .foregroundColor(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 14)
    }

    private func fact(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundColor(Theme.faint)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 14))
                .lineSpacing(2)
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
