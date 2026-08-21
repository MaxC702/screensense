import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel

    /// Tapping the flame goes to its tab. The badge is the obvious handle for
    /// "tell me about this", and it would be strange for it to open a copy of a
    /// screen the tab bar already has.
    let onShowStreak: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 13) {
                    header
                    if PreviewEnvironment.isSimulator { simulatorBanner }
                    if needsSetup { setupCard }

                    SectionLabel("Breaks")
                    breaksHero
                    if !model.isOnBreak { budgetRows }

                    footnote
                    buildStamp
                }
                .padding(.horizontal, 17)
                .padding(.bottom, 17)
            }
            .background(Theme.background.ignoresSafeArea())
            // Hidden only for this screen; SettingsView brings its own bar back.
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(Theme.accentSoft)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("ScreenBlock")
                    .font(Theme.display(28))
                    .kerning(0.3)

                HStack(spacing: 6) {
                    Circle()
                        .fill(model.state.blockingEnabled ? Color.green : Theme.faint)
                        .frame(width: 7, height: 7)
                    statusLine
                        .font(.system(size: 12))
                }
            }
            Spacer()
            streakBadge
            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .accessibilityLabel("Settings")
        }
        .padding(.top, 4)
    }

    /// The level's name sits here, immediately under the wordmark and a few
    /// points from the badge it explains — a colour on its own means nothing
    /// until something nearby says what it is called.
    private var statusLine: Text {
        let on = model.state.blockingEnabled
        let status = Text(on ? "Blocking is on" : "Blocking is off")
            .foregroundColor(Theme.muted)
        guard on, model.streakDays > 0 else { return status }

        // While relighting, this says so *instead of* naming the level. Both
        // together wrap onto a second line, and the level is already being said
        // by the colour of the badge two inches to the right — whereas the fact
        // that a rung is missing is said by nothing else on this screen.
        let trailing = model.isRelighting
            ? Text("Relighting").foregroundColor(model.streakLevel.tint)
            : Text("\(model.streakLevel.name) streak").foregroundColor(model.streakLevel.tint)

        return status
            + Text("  ·  ").foregroundColor(Theme.faint)
            + trailing
    }

    /// Days blocking has been left on, sat in the header rather than in the stack
    /// of cards below it: it is a score, not a control.
    ///
    /// Tapping it opens the streak's tab. A number in a coloured pill is not
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
            HStack(spacing: 5) {
                Image(systemName: lit ? "flame.fill" : "flame")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(lit ? tint : Theme.faint)
                Text("\(days)")
                    .font(Theme.display(17, .demiBold))
                    .monospacedDigit()
                    .foregroundColor(lit ? .white : Theme.faint)

                // Rides inside the badge rather than beside it: it qualifies the
                // flame, and a gauge floating on its own next to a number would
                // be one more unexplained thing on the busiest line of the screen.
                if let charge = model.levelCharge, lit {
                    LevelBattery(charge: charge, tint: tint)
                        .padding(.leading, 1)
                }
            }
            .padding(.horizontal, 10)
            // Matches the gear button, so the two sit on one line across the top.
            .frame(height: 38)
            .background(
                lit ? tint.opacity(0.16) : Theme.card,
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(badgeLabel)
        .accessibilityHint("Opens the streak tab")
    }

    private var badgeLabel: String {
        guard model.streakDays > 0 else { return "No streak" }
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
            systemImage: "exclamationmark.triangle.fill"
        )
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(.orange)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(
            Color.orange.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    // MARK: - Setup

    /// Home shows no way to stop blocking. That is the point: the switch and the
    /// app list live in Settings, two taps and a deliberate detour away, because
    /// a one-tap "off" beside a spent break budget is the same escape hatch that
    /// makes Screen Time's own limits evaporate — you reach for it without ever
    /// deciding to.
    ///
    /// What Home does still have to do is get someone who has not set up yet to
    /// the place where they can. This card is the only route across, and it
    /// disappears the moment protection is actually running.
    private var needsSetup: Bool {
        model.blockedCount == 0 || !model.state.blockingEnabled
    }

    private var setupCard: some View {
        NavigationLink {
            SettingsView()
        } label: {
            Card {
                HStack(spacing: 10) {
                    IconTile(symbol: model.blockedCount == 0 ? "square.grid.2x2.fill" : "lock.open.fill")
                    VStack(alignment: .leading, spacing: 1) {
                        Text(setupTitle).font(Theme.display(15, .medium))
                        Text(setupSubtitle)
                            .font(.system(size: 11.5))
                            .foregroundColor(Theme.muted)
                    }
                    Spacer()
                    chevron
                }
            }
        }
        .buttonStyle(.plain)
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

    // MARK: - Breaks

    /// Carries the gradient only when there is something to act on — a break to
    /// take, or one running. Cooling down and out-of-breaks go flat, so the card
    /// says whether the app is open to you before any of its text is read.
    private var heroIsLive: Bool { model.canStartBreak || model.isOnBreak }

    private var breaksHero: some View {
        VStack(spacing: 14) {
            HStack {
                Text(model.isOnBreak ? "On a break" : "Breaks today")
                    .font(Theme.display(15, .medium))
                Spacer()
                Pill(text: "\(model.breaksRemaining) of \(model.settings.breaksPerDay)")
            }

            BreakRing(fraction: ringFraction, onGradient: heroIsLive) {
                VStack(spacing: 5) {
                    Text(model.isOnBreak ? model.countdownText : "\(model.breaksRemaining)")
                        .font(Theme.display(model.isOnBreak ? 31 : 38, .ultraLight))
                        .monospacedDigit()
                    Text(ringCaption)
                        .font(.system(size: 9.5, weight: .semibold))
                        .kerning(0.4)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            if model.isOnBreak {
                endBreakButton
            } else {
                startBreakButton
                if model.isCoolingDown, model.breaksRemaining > 0 {
                    Text("Breaks are spaced out so you can't take them back to back.")
                        .font(.system(size: 11))
                        .foregroundColor(heroIsLive ? .white.opacity(0.8) : Theme.muted)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(heroBackground)
    }

    @ViewBuilder
    private var heroBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        if heroIsLive {
            shape.fill(Theme.gradient)
                .shadow(color: Theme.accent.opacity(0.32), radius: 17, y: 8)
        } else {
            shape.fill(Theme.card)
        }
    }

    private var ringFraction: Double {
        model.isOnBreak
            ? model.breakProgress
            : Double(model.breaksRemaining) / Double(max(model.settings.breaksPerDay, 1))
    }

    private var ringCaption: String {
        if model.isOnBreak { return "BREAK RUNNING" }
        return model.breaksRemaining == 1 ? "BREAK LEFT" : "BREAKS LEFT"
    }

    private var startBreakButton: some View {
        Button {
            model.startBreak()
        } label: {
            Text(startButtonTitle)
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    model.canStartBreak ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.white.opacity(0.07)),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .foregroundColor(model.canStartBreak
                                 ? Color(red: 0.357, green: 0.235, blue: 0.878)
                                 : Theme.faint)
        }
        .disabled(!model.canStartBreak)
    }

    private var endBreakButton: some View {
        Button(role: .destructive) {
            model.endBreakEarly()
        } label: {
            Text("End break now")
                .font(.system(size: 13, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Color.white.opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .foregroundColor(.white.opacity(0.85))
        }
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
        VStack(spacing: 0) {
            // A second route into settings, right next to the numbers it changes —
            // the gear alone makes you go looking for it.
            NavigationLink {
                SettingsView()
            } label: {
                valueRow("Each break lasts", "\(model.settings.breakMinutes) min", chevron: true)
            }
            .buttonStyle(.plain)

            Divider().overlay(Theme.hairline)
            valueRow("Breaks per day", "\(model.settings.breaksPerDay)")

            Divider().overlay(Theme.hairline)
            valueRow("Wait between breaks", "\(model.settings.cooldownMinutes) min")
        }
        .padding(.horizontal, 16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func valueRow(_ title: String, _ value: String, chevron showChevron: Bool = false) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 13.5))
                .foregroundColor(Theme.muted)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
            if showChevron { chevron }
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(Theme.faint)
    }

    // MARK: - Footer

    private var footnote: some View {
        Text("Breaks reset at midnight. You can start one straight from the block screen without opening ScreenBlock. What's blocked, and whether blocking is on at all, live in Settings — out of reach of a moment you'd regret.")
            .font(.system(size: 11))
            .foregroundColor(Theme.faint)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 6)
            .padding(.top, 4)
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
            .font(.system(size: 10).monospacedDigit())
            .foregroundColor(Theme.faint)
    }
}
