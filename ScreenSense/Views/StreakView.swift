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
        NavigationStack {
            ScrollView {
                VStack(spacing: 13) {
                    hero
                    graphCard
                    sourceCard
                    rules
                }
                .padding(.horizontal, 17)
                .padding(.bottom, 17)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Streak")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(Theme.accentSoft)
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

        return Card {
            HStack(spacing: 12) {
                StreakFlame(size: 30, lit: days > 0, broken: model.streakBrokenToday, tint: level.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(heroTitle)
                        .font(Theme.display(24, .medium))
                        .monospacedDigit()
                    Text(heroSubtitle)
                        .font(.system(size: 12.5))
                        .foregroundColor(days > 0 ? level.tint : Theme.muted)
                }
                Spacer()
            }

            StreakLadder(level: level, target: model.earnedStreakLevel)

            if let charge = model.levelCharge, days > 0 {
                HStack(spacing: 9) {
                    LevelBattery(charge: charge, tint: level.tint, size: CGSize(width: 9, height: 21))
                    Text(chargeCaption)
                        .font(.system(size: 11.5))
                        .foregroundColor(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }

            if model.isRelighting {
                Text("Relighting — \(model.daysToRelight) more day\(model.daysToRelight == 1 ? "" : "s") back to \(model.earnedStreakLevel.name).")
                    .font(.system(size: 11.5))
                    .foregroundColor(Theme.muted)
            }
        }
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

    private var graphCard: some View {
        let points = model.dailyLevels(days: window)

        return Card {
            HStack {
                Text("Last \(window) days").font(Theme.display(15, .medium))
                Spacer()
                Text("each day's level")
                    .font(.system(size: 10.5))
                    .foregroundColor(Theme.faint)
            }

            StreakGraph(points: points)
                .frame(height: 186)

            // No caption. The rungs are named down the side and the days are
            // named along the bottom, which is the whole of what a sentence
            // under it used to say.
            if points.allSatisfy({ $0.level == nil }) {
                Text("Nothing to plot yet — the line starts once a day is behind you.")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - What the rungs are cut from

    /// The rungs are a share of what these apps used to take, so the figure they
    /// are a share *of* has to be visible and changeable. Sat under the card that
    /// explains the level rather than buried in Settings, which is the screen for
    /// what you are allowed rather than for what you are measured against.
    private var baselineRow: some View {
        Button { isAskingBaseline = true } label: {
            HStack(spacing: 7) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.faint)
                Text(model.hasChosenBaseline
                     ? "Scaled to \(model.baselineBand.phrase)"
                     : "Scaled to a guess — say what you were on")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.muted)
                Spacer(minLength: 0)
                Text(model.hasChosenBaseline ? "Change" : "Answer")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.accentSoft)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Where the level comes from

    private var sourceCard: some View {
        Card {
            if let average = model.averageUnblockedMinutes {
                let counted = min(model.streakDays, window)
                HStack(spacing: 10) {
                    Text(minutes(average))
                        .font(Theme.display(26, .demiBold))
                        .monospacedDigit()
                    VStack(alignment: .leading, spacing: 0) {
                        Text("min a day").font(.system(size: 11.5)).foregroundColor(Theme.muted)
                        Text(counted == 1 ? "today so far" : "averaged over \(counted) days")
                            .font(.system(size: 9.5))
                            .foregroundColor(Theme.faint)
                    }
                    Spacer()
                    pill(model.earnedStreakLevel)
                }
                Text("What you actually unblocked, not what you allowed yourself. Today counts as it goes — \(model.minutesUsedToday) min so far, and ending a break early costs you less of it.")
                    .font(.system(size: 11.5))
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(spacing: 10) {
                    Text("\(model.dailyUnblockedMinutes)")
                        .font(Theme.display(26, .demiBold))
                        .monospacedDigit()
                    VStack(alignment: .leading, spacing: 0) {
                        Text("min a day").font(.system(size: 11.5)).foregroundColor(Theme.muted)
                        Text("your budget, at most").font(.system(size: 9.5)).foregroundColor(Theme.faint)
                    }
                    Spacer()
                    pill(model.configuredStreakLevel)
                }
                Text(model.streakBrokenToday
                     ? "A lost run costs the rest of the day, so there is nothing here to average yet. The flame relights on tomorrow's minutes."
                     : "Nothing running to measure. Switch blocking on and the flame follows what you actually spend.")
                    .font(.system(size: 11.5))
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(ladderNote)
                .font(.system(size: 11))
                .foregroundColor(Theme.faint)
                .fixedSize(horizontal: false, vertical: true)

            Divider().overlay(Theme.hairline)
            baselineRow
        }
    }

    // MARK: - What it costs

    private var rules: some View {
        Card {
            fact("checkmark.circle.fill", "Breaks don't cost the streak — only the minutes count.", tint: Theme.accentSoft)
            fact(
                "power",
                "Turning blocking off does: the day is spent, the count restarts tomorrow, and the flame drops a rung. \(StreakLevel.relightDays) days of blocking wins the rung back.",
                tint: .orange
            )
            if model.bestStreak > 0 {
                fact("trophy.fill", "Best run: \(model.bestStreak) days.", tint: Theme.streak)
            }
        }
    }

    // MARK: - Pieces

    private func minutes(_ value: Double) -> String {
        value < 10 ? String(format: "%.1f", value) : "\(Int(value.rounded()))"
    }

    /// Spells out what the rung on show currently costs in minutes. The number
    /// moves with the baseline, so leaving it implicit would make the ladder look
    /// like it had changed its mind.
    private var ladderNote: String {
        let level = model.earnedStreakLevel
        guard let ceiling = level.ceiling(baseline: model.baselineMinutes) else {
            return "Ember is the bottom of the ladder — there is nothing below it to fall to."
        }
        return "\(level.name) is \(ceiling) min a day or less, cut from a starting point of \(model.baselineBand.phrase)."
    }

    private func pill(_ level: StreakLevel) -> some View {
        Text(level.name)
            .font(.system(size: 10.5, weight: .bold))
            .foregroundColor(level.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(level.tint.opacity(0.16), in: Capsule())
    }

    private func fact(_ symbol: String, _ text: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12.5))
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
