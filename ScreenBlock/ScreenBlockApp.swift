import SwiftUI

@main
struct ScreenBlockApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
                .task { model.refresh() }
                .onChange(of: scenePhase) { phase in
                    // Extensions may have ended a break, and the day may have
                    // rolled over, while this process was suspended.
                    if phase == .active { model.refresh() }
                }
        }
    }
}
