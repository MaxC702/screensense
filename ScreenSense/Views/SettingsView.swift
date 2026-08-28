import FamilyControls
import SwiftUI

/// Everything that defines the block: what it covers, whether it is on, and the
/// break budget that lets you through it.
///
/// The two protection controls are here rather than on Home deliberately. Home
/// is the screen you land on when a break has just run out, and that is the
/// worst possible moment to be one tap from a switch that turns the whole thing
/// off. Screen Time loses to exactly that: adding fifteen more minutes is so
/// close to hand it stops feeling like a decision. Putting the switch behind a
/// navigation push does not stop anyone who means it — it just means they have
/// to mean it.
///
/// Changes write through immediately — there is no save button — because the
/// shield extension reads these values from the shared container the next time
/// it is spawned, and a pending unsaved edit would show the user one number in
/// the app and a different one on the block screen.
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    /// Set when the switch is thrown off with a run in progress. The toggle
    /// snaps back to on while this is up, because nothing has been decided yet.
    @State private var isConfirmingUnblock = false

    var body: some View {
        ScrollView {
            VStack(spacing: 13) {
                SectionLabel("Protection")
                blockedAppsCard
                blockingCard

                SectionLabel("Breaks")
                levelCard
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
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .familyActivityPicker(isPresented: $model.isPickerPresented, selection: $model.selection)
        .onChange(of: model.isPickerPresented) { presented in
            // Commit when Apple's picker dismisses rather than on every keystroke
            // inside it — the picker mutates the binding continuously.
            if !presented { model.commitSelection() }
        }
    }

    // MARK: - Protection

    private var blockedAppsCard: some View {
        Card {
            HStack(spacing: 10) {
                IconTile(symbol: "square.grid.2x2.fill")
                VStack(alignment: .leading, spacing: 1) {
                    Text("Blocked apps").font(Theme.display(15, .medium))
                    Text(model.blockedCount == 0
                         ? "Nothing selected yet"
                         : "\(model.blockedCount) apps, categories and sites")
                        .font(.system(size: 11.5))
                        .foregroundColor(Theme.muted)
                }
                Spacer()
            }

            Button {
                model.isPickerPresented = true
            } label: {
                Text(model.blockedCount == 0 ? "Choose apps" : "Edit selection")
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        Theme.accent.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .foregroundColor(Theme.accentSoft)
            }
        }
    }

    private var blockingCard: some View {
        Card {
            Toggle(isOn: Binding(
                get: { model.state.blockingEnabled },
                // Turning it *on* is never second-guessed — friction belongs
                // only on the direction that costs something. Turning it off
                // with a run going asks first; with nothing to lose it just
                // goes, because a confirmation that always fires stops being
                // read within a week.
                set: { enabled in
                    if !enabled, model.streakDays > 0 {
                        isConfirmingUnblock = true
                    } else {
                        model.setBlocking(enabled)
                    }
                }
            )) {
                HStack(spacing: 10) {
                    IconTile(symbol: "lock.shield.fill")
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Block these apps").font(Theme.display(15, .medium))
                        Text(blockingSubtitle)
                            .font(.system(size: 11.5))
                            .foregroundColor(Theme.muted)
                    }
                }
            }
            .tint(Theme.accent)
            .disabled(model.blockedCount == 0)
            .opacity(model.blockedCount == 0 ? 0.45 : 1)

            // Said at the switch, not on Home, because this is now the only place
            // it can be read — and the only place it can be acted on.
            if model.state.blockingEnabled, model.breaksRemaining == 0 {
                note("Out of breaks until midnight. Switching off is not a sixth break — it ends the streak.")
            }
        }
        .alert(unblockAlertTitle, isPresented: $isConfirmingUnblock) {
            // iOS puts the cancel role last whatever order these are written in,
            // so the reflex — the bottom button, the one under your thumb — is
            // the one that keeps the streak.
            Button("Keep blocking on", role: .cancel) { }
            Button("Turn it off", role: .destructive) { model.setBlocking(false) }
        } message: {
            Text(unblockAlertMessage)
        }
    }

    private var unblockAlertTitle: String {
        let days = model.streakDays
        return "End your \(days)-day \(model.streakLevel.name) streak?"
    }

    /// Names the cost, then names the cheaper thing — because the honest answer
    /// to most of the moments this alert appears in is "you wanted a few minutes,
    /// not an unlocked phone", and a break costs nothing but a break.
    private var unblockAlertMessage: String {
        let days = model.streakDays
        var lines = ["Turning blocking off unblocks everything and resets your streak to zero. \(days) day\(days == 1 ? "" : "s") gone, and today goes with them — switching back on this afternoon does not buy day 1 back, the next run starts tomorrow."]

        // Only promised when it will actually happen, so the alert never
        // threatens a consequence the ladder cannot deliver.
        if days >= StreakLevel.minimumRunToPenalise, model.configuredStreakLevel > .ember {
            let dropped = model.configuredStreakLevel.lowered(by: 1)
            lines.append("Your flame drops to \(dropped.name) with it, and takes \(StreakLevel.relightDays) days of blocking to earn back.")
        }

        if model.breaksRemaining > 0 {
            let left = model.breaksRemaining
            lines.append("You still have \(left) break\(left == 1 ? "" : "s") today. A break costs you nothing but the break.")
        } else {
            lines.append("Your breaks come back at midnight, and they don't cost the streak.")
        }

        if model.bestStreak > 0 {
            lines.append("Your best run of \(model.bestStreak) day\(model.bestStreak == 1 ? "" : "s") is kept either way.")
        }

        return lines.joined(separator: "\n\n")
    }

    /// This switch is the only thing that costs a streak, so the cost is spelled
    /// out on it rather than left for the badge to imply — and once a run is
    /// lost, the number to beat is named in the same place.
    private var blockingSubtitle: String {
        if model.state.blockingEnabled {
            let days = model.streakDays
            // Names the streak outright. This sits under "Block these apps",
            // where anything that merely says "starts again tomorrow" would
            // sound like a statement about the blocking itself.
            guard days > 0 else {
                return model.streakBrokenToday
                    ? "Streak lost today — the next one starts tomorrow"
                    : "Stays on until you spend a break"
            }
            return "\(days)-day streak — turning this off resets it"
        }
        if model.streakBrokenToday { return "Streak lost today — the next one starts tomorrow" }
        guard model.bestStreak > 0 else { return "Stays on until you spend a break" }
        return "Your best run was \(model.bestStreak) day\(model.bestStreak == 1 ? "" : "s") — start again"
    }

    // MARK: - Level

    /// Heads the Breaks section, above the controls that set it.
    ///
    /// The level is the reason to touch the sliders at all, and it moves while
    /// they are being dragged — which is the entire feedback loop. Putting it
    /// below them would hide the consequence under the cause.
    private var levelCard: some View {
        let level = model.configuredStreakLevel

        return Card {
            HStack(spacing: 10) {
                IconTile(symbol: "flame.fill")
                VStack(alignment: .leading, spacing: 1) {
                    Text("Daily allowance").font(Theme.display(15, .medium))
                    Text("\(model.dailyUnblockedMinutes) unblocked minute\(model.dailyUnblockedMinutes == 1 ? "" : "s") a day")
                        .font(.system(size: 11.5))
                        .foregroundColor(Theme.muted)
                }
                Spacer()
                Text(level.name)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(level.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(level.tint.opacity(0.16), in: Capsule())
            }

            StreakLadder(level: level)

            Text(nextLevelHint)
                .font(.system(size: 11))
                .foregroundColor(Theme.muted)

            // The budget is a worst case, and since the flame started following
            // what is actually spent the two are usually different. Saying so
            // here is what stops this card and the Streak tab looking like they
            // disagree.
            Text(earnedNote)
                .font(.system(size: 11))
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            if model.isRelighting {
                note("A lost run has your flame at \(model.streakLevel.name) for now. \(relightHint)")
            }
        }
    }

    /// Ties the slider to the thing it does not control, so nobody drags this
    /// expecting the flame on the other tab to follow.
    private var earnedNote: String {
        guard let average = model.averageUnblockedMinutes else {
            return "That is the most you can spend. The flame follows what you actually spend, which needs blocking switched on to mean anything."
        }
        let spent = average < 10 ? String(format: "%.1f", average) : "\(Int(average.rounded()))"
        return "That is the most you can spend. You are actually spending \(spent) min a day, which is \(model.earnedStreakLevel.name)."
    }

    private var relightHint: String {
        let days = model.daysToRelight
        return "\(days) more day\(days == 1 ? "" : "s") of blocking puts it back."
    }

    private var nextLevelHint: String {
        guard let next = model.configuredStreakLevel.next, let shed = model.minutesToNextLevel else {
            return "Nothing is stricter than this."
        }
        return "\(shed) fewer minute\(shed == 1 ? "" : "s") a day reaches \(next.name)."
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
            Text("Your streak's level comes from breaks per day times break length — the unblocked time you allow yourself. The wait between breaks changes when that time can be spent, not how much of it there is, so it doesn't count towards the level.")
        }
        .font(.system(size: 11))
        .foregroundColor(Theme.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.top, 4)
    }
}
