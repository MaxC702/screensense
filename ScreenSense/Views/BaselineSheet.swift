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

                    Text("A rough answer is enough — the rungs move in fifths, not minutes. You can change it whenever you like.")
                        .font(.system(size: 11.5))
                        .foregroundColor(Theme.faint)
                        .fixedSize(horizontal: false, vertical: true)
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
            Text("How long were you spending in these apps on a normal day?")
                .font(Theme.display(19, .medium))
                .fixedSize(horizontal: false, vertical: true)

            // Says what the answer is *for*. Without this it reads as data
            // collection, which is the one thing this app must never look like.
            Text("The flame measures how far you have come down from your own starting point, not how you compare to anyone else. Six hours down to forty minutes a day is a harder thing to do than ninety minutes down to forty, and this is what lets the ladder tell them apart.")
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
            HStack(alignment: .top, spacing: 11) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(band.title)
                        .font(Theme.display(16, .medium))
                        .foregroundColor(.white)
                    Text(band.detail)
                        .font(.system(size: 11.5))
                        .foregroundColor(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    // The hardest rung, named up front. A ladder is easier to
                    // agree to when the top of it is not a surprise.
                    Text("Blue flame at \(band.topRungMinutes) min a day")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(StreakLevel.blueFlame.tint.opacity(0.9))
                }
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
