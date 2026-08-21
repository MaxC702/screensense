import SwiftUI

/// The streak's own tab: where it stands, how it got there, and what moves it.
///
/// The flame on the home screen is a single number, and a single number cannot
/// show a habit changing. The graph can — which is the reason this is a tab and
/// not the sheet it started as.
struct StreakView: View {
    @EnvironmentObject private var model: AppModel

    /// Two weeks. Long enough to show a habit turning, short enough that each
    /// day still gets width worth drawing on a phone.
    private let window = 14

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

            if model.isRelighting {
                Text("Relighting — \(model.daysToRelight) more day\(model.daysToRelight == 1 ? "" : "s") back to \(model.earnedStreakLevel.name).")
                    .font(.system(size: 11.5))
                    .foregroundColor(Theme.muted)
            }
        }
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
                .frame(height: 168)

            Text(graphCaption(points))
                .font(.system(size: 11))
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// A graph of five flat points explains nothing, so until there is a shape
    /// to read the caption says what will make one.
    private func graphCaption(_ points: [AppModel.DayPoint]) -> String {
        let drawn = points.filter { $0.level != nil }.count
        guard drawn > 1 else {
            return "The line rises as you unblock less. Come back tomorrow and it will have somewhere to go."
        }
        return "Higher is stricter. A day you spent no breaks sits at the top; a day you spent the lot sits at the bottom."
    }

    // MARK: - Where the level comes from

    private var sourceCard: some View {
        Card {
            if let average = model.averageUnblockedMinutes {
                HStack(spacing: 10) {
                    Text(minutes(average))
                        .font(Theme.display(26, .demiBold))
                        .monospacedDigit()
                    VStack(alignment: .leading, spacing: 0) {
                        Text("min a day").font(.system(size: 11.5)).foregroundColor(Theme.muted)
                        Text("averaged, finished days").font(.system(size: 9.5)).foregroundColor(Theme.faint)
                    }
                    Spacer()
                    pill(model.earnedStreakLevel)
                }
                Text("What you actually unblocked, not what you allowed yourself. Today's \(model.minutesUsedToday) min joins the average tomorrow.")
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
                        Text("your budget, for now").font(.system(size: 9.5)).foregroundColor(Theme.faint)
                    }
                    Spacer()
                    pill(model.configuredStreakLevel)
                }
                Text("No finished days yet, so the flame goes by what you set. From tomorrow it goes by what you spend.")
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
