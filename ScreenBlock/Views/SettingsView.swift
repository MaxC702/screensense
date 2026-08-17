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
            VStack(spacing: 13) {
                breaksPerDayCard
                breakLengthCard
                cooldownCard
                diagnosticsLink
                explainer
            }
            .padding(.horizontal, 17)
            .padding(.bottom, 17)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Breaks")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Breaks per day

    private var breaksPerDayCard: some View {
        Card {
            cardHeader(symbol: "number", title: "Breaks per day")

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
                note("You've already used \(model.state.breaksUsed) today — this takes effect tomorrow.")
            }
        }
    }

    // MARK: - Break length

    private var breakLengthCard: some View {
        Card {
            cardHeader(
                symbol: "timer",
                title: "Break length",
                trailing: "\(model.settings.breakMinutes) min"
            )

            Slider(
                value: Binding(
                    get: { Double(model.settings.breakMinutes) },
                    set: { value in model.updateSettings { $0.breakMinutes = Int(value.rounded()) } }
                ),
                in: Double(BreakRules.minMinutes)...Double(BreakRules.maxMinutes),
                step: 1
            )
            .tint(Theme.accent)

            bounds("\(BreakRules.minMinutes) min", "\(BreakRules.maxMinutes) min")
        }
    }

    // MARK: - Cooldown

    private var cooldownCard: some View {
        Card {
            cardHeader(
                symbol: "hourglass",
                title: "Wait between breaks",
                subtitle: "Before the next one can start",
                trailing: "\(model.settings.cooldownMinutes) min"
            )

            Slider(
                value: Binding(
                    get: { Double(model.settings.cooldownMinutes) },
                    set: { value in model.updateSettings { $0.cooldownMinutes = Int(value.rounded()) } }
                ),
                in: Double(BreakRules.minCooldownMinutes)...Double(BreakRules.maxCooldownMinutes),
                step: 5
            )
            .tint(Theme.accent)

            bounds("\(BreakRules.minCooldownMinutes) min", "1 hour")

            if model.isCoolingDown {
                note("Cooling down now — \(model.cooldownText) left. Changes apply to the next one.")
            }
        }
    }

    // MARK: - Pieces

    private func cardHeader(
        symbol: String,
        title: String,
        subtitle: String? = nil,
        trailing: String? = nil
    ) -> some View {
        HStack(spacing: 10) {
            IconTile(symbol: symbol)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(Theme.display(15, .medium))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundColor(Theme.muted)
                }
            }
            Spacer()
            if let trailing { Pill(text: trailing) }
        }
    }

    private func bounds(_ low: String, _ high: String) -> some View {
        HStack {
            Text(low)
            Spacer()
            Text(high)
        }
        .font(.system(size: 11))
        .foregroundColor(Theme.faint)
    }

    private func note(_ text: String) -> some View {
        Label(text, systemImage: "info.circle")
            .font(.system(size: 11))
            .foregroundColor(.orange)
    }

    /// Temporary while the out-of-process timing is being pinned down on device.
    private var diagnosticsLink: some View {
        NavigationLink {
            DiagnosticsView()
        } label: {
            Card {
                HStack(spacing: 10) {
                    IconTile(symbol: "waveform.path.ecg")
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Diagnostics").font(Theme.display(15, .medium))
                        Text("What the extensions actually did, and when")
                            .font(.system(size: 11.5))
                            .foregroundColor(Theme.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.faint)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var explainer: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("A break runs on the clock. Start a 5-minute break and the block comes back 5 minutes later, whether or not you spent them in the app.")
            Text("The wait between breaks is the same, so it can't be run down from inside a blocked app either.")
            Text("Breaks reset at midnight. Ending one early doesn't give it back, and it still starts the wait.")
        }
        .font(.system(size: 11))
        .foregroundColor(Theme.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.top, 4)
    }
}
