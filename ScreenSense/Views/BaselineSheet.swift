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
                VStack(alignment: .leading, spacing: 0) {
                    preamble

                    RuledList {
                        ForEach(ScreenTimeBand.allCases, id: \.rawValue) { band in
                            option(band)
                        }
                    }
                    .padding(.top, 32)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Theme.background.ignoresSafeArea())
            .pushedScreen("Where you started")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Not now") { dismiss() }
                        .foregroundColor(Theme.muted)
                }
            }
        }
        .foregroundColor(Theme.foreground)
        .tint(Theme.muted)
    }

    private var preamble: some View {
        VStack(alignment: .leading, spacing: 12) {
            // In the page rather than the bar, where iOS 26 squeezes a
            // leading title into a button-sized bubble.
            SectionLabel("Where you started")
                .padding(.bottom, -4)
            Text("How long do you usually spend on these specific apps per day?")
                .font(Theme.display(30))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            // Says what the answer is *for*. Without this it reads as data
            // collection, which is the one thing this app must never look like.
            Text("The flame measures how far you have come down from your own starting point.")
                .font(.system(size: 15))
                .lineSpacing(3)
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
            HStack(spacing: 12) {
                // The answers say what they are. Anything written underneath
                // them was commentary on the user's habits, which is not this
                // screen's business and reads as a judgement while they are
                // still deciding which one is true.
                Text(band.title)
                    .font(.system(size: 17))
                    .foregroundColor(chosen ? Theme.foreground : Theme.muted)
                Spacer(minLength: 0)
                ZStack {
                    Circle()
                        .fill(chosen ? Theme.foreground : Color.clear)
                    Circle()
                        .strokeBorder(chosen ? Theme.foreground : Theme.hairline, lineWidth: 1)
                    if chosen {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.background)
                    }
                }
                .frame(width: 22, height: 22)
            }
            .frame(height: 60)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rule() }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }
}
