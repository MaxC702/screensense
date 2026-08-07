import DeviceActivity
import Foundation

/// Runs out-of-process, woken by the system. This is the component that makes
/// the block trustworthy: it re-applies the shield even if ScreenBlock has been
/// force-quit, backgrounded for days, or never reopened after the break started.
///
/// Keep the work here short and synchronous — the system gives these extensions
/// a very small execution budget before killing them.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    /// Fires once the user has spent their break's worth of *usage* in the
    /// blocked apps. This is the primary trigger, and the only one that can
    /// express a break shorter than 15 minutes.
    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
        guard activity == .breakWindow, event == .breakUsage else { return }
        BreakEngine.endBreak()
    }

    /// Backstop. The monitoring window is padded to iOS's 15-minute minimum, so
    /// this closes out a break whose threshold never tripped — for example when
    /// the user started a break and then never opened the blocked app.
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == .breakWindow else { return }
        BreakEngine.endBreak()
    }
}
