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
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            Image(systemName: "checkmark.shield")
                .font(.system(size: 22, weight: .light))
                .frame(width: 52, height: 52)
                .overlay(Circle().stroke(Theme.hairline, lineWidth: 1))

            Text("ScreenSense needs Screen Time access")
                .font(Theme.display(32))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 32)

            Text("iOS handles the blocking itself. ScreenSense never sees which apps you pick — it only receives anonymous handles from the system.")
                .font(.system(size: 15))
                .lineSpacing(3)
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)

            Spacer()

            if model.authorizationStatus == .denied {
                Text("Access was denied. Open Settings › Screen Time to allow it, then come back.")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.streak)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 16)
            }

            Button("Grant access") {
                Task { await model.requestAuthorization() }
            }
            .buttonStyle(PillButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
}
