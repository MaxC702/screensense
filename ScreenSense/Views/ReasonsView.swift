import SwiftUI

/// The answers to "why did you get ScreenSense", editable after onboarding,
/// because the reasons someone has in week one are not always the ones they
/// have in month three.
struct ReasonsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenTitle("Your reasons")
                Text("Pick any. The block screen shows them back to you.")
                    .font(.system(size: 15))
                    .lineSpacing(3)
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, -12)
                    .padding(.bottom, 24)
                ReasonList()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background.ignoresSafeArea())
        .pushedScreen("Your reasons")
    }
}

extension UserProfile {
    /// The reasons in a few words for a settings row: the first two, then a
    /// count of the rest.
    var reasonsSummary: String {
        let titles = reasons.map { reason in
            reason == .other ? (typedReason ?? reason.title) : reason.title
        }
        switch titles.count {
        case 0: return "None picked"
        case 1, 2: return titles.joined(separator: ", ")
        default: return titles.prefix(2).joined(separator: ", ") + " and \(titles.count - 2) more"
        }
    }
}
