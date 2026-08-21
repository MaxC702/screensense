import SwiftUI

/// What the flame in the header means, in as few lines as it can be said.
///
/// Most of it is guessable. A streak is days in a row, and anyone who has seen
/// one before knows it goes back to nothing when you break it. What cannot be
/// guessed is where the colour comes from and what the switch costs — so that is
/// all this says, and it says it once.
struct StreakInfoView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 13) {
                    hero
                    budget
                    rules
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

    /// The same flame, number and ladder as the screen behind, so it is obvious
    /// this is about the thing that was just tapped.
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

            StreakLadder(level: level, target: model.configuredStreakLevel)

            if model.isRelighting {
                Text("Relighting — \(model.daysToRelight) more day\(model.daysToRelight == 1 ? "" : "s") back to \(model.configuredStreakLevel.name).")
                    .font(.system(size: 11.5))
                    .foregroundColor(Theme.muted)
            }
        }
    }

    // MARK: - Where the colour comes from

    /// The one thing nobody works out on their own: the flame's colour is set by
    /// the budget, not by the days. Shown as the arithmetic rather than told,
    /// because the rule is obvious the moment it has been done once.
    private var budget: some View {
        let level = model.configuredStreakLevel

        return Card {
            HStack(spacing: 8) {
                factor("\(model.settings.breaksPerDay)", "breaks")
                sign("×")
                factor("\(model.settings.breakMinutes)", "min each")
                sign("=")
                factor("\(model.dailyUnblockedMinutes)", "min a day")

                Spacer(minLength: 4)

                Text(level.name)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(level.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(level.tint.opacity(0.16), in: Capsule())
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(model.settings.breaksPerDay) breaks of \(model.settings.breakMinutes) minutes is \(model.dailyUnblockedMinutes) unblocked minutes a day, which is \(level.name)")

            Text("Your budget sets the colour, not the days. \(nextLevelHint)")
                .font(.system(size: 11.5))
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var nextLevelHint: String {
        guard let next = model.configuredStreakLevel.next, let shed = model.minutesToNextLevel else {
            return "Nothing is stricter than this."
        }
        return "\(shed) fewer minute\(shed == 1 ? "" : "s") a day reaches \(next.name)."
    }

    // MARK: - What it costs

    private var rules: some View {
        Card {
            fact("checkmark.circle.fill", "Breaks don't cost it.", tint: Theme.accentSoft)
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

    private func sign(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Theme.faint)
    }
}
