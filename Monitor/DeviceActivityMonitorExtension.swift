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
        BreakLog.record("usage threshold reached", source: "monitor")
        BreakEngine.endBreak(source: "monitor/threshold")
    }

    /// The punctual one. `.breakEnd` is an interval scheduled to *begin* exactly
    /// when the break's wall clock runs out, so this fires at that moment
    /// regardless of what the user is doing — including while they are still
    /// inside a blocked app, which is precisely when the block needs to return.
    ///
    /// `.breakWindow` also reports a start (it begins when the break does), so
    /// the guard matters: ending the break the instant it started would make
    /// every break zero-length.
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity == .breakEnd else { return }
        BreakLog.record("resume interval started — break is over", source: "monitor")
        BreakEngine.endBreak(source: "monitor/resume")
    }

    /// Backstop. The monitoring window is padded to iOS's 15-minute minimum, so
    /// this closes out a break whose threshold never tripped — for example when
    /// the user started a break and then never opened the blocked app.
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == .breakWindow else { return }
        BreakLog.record("padded window ended (backstop)", source: "monitor")
        BreakEngine.endBreak(source: "monitor/backstop")
    }
}
