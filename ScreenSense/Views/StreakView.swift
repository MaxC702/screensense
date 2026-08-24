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
    }

    // MARK: - Hero

    private var hero: some View {
        let days = model.streakDays
        let level = model.streakLevel

        return Card {
            HStack(spacing: 12) {
                Image(systemName: days > 0 ? "flame.fill" : "flame")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(days > 0 ? level.tint : Theme.faint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(days > 0 ? "\(days) day\(days == 1 ? "" : "s")" : "No streak yet")
                        .font(Theme.display(24, .medium))
                        .monospacedDigit()
                    Text(days > 0 ? "at \(level.name)" : "Switch blocking on to start one")
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
                Text("Nothing running to measure. Switch blocking on and the flame follows what you actually spend.")
                    .font(.system(size: 11.5))
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - What it costs

    private var rules: some View {
        Card {
            fact("checkmark.circle.fill", "Breaks don't cost the streak — only the minutes count.", tint: Theme.accentSoft)
            fact(
                "power",
                "Turning blocking off does: the days reset and the flame drops a rung. \(StreakLevel.relightDays) days of blocking wins the rung back.",
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
