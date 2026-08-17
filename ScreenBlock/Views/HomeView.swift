import FamilyControls
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 13) {
                    header
                    if PreviewEnvironment.isSimulator { simulatorBanner }

                    SectionLabel("Protection")
                    blockedAppsCard
                    statusCard

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
            .familyActivityPicker(isPresented: $model.isPickerPresented, selection: $model.selection)
            .onChange(of: model.isPickerPresented) { presented in
                // Commit when Apple's picker dismisses rather than on every keystroke
                // inside it — the picker mutates the binding continuously.
                if !presented { model.commitSelection() }
            }
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
                    Text(model.state.blockingEnabled ? "Blocking is on" : "Blocking is off")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.muted)
                }
            }
            Spacer()
            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .accessibilityLabel("Break settings")
        }
        .padding(.top, 4)
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
                chevron
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

    private var statusCard: some View {
        Card {
            Toggle(isOn: Binding(
                get: { model.state.blockingEnabled },
                set: { model.setBlocking($0) }
            )) {
                HStack(spacing: 10) {
                    IconTile(symbol: "lock.shield.fill")
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Block these apps").font(Theme.display(15, .medium))
                        Text("Stays on until you spend a break")
                            .font(.system(size: 11.5))
                            .foregroundColor(Theme.muted)
                    }
                }
            }
            .tint(Theme.accent)
            .disabled(model.blockedCount == 0)
            .opacity(model.blockedCount == 0 ? 0.45 : 1)
        }
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
        Text("Breaks reset at midnight. Tap the gear to change how many you get and how long they last. You can also start one straight from the block screen without opening ScreenBlock.")
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
