import FamilyControls
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    blockedAppsCard
                    statusCard
                    breaksCard
                    footnote
                }
                .padding(20)
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
        .tint(Theme.accent)
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("ScreenBlock")
                    .font(.largeTitle.bold())
                Text(model.state.blockingEnabled ? "Blocking is on" : "Blocking is off")
                    .font(.subheadline)
                    .foregroundColor(Theme.muted)
            }
            Spacer()
            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Theme.card, in: Circle())
            }
            .accessibilityLabel("Break settings")
        }
        .padding(.top, 8)
    }

    private var blockedAppsCard: some View {
        Card {
            Label("Blocked apps", systemImage: "square.grid.2x2.fill")
                .font(.headline)

            Text(model.blockedCount == 0
                 ? "Nothing selected yet."
                 : "\(model.blockedCount) selected — apps, categories and sites.")
                .font(.subheadline)
                .foregroundColor(Theme.muted)

            Button {
                model.isPickerPresented = true
            } label: {
                Text(model.blockedCount == 0 ? "Choose apps" : "Edit selection")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.accent.opacity(0.18),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundColor(Theme.accent)
            }
        }
    }

    private var statusCard: some View {
        Card {
            Toggle(isOn: Binding(
                get: { model.state.blockingEnabled },
                set: { model.setBlocking($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Block these apps").font(.headline)
                    Text("Stays on until you spend a break.")
                        .font(.caption)
                        .foregroundColor(Theme.muted)
                }
            }
            .tint(Theme.accent)
            .disabled(model.blockedCount == 0)
        }
    }

    private var breaksCard: some View {
        Card {
            HStack {
                Label("Breaks today", systemImage: "cup.and.saucer.fill")
                    .font(.headline)
                Spacer()
                breakPips
            }

            if model.isOnBreak {
                activeBreak
            } else {
                idleBreak
            }
        }
    }

    /// One dot per allowed break; spent ones hollow out. Faster to read than
    /// "2/3", and the row length itself shows the configured allowance.
    private var breakPips: some View {
        HStack(spacing: 6) {
            ForEach(0..<model.settings.breaksPerDay, id: \.self) { index in
                Circle()
                    .fill(index < model.breaksRemaining ? Theme.accent : Color.white.opacity(0.15))
                    .frame(width: 10, height: 10)
            }
        }
    }

    private var activeBreak: some View {
        VStack(spacing: 14) {
            Text(model.countdownText)
                .font(.system(size: 52, weight: .semibold, design: .rounded))
                .monospacedDigit()

            Text("Break running")
                .font(.caption)
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)

            Button(role: .destructive) {
                model.endBreakEarly()
            } label: {
                Text("End break now")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var idleBreak: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Second route into settings, right next to the number it changes —
            // the gear alone makes you go looking for it.
            NavigationLink {
                SettingsView()
            } label: {
                HStack(spacing: 6) {
                    Text("Each break lasts")
                        .foregroundColor(Theme.muted)
                    Spacer()
                    Text("\(model.settings.breakMinutes) min")
                        .font(.headline.monospacedDigit())
                        .foregroundColor(.white)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundColor(Theme.muted)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider().overlay(Color.white.opacity(0.08))
            valueRow("Breaks per day", "\(model.settings.breaksPerDay)")

            Divider().overlay(Color.white.opacity(0.08))
            valueRow("Wait between breaks", "\(model.settings.cooldownMinutes) min")

            Button {
                model.startBreak()
            } label: {
                Text(startButtonTitle)
                    .font(.headline)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        model.canStartBreak ? Theme.accent : Color.white.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .foregroundColor(model.canStartBreak ? .white : Theme.muted)
            }
            .disabled(!model.canStartBreak)
            .padding(.top, 8)

            if model.isCoolingDown {
                Text("Breaks are spaced out so you can't take them back to back.")
                    .font(.caption)
                    .foregroundColor(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 6)
            }
        }
    }

    /// The button doubles as the cooldown readout — a disabled control with no
    /// explanation is the thing that makes an app feel broken.
    private var startButtonTitle: String {
        if model.isCoolingDown {
            return "Next break in \(model.cooldownText)"
        }
        if model.breaksRemaining == 0 {
            return "No breaks left today"
        }
        return "Start \(model.settings.breakMinutes)-minute break"
    }

    private func valueRow(_ title: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .foregroundColor(Theme.muted)
            Spacer()
            Text(value)
                .font(.headline.monospacedDigit())
        }
        .padding(.vertical, 8)
    }

    private var footnote: some View {
        Text("Breaks reset at midnight. Tap the gear to change how many you get and how long they last. You can also start one straight from the block screen without opening ScreenBlock.")
            .font(.caption)
            .foregroundColor(Theme.muted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }
}
