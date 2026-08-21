import SwiftUI

/// What the flame in the header actually means.
///
/// The badge is a number and a colour, and neither of those says what earns it
/// or what costs it. Nobody goes hunting through settings to find out what a
/// badge is — they tap the badge. So tapping the badge is what opens this.
///
/// Three questions, in the order someone actually asks them: what am I looking
/// at, how do I make it better, and what breaks it.
struct StreakInfoView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 13) {
                    hero
                    whatItIs
                    howItLevelsUp
                    howItIsLost
                }
                .padding(.horizontal, 17)
                .padding(.bottom, 17)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Your streak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
        .tint(Theme.accentSoft)
    }

    // MARK: - Hero

    /// The same flame, the same number, the same ladder as the screen behind —
    /// so it is obvious this sheet is about the thing that was just tapped.
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
                    Text(days > 0
                         ? "at \(level.name)"
                         : "Switch blocking on to start one")
                        .font(.system(size: 12.5))
                        .foregroundColor(days > 0 ? level.tint : Theme.muted)
                }
                Spacer()
            }

            StreakLadder(level: level, target: model.configuredStreakLevel)

            if model.isRelighting {
                paragraph("Relighting. A lost run cost you a rung — \(model.daysToRelight) more day\(model.daysToRelight == 1 ? "" : "s") of blocking and the ghosted rung above comes back to \(model.configuredStreakLevel.name).")
            }
        }
    }

    // MARK: - The three questions

    private var whatItIs: some View {
        infoCard(symbol: "calendar", title: "What it is") {
            paragraph("Days in a row you have left blocking switched on, counting today.")
            paragraph("It starts the moment you turn blocking on, and goes up at midnight. Closing the app, restarting your phone, or not opening ScreenBlock for a week costs you nothing — the count is worked out from the day it started, not from anything you have to come back and do.")
        }
    }

    private var howItLevelsUp: some View {
        infoCard(symbol: "flame.fill", title: "How it heats up") {
            paragraph("The number is days. The colour is difficulty — and difficulty comes from your break budget, not from how long you have kept it up.")

            // The arithmetic spelled out with this user's own numbers, because
            // the rule is only obvious once you have seen it done once.
            sum

            paragraph("Fewer unblocked minutes a day means a hotter flame. \(nextLevelHint)")
            paragraph("Tightening the budget promotes the run you are already on — you never start over for asking more of yourself.")
        }
    }

    private var howItIsLost: some View {
        infoCard(symbol: "exclamationmark.triangle.fill", title: "How it's lost") {
            paragraph("One thing resets it to zero: switching \u{201C}Block these apps\u{201D} off in Settings.")
            paragraph("Losing a run of \(StreakLevel.minimumRunToPenalise) days or more costs you a rung on the ladder as well as the days. \(StreakLevel.relightDays) days of blocking earns it back — the debt is paid in days, not in waiting, so it can't be sat out with blocking switched off.")
            paragraph("Spending a break does not cost either of them. Breaks are the sanctioned way through the block — charging your streak for using one would only push you towards the switch instead, and that removes the block entirely.")

            if model.bestStreak > 0 {
                paragraph("Your best run so far is \(model.bestStreak) day\(model.bestStreak == 1 ? "" : "s"). Losing a streak keeps that number, so there is always something to beat.")
            } else {
                paragraph("Your longest run is kept even after a streak ends, so there is always something to beat.")
            }
        }
    }

    // MARK: - Pieces

    /// breaks × length = minutes, laid out as the equation it is.
    private var sum: some View {
        let level = model.configuredStreakLevel

        return HStack(spacing: 8) {
            factor("\(model.settings.breaksPerDay)", "breaks")
            symbol("×")
            factor("\(model.settings.breakMinutes)", "min each")
            symbol("=")
            factor("\(model.dailyUnblockedMinutes)", "min a day")

            Spacer(minLength: 4)

            Text(level.name)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundColor(level.tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(level.tint.opacity(0.16), in: Capsule())
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 13)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(model.settings.breaksPerDay) breaks of \(model.settings.breakMinutes) minutes is \(model.dailyUnblockedMinutes) unblocked minutes a day, which is \(level.name)")
    }

    private func factor(_ value: String, _ caption: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(Theme.display(17, .demiBold))
                .monospacedDigit()
            Text(caption)
                .font(.system(size: 9))
                .foregroundColor(Theme.faint)
        }
    }

    private func symbol(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Theme.faint)
    }

    private var nextLevelHint: String {
        guard let next = model.configuredStreakLevel.next, let shed = model.minutesToNextLevel else {
            return "You are at the top of the ladder — nothing is stricter than this."
        }
        return "\(shed) fewer minute\(shed == 1 ? "" : "s") a day would reach \(next.name)."
    }

    private func infoCard<Body: View>(
        symbol: String,
        title: String,
        @ViewBuilder body: () -> Body
    ) -> some View {
        Card {
            HStack(spacing: 10) {
                IconTile(symbol: symbol)
                Text(title).font(Theme.display(15, .medium))
                Spacer()
            }
            body()
        }
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12.5))
            .foregroundColor(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
