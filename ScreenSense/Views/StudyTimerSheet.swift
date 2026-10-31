import SwiftUI

/// Picks a study length that isn't one of the buttons, and keeps the buttons
/// themselves: up to three lengths of the user's own, in place of 25, 50 and 90.
///
/// One sheet for both because they are the same decision seen twice — "this
/// length, now" and "this length, again later" — and a length worth saving is
/// usually found by picking it here first.
struct StudyTimerSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var minutes: Int

    /// Starts on the length last picked, so reopening to tweak it is a nudge
    /// of the wheel rather than a scroll from the top.
    init(startingAt minutes: Int) {
        _minutes = State(initialValue: BreakRules.validStudyMinutes(minutes))
    }

    private var presets: [Int] { model.settings.studyPresets }
    private var isSaved: Bool { presets.contains(minutes) }
    private var isFull: Bool { presets.count >= BreakRules.maxStudyPresets }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ScreenTitle("Custom session")

                    StudyDial(minutes: $minutes)
                        .frame(maxWidth: .infinity)

                    startButton
                        .padding(.top, 32)
                    saveButton
                        .padding(.top, 8)

                    SectionLabel("My timers")
                        .padding(.top, 32)
                    RuledList {
                        ForEach(presets, id: \.self) { preset in
                            presetRow(preset)
                        }
                    }
                    Text(timersNote)
                        .font(.system(size: 13))
                        .lineSpacing(2)
                        .foregroundColor(Theme.faint)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .background(Theme.background.ignoresSafeArea())
            .pushedScreen("Custom session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.muted)
                }
            }
        }
        .foregroundColor(Theme.foreground)
        .tint(Theme.muted)
    }

    // MARK: - Actions

    private var startButton: some View {
        Button("Start \(BreakRules.studyLengthText(minutes)) session") {
            model.startStudy(minutes: minutes)
            dismiss()
        }
        .buttonStyle(PillButtonStyle())
        .disabled(!model.canStartStudy)
    }

    /// Saving also picks it, so closing the sheet leaves it ready to start.
    private var saveButton: some View {
        Button {
            model.updateSettings {
                $0.studyPresets.append(minutes)
                $0.studyMinutes = minutes
            }
        } label: {
            Label(saveTitle, systemImage: isSaved ? "checkmark" : "plus")
                .font(.system(size: 14, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .foregroundColor(isSaved || isFull ? Theme.faint : Theme.muted)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isSaved || isFull)
    }

    private var saveTitle: String {
        if isSaved { return "In my timers" }
        if isFull { return "My timers are full" }
        return "Save to my timers"
    }

    // MARK: - My timers

    private func presetRow(_ preset: Int) -> some View {
        HStack {
            Text(BreakRules.studyLengthText(preset))
                .font(.system(size: 17))
                .monospacedDigit()
            Spacer(minLength: 0)
            // The last one stays: the row on the home screen needs at least
            // one length besides Custom to make sense.
            if presets.count > 1 {
                Button {
                    model.updateSettings { $0.studyPresets.removeAll { $0 == preset } }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.muted)
                        .frame(width: 26, height: 26)
                        .overlay(Circle().stroke(Theme.hairline, lineWidth: 1))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(BreakRules.studyLengthText(preset))")
            }
        }
        .ruledRow()
    }

    private var timersNote: String {
        if isFull {
            return "Up to \(BreakRules.maxStudyPresets). Remove one to make room for another."
        }
        return "Up to \(BreakRules.maxStudyPresets), shown as buttons on the home screen. Keep just one if that's all you use."
    }
}
