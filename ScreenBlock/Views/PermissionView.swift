import FamilyControls
import SwiftUI

/// Gate shown until the user grants Screen Time authorization.
///
/// Without `.approved`, `FamilyActivityPicker` shows nothing and every write to
/// `ManagedSettingsStore` is silently ignored — so there is no useful UI to show
/// behind this screen.
struct PermissionView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 62))
                .foregroundStyle(Theme.gradient)

            VStack(spacing: 10) {
                Text("ScreenBlock needs Screen Time access")
                    .font(Theme.display(22, .medium))
                    .multilineTextAlignment(.center)

                Text("iOS handles the blocking itself. ScreenBlock never sees which apps you pick — it only receives anonymous handles from the system.")
                    .font(.subheadline)
                    .foregroundColor(Theme.muted)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            if model.authorizationStatus == .denied {
                Text("Access was denied. Open Settings › Screen Time to allow it, then come back.")
                    .font(.footnote)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await model.requestAuthorization() }
            } label: {
                Text("Grant access")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .shadow(color: Theme.accent.opacity(0.35), radius: 14, y: 6)
            }
            .foregroundColor(.white)
        }
        .padding(28)
    }
}
