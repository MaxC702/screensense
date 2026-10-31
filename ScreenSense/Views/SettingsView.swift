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

    /// The level card is the one place that sets what the flame is judged on, so
    /// it is where the other half of that judgement — the starting point — has
    /// to be reachable too.
    @State private var isEditingBaseline = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenTitle("Settings")

                SectionLabel("Protection")
                RuledList {
                    blockedAppsRow
                    blockingRow
                }

                SectionLabel("Breaks").padding(.top, 40)
                RuledList {
                    levelRow
                    breaksPerDayRow
                    breakLengthRow
                    cooldownRow
                }

                #if DEBUG
                SectionLabel("Support").padding(.top, 40)
                RuledList { diagnosticsLink }
                #endif

                explainer
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .background(Theme.background.ignoresSafeArea())
        .pushedScreen("Settings")
        .sheet(isPresented: $isEditingBaseline) {
            BaselineSheet().environmentObject(model)
        }
        .familyActivityPicker(isPresented: $model.isPickerPresented, selection: $model.selection)
        .onChange(of: model.isPickerPresented) { presented in
            // Commit when Apple's picker dismisses rather than on every keystroke
            // inside it — the picker mutates the binding continuously.
            if !presented { model.commitSelection() }
        }
    }

    // MARK: - Protection

    private var blockedAppsRow: some View {
        HStack(spacing: 16) {
            rowTitle(
                "Blocked apps",
                model.blockedCount == 0
                    ? "Nothing selected yet"
                    : "\(model.blockedCount) apps, categories and sites"
            )

            Button {
                model.isPickerPresented = true
            } label: {
                HStack(spacing: 2) {
                    Text(model.blockedCount == 0 ? "Choose" : "Edit")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                }
                .font(.system(size: 15))
                .foregroundColor(Theme.muted)
            }
            .buttonStyle(.plain)
            // Taking apps off the list is turning blocking off one app at a
            // time, so it is locked for the session along with the switch.
            .disabled(model.isStudying)
            .opacity(model.isStudying ? 0.45 : 1)
        }
        .ruledRow()
    }

    private var blockingRow: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                rowTitle("Block these apps", blockingSubtitle)
            }
            .toggleStyle(InkToggleStyle())
            .disabled(model.blockedCount == 0 || model.isStudying)
            .opacity(model.blockedCount == 0 || model.isStudying ? 0.45 : 1)

            if model.isStudying, let end = model.state.studyEndsAt {
                note("Locked until your study session ends at \(end.formatted(date: .omitted, time: .shortened)).")
            }

            // Said at the switch, not on Home, because this is now the only place
            // it can be read — and the only place it can be acted on.
            if model.state.blockingEnabled, model.breaksRemaining == 0 {
                note("Out of breaks until midnight. Switching off is not a sixth break — it ends the streak.")
            }
        }
        .ruledRow()
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
    ///
    /// Shows the level the flame shows, not the one the allowance alone is worth.
    /// Those two are genuinely different facts — what you are allowed against
    /// what you actually spend — but a person reading a blue flame on Home and
    /// the words "White heat" here does not receive two facts, they receive a
    /// contradiction. The allowance's own worth is still said, in the sentence
    /// under the ladder, where it is labelled as being about the allowance.
    private var levelRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            rowHeading("Daily allowance", trailing: "\(model.dailyUnblockedMinutes) min a day", trailingColor: Theme.muted)

            StreakLadder(level: model.streakLevel, target: model.earnedStreakLevel)
                .padding(.top, 16)

            Text(flameNote)
                .font(.system(size: 14))
                .lineSpacing(2)
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)

            Text(allowanceNote)
                .font(.system(size: 13))
                .lineSpacing(2)
                .foregroundColor(Theme.faint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            if model.isRelighting {
                note("A lost run has your flame at \(model.streakLevel.name) for now. \(relightHint)")
                    .padding(.top, 12)
            }

            BaselineRow(band: model.baselineBand, hasChosen: model.hasChosenBaseline) {
                isEditingBaseline = true
            }
            .padding(.top, 16)

            if let outgrown = outgrownBaselineNote {
                note(outgrown)
                    .padding(.top, 12)
            }
        }
        .ruledRow()
    }

    /// What the badge above is actually reading, so the number on this card and
    /// the flame on Home are visibly the same number.
    private var flameNote: String {
        guard let average = model.averageUnblockedMinutes else {
            return "Your level follows what you actually spend. With no day on the board yet it goes by the allowance below."
        }
        let spent = average < 10 ? String(format: "%.1f", average) : "\(Int(average.rounded()))"
        let base = "Your level follows what you actually spend: \(spent) min a day."
        guard model.weekSpansBaselineChange else { return base }
        return base + " Days before you changed where you started keep the level they earned then."
    }

    /// Ties the sliders to the thing they *do* control, which is the worst case
    /// rather than the level — dragging them does not move the flame, it moves
    /// the ceiling the flame could rise to.
    private var allowanceNote: String {
        let budget = model.dailyUnblockedMinutes
        let worth = model.configuredStreakLevel
        let base = "Spending the full \(budget) min a day would be \(worth.name)."
        guard let next = worth.next, let shed = model.minutesToNextLevel else {
            return base + " Nothing is stricter than that."
        }
        return base + " \(shed) fewer minute\(shed == 1 ? "" : "s") a day would make it \(next.name)."
    }

    private var relightHint: String {
        let days = model.daysToRelight
        return "\(days) more day\(days == 1 ? "" : "s") of blocking puts it back."
    }

    /// The step-up, offered once the top rung has been held rather than touched.
    ///
    /// Says the plain thing: you are at the top, it is too easy, here is the
    /// button and here is what changes. An earlier draft talked about a ladder
    /// having "done its job", which is a metaphor the app never sets up and
    /// which asks somebody a week into using it to work out what job a ladder
    /// has. Both numbers are named because the trade is the whole message.
    ///
    /// Never shown on the hardest band — `harderBand` returns nil there, because
    /// there is nowhere to send someone already at the top of the last one, and
    /// inventing somewhere would be a lie.
    private var outgrownBaselineNote: String? {
        guard let harder = model.harderBand else { return nil }
        let here = StreakLevel.blueFlame.ceiling(band: model.baselineBand) ?? 0
        let there = StreakLevel.blueFlame.ceiling(band: harder) ?? 0
        let days = model.daysAtSummit
        // Named as a cut, not as a new figure to subtract from the old one.
        // "Blue flame would need 35 min a day" reads just as easily as
        // thirty-five *more*, which is the opposite of what is being offered.
        let drop = max(0, here - there)
        return "You have been at Blue flame for \(days) day\(days == 1 ? "" : "s"), so this is too easy now. Tap Change above and pick \(harder.title.lowercased()) — every level gets stricter, and Blue flame would mean cutting \(drop) more minute\(drop == 1 ? "" : "s") a day, down to \(there) from \(here)."
    }

    // MARK: - Breaks per day

    private var breaksPerDayRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            rowHeading("Breaks per day")

            HStack(spacing: 6) {
                ForEach(BreakRules.breaksRange, id: \.self) { count in
                    ChoiceChip(
                        title: "\(count)",
                        selected: count == model.settings.breaksPerDay,
                        height: 36
                    ) {
                        model.updateSettings { $0.breaksPerDay = count }
                    }
                    .accessibilityLabel("\(count) break\(count == 1 ? "" : "s") a day")
                }
            }

            if model.state.breaksUsed > model.settings.breaksPerDay {
                // Spent breaks aren't refunded, so lowering the allowance below
                // today's usage takes effect tomorrow rather than retroactively.
                note("You've already used \(model.state.breaksUsed) today — this takes effect tomorrow.")
            }
        }
        .ruledRow()
    }

    // MARK: - Break length

    private var breakLengthRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            rowHeading("Break length", trailing: "\(model.settings.breakMinutes) min")

            Slider(
                value: Binding(
                    get: { Double(model.settings.breakMinutes) },
                    set: { value in model.updateSettings { $0.breakMinutes = Int(value.rounded()) } }
                ),
                in: Double(BreakRules.minMinutes)...Double(BreakRules.maxMinutes),
                step: 1
            )
            .tint(Theme.foreground)

            bounds("\(BreakRules.minMinutes) min", "\(BreakRules.maxMinutes) min")
        }
        .ruledRow()
    }

    // MARK: - Cooldown

    private var cooldownRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            rowHeading("Wait between breaks", trailing: "\(model.settings.cooldownMinutes) min")
            Text("Before the next one can start")
                .font(.system(size: 13))
                .foregroundColor(Theme.muted)
                .padding(.top, -8)

            Slider(
                value: Binding(
                    get: { Double(model.settings.cooldownMinutes) },
                    set: { value in model.updateSettings { $0.cooldownMinutes = Int(value.rounded()) } }
                ),
                in: Double(BreakRules.minCooldownMinutes)...Double(BreakRules.maxCooldownMinutes),
                step: 5
            )
            .tint(Theme.foreground)

            bounds("\(BreakRules.minCooldownMinutes) min", "1 hour")

            if model.isCoolingDown {
                note("Cooling down now — \(model.cooldownText) left. Changes apply to the next one.")
            }
        }
        .ruledRow()
    }

    // MARK: - Pieces

    /// A row's name and what it currently covers, set the way every row with a
    /// control on its right is.
    private func rowTitle(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(Theme.foreground)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A row's name, with its current value opposite for the rows whose control
    /// sits underneath rather than beside it.
    private func rowHeading(_ title: String, trailing: String? = nil, trailingColor: Color = Theme.foreground) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(Theme.foreground)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 15))
                    .monospacedDigit()
                    .foregroundColor(trailingColor)
            }
        }
    }

    private func bounds(_ low: String, _ high: String) -> some View {
        HStack {
            Text(low)
            Spacer()
            Text(high)
        }
        .font(.system(size: 12))
        .foregroundColor(Theme.faint)
    }

    /// The warm colour is the streak's, and every note here is about something
    /// the streak stands to lose or a limit on a break — which is the same thing.
    private func note(_ text: String) -> some View {
        Label(text, systemImage: "info.circle")
            .font(.system(size: 13))
            .foregroundColor(Theme.streak)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// A log reader for the three extensions, which have no console of their own
    /// on a device that is not attached to Xcode. Debug builds only.
    ///
    /// It is a developer tool wearing a settings row: it answers "did the monitor
    /// actually fire", which is the one question this architecture makes hard to
    /// ask, and it is worthless to anybody who is not debugging it. Shipping it
    /// would put a wall of timestamps in front of a user looking for the app
    /// list, and invite App Review to wonder what is being recorded.
    ///
    /// `BreakLog` itself is left compiled in, so a development build installed on
    /// the phone still has the whole history to read — which is exactly the case
    /// this exists for.
    #if DEBUG
    private var diagnosticsLink: some View {
        NavigationLink {
            DiagnosticsView()
        } label: {
            HStack(spacing: 16) {
                rowTitle("Diagnostics", "What the extensions actually did, and when")
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.faint)
            }
            .contentShape(Rectangle())
            .ruledRow()
        }
        .buttonStyle(.plain)
    }
    #endif

    private var explainer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("A break runs on the clock. Start a 5-minute break and the block comes back 5 minutes later, whether or not you spent them in the app.")
            Text("The wait between breaks is the same, so it can't be run down from inside a blocked app either.")
            Text("Breaks reset at midnight. Ending one early doesn't give it back, and it still starts the wait.")
            Text("Your streak's level comes from breaks per day times break length — the unblocked time you allow yourself. The wait between breaks changes when that time can be spent, not how much of it there is, so it doesn't count towards the level.")
        }
        .font(.system(size: 12))
        .lineSpacing(2)
        .foregroundColor(Theme.faint)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 40)
    }
}
