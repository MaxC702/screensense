import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel

    /// Tapping the flame goes to its tab. The badge is the obvious handle for
    /// "tell me about this", and it would be strange for it to open a copy of a
    /// screen the tab bar already has.
    let onShowStreak: () -> Void

    @State private var confirmingEndStudy = false
    @State private var isPickingCustomStudy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    if PreviewEnvironment.isSimulator { simulatorBanner }
                    if needsSetup { setupRow }

                    // A running session takes the breaks' place rather than
                    // sitting above them: there is nothing to do with a break
                    // until it ends, and a section offering one would be a lie.
                    if model.isStudying {
                        studyHero
                    } else {
                        breaksHero
                        if !model.isOnBreak { budgetRows }
                        studySection
                    }

                    footnote
                    buildStamp
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .background(Theme.background.ignoresSafeArea())
            // Never shown; it is what the back button on Settings says.
            .navigationTitle("Home")
            // Hidden only for this screen; SettingsView brings its own bar back.
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(Theme.muted)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 4) {
            VStack(alignment: .leading, spacing: 10) {
                Text("ScreenSense")
                    .font(Theme.display(30))

                HStack(spacing: 8) {
                    Circle()
                        .fill(model.state.blockingEnabled ? Theme.ok : Theme.faint)
                        .frame(width: 6, height: 6)
                    statusLine
                        .font(.system(size: 13))
                }
            }
            Spacer()
            streakBadge
            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.muted)
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
            }
            .accessibilityLabel("Settings")
        }
        .padding(.top, 8)
    }

    /// The level's name sits here, immediately under the wordmark and a few
    /// points from the badge it explains — a colour on its own means nothing
    /// until something nearby says what it is called.
    private var statusLine: Text {
        let on = model.state.blockingEnabled
        let status = Text(on ? "Blocking is on" : "Blocking is off")
            .foregroundColor(Theme.muted)
        // Nothing about a lost streak belongs on this line. Sat next to
        // "Blocking is on", a phrase like "starts again tomorrow" reads as a
        // claim about the blocking rather than about the count — and there is no
        // wording that reliably survives being read a word and a half away from
        // the wrong subject. The broken flame carries it instead, and the tab it
        // opens is where the sentence goes.
        guard on, model.streakDays > 0 else { return status }

        // While relighting, this says so *instead of* naming the level. Both
        // together wrap onto a second line, and the level is already being said
        // by the colour of the badge two inches to the right — whereas the fact
        // that a rung is missing is said by nothing else on this screen.
        let trailing = model.isRelighting
            ? Text("Relighting").foregroundColor(model.streakLevel.tint)
            : Text(model.streakLevel.name).foregroundColor(model.streakLevel.tint)

        return status
            + Text("  ·  ").foregroundColor(Theme.faint)
            + trailing
    }

    /// Days blocking has been left on, sat in the header rather than in the
    /// page below it: it is a score, not a control.
    ///
    /// Tapping it opens the streak's tab. A number beside a flame is not
    /// self-explanatory — it says something is being counted without saying what
    /// earns it or what costs it — and the badge is the thing someone reaches for
    /// when they want to know, so the badge is what answers.
    ///
    /// Shown even at zero, dimmed. A badge that only appears once you're winning
    /// can't teach anyone that there is something to win.
    private var streakBadge: some View {
        let days = model.streakDays
        let lit = days > 0
        let tint = model.streakLevel.tint

        return Button(action: onShowStreak) {
            HStack(spacing: 6) {
                StreakFlame(size: 14, lit: lit, broken: model.streakBrokenToday, tint: tint)
                Text("\(days)")
                    .font(.system(size: 15, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(lit ? Theme.foreground : Theme.faint)

                // Rides inside the badge rather than beside it: it qualifies the
                // flame, and a gauge floating on its own next to a number would
                // be one more unexplained thing on the busiest line of the screen.
                if let charge = model.levelCharge, lit {
                    LevelBattery(charge: charge, tint: tint, size: CGSize(width: 6, height: 14))
                }
            }
            .padding(.horizontal, 8)
            // Matches the gear button, so the two sit on one line across the top.
            .frame(height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(badgeLabel)
        .accessibilityHint("Opens the streak tab")
    }

    private var badgeLabel: String {
        guard model.streakDays > 0 else {
            return model.streakBrokenToday ? "Streak broken today, day 1 starts tomorrow" : "No streak"
        }
        let base = "\(model.streakDays) day \(model.streakLevel.name) streak"
        guard let headroom = model.levelHeadroom, let below = model.streakLevel.previous else {
            return base
        }
        return base + ", \(String(format: "%.0f", headroom)) minutes a day before it drops to \(below.name)"
    }

    /// Nothing here is really blocked, and a UI that looks identical to the real
    /// thing while doing nothing is worth labelling.
    private var simulatorBanner: some View {
        Label(
            "Simulator preview — nothing is actually blocked.",
            systemImage: "exclamationmark.triangle"
        )
        .font(.system(size: 12))
        .foregroundColor(Theme.streak)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 20)
    }

    // MARK: - Setup

    /// Home shows no way to stop blocking. That is the point: the switch and the
    /// app list live in Settings, two taps and a deliberate detour away, because
    /// a one-tap "off" beside a spent break budget is the same escape hatch that
    /// makes Screen Time's own limits evaporate — you reach for it without ever
    /// deciding to.
    ///
    /// What Home does still have to do is get someone who has not set up yet to
    /// the place where they can. This row is the only route across, and it
    /// disappears the moment protection is actually running.
    private var needsSetup: Bool {
        model.blockedCount == 0 || !model.state.blockingEnabled
    }

    private var setupRow: some View {
        NavigationLink {
            SettingsView()
        } label: {
            RuledList {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(setupTitle)
                            .font(.system(size: 16))
                            .foregroundColor(Theme.foreground)
                        Text(setupSubtitle)
                            .font(.system(size: 13))
                            .foregroundColor(Theme.muted)
                    }
                    Spacer()
                    chevron
                }
                .ruledRow()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 24)
    }

    private var setupTitle: String {
        model.blockedCount == 0 ? "Nothing is blocked yet" : "Blocking is off"
    }

    private var setupSubtitle: String {
        if model.blockedCount == 0 {
            return "Choose apps in Settings to start"
        }
        let count = model.blockedCount
        return "\(count) app\(count == 1 ? "" : "s"), categories and sites are unprotected"
    }

    // MARK: - Hero

    /// The heading over the ring, the ring, and what to do about it — the shape
    /// both a break and a study session take, so the screen does not rearrange
    /// itself when one becomes the other.
    private func hero<Ring: View, Actions: View>(
        title: String,
        meta: String?,
        @ViewBuilder ring: () -> Ring,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).foregroundColor(Theme.muted)
                Spacer()
                if let meta {
                    Text(meta)
                        .monospacedDigit()
                        .foregroundColor(Theme.faint)
                }
            }
            .font(.system(size: 14))

            ring()
                .padding(.top, 32)

            VStack(spacing: 12) {
                actions()
            }
            .padding(.top, 40)
        }
        .padding(.top, 40)
    }

    private func ringFigure(_ value: String, caption: String) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(Theme.numeral(value.count > 5 ? 52 : 64))
                .foregroundColor(Theme.foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption)
                .font(.system(size: 13))
                .foregroundColor(Theme.muted)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Breaks

    private var breaksHero: some View {
        hero(
            title: model.isOnBreak ? "On a break" : "Breaks today",
            meta: model.isOnBreak
                ? "\(model.breaksRemaining) of \(model.settings.breaksPerDay) left"
                : "\(model.breaksRemaining) of \(model.settings.breaksPerDay)"
        ) {
            HeroRing(fraction: ringFraction) {
                ringFigure(
                    model.isOnBreak ? model.countdownText : "\(model.breaksRemaining)",
                    caption: ringCaption
                )
            }
        } actions: {
            if model.isOnBreak {
                Button("End break now") { model.endBreakEarly() }
                    .buttonStyle(PillButtonStyle(kind: .secondary))
            } else {
                startBreakButton
                if model.breaksRemaining == 0 {
                    caption("Breaks reset at midnight.")
                } else if model.isCoolingDown {
                    caption("Breaks are spaced out so you can't take them back to back.")
                }
            }
        }
    }

    private var ringFraction: Double {
        model.isOnBreak
            ? model.breakProgress
            : Double(model.breaksRemaining) / Double(max(model.settings.breaksPerDay, 1))
    }

    private var ringCaption: String {
        if model.isOnBreak { return "until blocking resumes" }
        return model.breaksRemaining == 1 ? "break left" : "breaks left"
    }

    private var startBreakButton: some View {
        Button(startButtonTitle) { model.startBreak() }
            .buttonStyle(PillButtonStyle())
            .disabled(!model.canStartBreak)
    }

    /// The button doubles as the cooldown readout — a disabled control with no
    /// explanation is the thing that makes an app feel broken.
    /// Order matters: spending the last break starts a cooldown too, and the
    /// cooldown readout would then count towards a break that does not exist.
    private var startButtonTitle: String {
        if model.breaksRemaining == 0 {
            return "No breaks left today"
        }
        if model.isCoolingDown {
            return "Next break in \(model.cooldownText)"
        }
        return "Start \(model.settings.breakMinutes)-minute break"
    }

    // MARK: - Budget rows

    private var budgetRows: some View {
        RuledList {
            // A second route into settings, right next to the numbers it changes —
            // the gear alone makes you go looking for it.
            NavigationLink {
                SettingsView()
            } label: {
                valueRow("Each break lasts", "\(model.settings.breakMinutes) min", chevron: true)
            }
            .buttonStyle(.plain)

            valueRow("Breaks per day", "\(model.settings.breaksPerDay)")
            valueRow("Wait between breaks", "\(model.settings.cooldownMinutes) min")
        }
        .padding(.top, 40)
    }

    private func valueRow(_ title: String, _ value: String, chevron showChevron: Bool = false) -> some View {
        HStack(spacing: 4) {
            Text(title).foregroundColor(Theme.muted)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundColor(Theme.foreground)
            // The rows without one keep its width, so the values line up.
            chevron.opacity(showChevron ? 1 : 0)
        }
        .font(.system(size: 15))
        .contentShape(Rectangle())
        .ruledRow(padding: 14)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(Theme.faint)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(Theme.faint)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Study

    private var studySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("Study")
            Text("Study session")
                .font(Theme.display(24))
            Text(studySubtitle)
                .font(.system(size: 14))
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

            HStack(spacing: 8) {
                ForEach(model.settings.studyPresets, id: \.self) { minutes in
                    ChoiceChip(
                        title: BreakRules.studyLengthText(minutes),
                        selected: minutes == model.settings.studyMinutes
                    ) {
                        model.updateSettings { $0.studyMinutes = minutes }
                    }
                }
                // Shows the custom length once one is picked, so the button
                // below is never starting a length nothing on screen names.
                let custom = !model.settings.studyPresets.contains(model.settings.studyMinutes)
                ChoiceChip(
                    title: custom ? BreakRules.studyLengthText(model.settings.studyMinutes) : "Custom",
                    selected: custom,
                    opensMore: true
                ) {
                    isPickingCustomStudy = true
                }
            }
            .padding(.top, 20)
            .sheet(isPresented: $isPickingCustomStudy) {
                StudyTimerSheet(startingAt: model.settings.studyMinutes).environmentObject(model)
            }

            Button("Start \(BreakRules.studyLengthText(model.settings.studyMinutes)) session") {
                model.startStudy(minutes: model.settings.studyMinutes)
            }
            .buttonStyle(PillButtonStyle(kind: .secondary))
            .disabled(!model.canStartStudy)
            .padding(.top, 16)
        }
        .padding(.top, 48)
    }

    /// Says what a session does before it is started — that it turns breaks off
    /// is the whole point, and the one thing nobody should discover afterwards.
    private var studySubtitle: String {
        if !model.state.blockingEnabled || model.blockedCount == 0 {
            return "Turn blocking on to start one."
        }
        if model.isOnBreak {
            return "Starts once your break is over."
        }
        return "Breaks stay off until it ends."
    }

    private var studyHero: some View {
        hero(
            title: "Studying",
            meta: model.state.studyEndsAt.map { "Ends \($0.formatted(date: .omitted, time: .shortened))" }
        ) {
            HeroRing(fraction: model.studyProgress) {
                ringFigure(model.studyCountdownText, caption: "breaks are off")
            }
        } actions: {
            // Always a way out, never a free one: it asks first, and says what it
            // costs before the tap that pays it.
            Button("End session early") { confirmingEndStudy = true }
                .buttonStyle(PillButtonStyle(kind: .secondary))
                .confirmationDialog(
                    endStudyTitle,
                    isPresented: $confirmingEndStudy,
                    titleVisibility: .visible
                ) {
                    Button(model.streakDays > 0 ? "End session and lose streak" : "End session",
                           role: .destructive) { model.endStudyEarly() }
                    Button("Keep studying", role: .cancel) {}
                } message: {
                    Text(endStudyMessage)
                }
        }
    }

    private var endStudyTitle: String {
        let days = model.streakDays
        guard days > 0 else { return "End this session early?" }
        return "End early and lose your \(days)-day streak?"
    }

    private var endStudyMessage: String {
        guard model.streakDays > 0 else { return "Your breaks come back straight away." }
        var message = "Quitting a session costs the same as switching blocking off: the streak goes back to zero today"
        if model.streakDays >= StreakLevel.minimumRunToPenalise, model.streakLevel.previous != nil {
            message += " and the flame drops a level"
        }
        return message + ". Blocking stays on."
    }

    // MARK: - Footer

    private var footnote: some View {
        Text("Breaks reset at midnight. You can start one straight from the block screen without opening ScreenSense. What's blocked, and whether blocking is on at all, live in Settings.")
            .font(.system(size: 12))
            .lineSpacing(2)
            .foregroundColor(Theme.faint)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 48)
    }

    /// Which build is actually on the phone.
    ///
    /// Reinstalling over an app that is already installed gives no other signal
    /// that the new binary took — the icon doesn't change and the app relaunches
    /// looking identical. Reading it from the bundle rather than hardcoding it
    /// means it tracks `CURRENT_PROJECT_VERSION` in project.yml automatically.
    private var buildStamp: some View {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"

        return Text("v\(version) (\(build))")
            .font(.system(size: 12).monospacedDigit())
            .foregroundColor(Theme.faint.opacity(0.7))
            .padding(.top, 12)
    }
}
