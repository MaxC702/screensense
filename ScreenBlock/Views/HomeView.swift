import FamilyControls
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
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
        .familyActivityPicker(isPresented: $model.isPickerPresented, selection: $model.selection)
        .onChange(of: model.isPickerPresented) { presented in
            // Commit when Apple's picker dismisses rather than on every keystroke
            // inside it — the picker mutates the binding continuously.
            if !presented { model.commitSelection() }
        }
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
                breakPicker
            }
        }
    }

    /// Three dots — spent breaks hollow out. Faster to read than "2/3".
    private var breakPips: some View {
        HStack(spacing: 6) {
            ForEach(0..<BreakRules.breaksPerDay, id: \.self) { index in
                Circle()
                    .fill(index < model.state.breaksRemaining ? Theme.accent : Color.white.opacity(0.15))
                    .frame(width: 10, height: 10)
            }
        }
    }

    private var activeBreak: some View {
        VStack(spacing: 14) {
            Text(model.countdownText)
                .font(.system(size: 52, weight: .semibold, design: .rounded))
                .monospacedDigit()

            Text("Break running. Ends sooner if you spend the time in the blocked apps.")
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

    private var breakPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Length")
                    .foregroundColor(Theme.muted)
                Spacer()
                Text("\(Int(model.draftMinutes)) min")
                    .font(.headline.monospacedDigit())
            }

            Slider(
                value: $model.draftMinutes,
                in: Double(BreakRules.minMinutes)...Double(BreakRules.maxMinutes),
                step: 1
            )
            .tint(Theme.accent)

            Button {
                model.startBreak()
            } label: {
                Text(model.state.breaksRemaining > 0 ? "Start break" : "No breaks left today")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        model.state.breaksRemaining > 0 ? Theme.accent : Color.white.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .foregroundColor(model.state.breaksRemaining > 0 ? .white : Theme.muted)
            }
            .disabled(model.state.breaksRemaining == 0 || !model.state.blockingEnabled)
        }
    }

    private var footnote: some View {
        Text("Breaks reset at midnight. You can also start one straight from the block screen without opening ScreenBlock.")
            .font(.caption)
            .foregroundColor(Theme.muted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }
}
