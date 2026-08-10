import SwiftUI

/// Where the two numbers that define the break budget live.
///
/// Changes write through immediately — there is no save button — because the
/// shield extension reads these values from the shared container the next time
/// it is spawned, and a pending unsaved edit would show the user one number in
/// the app and a different one on the block screen.
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                breaksPerDayCard
                breakLengthCard
                explainer
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Breaks")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Breaks per day

    private var breaksPerDayCard: some View {
        Card {
            Label("Breaks per day", systemImage: "number")
                .font(.headline)

            Text("How many times you can let yourself back in.")
                .font(.subheadline)
                .foregroundColor(Theme.muted)

            Picker(
                "Breaks per day",
                selection: Binding(
                    get: { model.settings.breaksPerDay },
                    set: { value in model.updateSettings { $0.breaksPerDay = value } }
                )
            ) {
                ForEach(BreakRules.breaksRange, id: \.self) { count in
                    Text("\(count)").tag(count)
                }
            }
            .pickerStyle(.segmented)

            if model.state.breaksUsed > model.settings.breaksPerDay {
                // Spent breaks aren't refunded, so lowering the allowance below
                // today's usage takes effect tomorrow rather than retroactively.
                Label(
                    "You've already used \(model.state.breaksUsed) today — this takes effect tomorrow.",
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundColor(.orange)
            }
        }
    }

    // MARK: - Break length

    private var breakLengthCard: some View {
        Card {
            Label("Break length", systemImage: "timer")
                .font(.headline)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(model.settings.breakMinutes)")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(model.settings.breakMinutes == 1 ? "minute" : "minutes")
                    .font(.headline)
                    .foregroundColor(Theme.muted)
                Spacer()
            }

            Slider(
                value: Binding(
                    get: { Double(model.settings.breakMinutes) },
                    set: { value in model.updateSettings { $0.breakMinutes = Int(value.rounded()) } }
                ),
                in: Double(BreakRules.minMinutes)...Double(BreakRules.maxMinutes),
                step: 1
            )
            .tint(Theme.accent)

            HStack {
                Text("\(BreakRules.minMinutes) min")
                Spacer()
                Text("\(BreakRules.maxMinutes) min")
            }
            .font(.caption)
            .foregroundColor(Theme.muted)
        }
    }

    private var explainer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("A break counts down while you're actually using the blocked apps, so time spent with your phone in your pocket doesn't burn it.")
            Text("Breaks reset at midnight. Ending one early doesn't give it back.")
        }
        .font(.caption)
        .foregroundColor(Theme.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}
