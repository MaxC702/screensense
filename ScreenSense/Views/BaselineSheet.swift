import SwiftUI

/// The one question the ladder needs answering: how much were you on these apps
/// before?
///
/// Put on the Streak tab rather than during setup, and only once the flame is
/// there to be looked at. Asked cold it is a survey question; asked next to the
/// thing it changes, it is obviously the dial that makes the thing mean
/// something. Nothing else in the app is gated on it — an unanswered ladder runs
/// on the middle band and works fine, which is why this can afford to be a
/// question rather than a wall.
struct BaselineSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    preamble

                    VStack(spacing: 9) {
                        ForEach(ScreenTimeBand.allCases, id: \.rawValue) { band in
                            option(band)
                        }
                    }

                }
                .padding(17)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Where you started")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                        .foregroundColor(Theme.muted)
                }
            }
        }
        .tint(Theme.accentSoft)
    }

    private var preamble: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How long do you usually spend on these specific apps per day?")
                .font(Theme.display(19, .medium))
                .fixedSize(horizontal: false, vertical: true)

            // Says what the answer is *for*. Without this it reads as data
            // collection, which is the one thing this app must never look like.
            Text("The flame measures how far you have come down from your own starting point.")
                .font(.system(size: 12.5))
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func option(_ band: ScreenTimeBand) -> some View {
        let chosen = model.hasChosenBaseline && model.baselineBand == band

        return Button {
            model.chooseBaseline(band)
            dismiss()
        } label: {
            HStack(spacing: 11) {
                // The answers say what they are. Anything written underneath
                // them was commentary on the user's habits, which is not this
                // screen's business and reads as a judgement while they are
                // still deciding which one is true.
                Text(band.title)
                    .font(Theme.display(16, .medium))
                    .foregroundColor(.white)
                Spacer(minLength: 0)
                Image(systemName: chosen ? "checkmark.circle.fill" : "chevron.right")
                    .font(.system(size: chosen ? 17 : 12, weight: .semibold))
                    .foregroundColor(chosen ? Theme.accentSoft : Theme.faint)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(chosen ? Theme.accentSoft.opacity(0.5) : Theme.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
