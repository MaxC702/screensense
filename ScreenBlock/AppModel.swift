import Combine
import FamilyControls
import Foundation
import SwiftUI

/// View-facing state for the container app.
///
/// The app is intentionally *not* the source of truth — `BreakStore` is, because
/// extensions mutate it while the app isn't running. This model reloads from the
/// store on every foreground rather than trusting what it last held in memory.
@MainActor
final class AppModel: ObservableObject {

    @Published private(set) var state: BreakState
    @Published private(set) var settings: BreakSettings
    @Published private(set) var authorizationStatus: AuthorizationStatus
    @Published var selection: FamilyActivitySelection
    @Published var isPickerPresented = false
    @Published var errorMessage: String?

    /// Drives the countdown label. Republished every second only while a break
    /// is actually running.
    @Published private(set) var now: Date = .now

    private var ticker: AnyCancellable?

    init() {
        state = BreakStore.loadState()
        settings = BreakStore.loadSettings()
        selection = BreakStore.loadSelection()
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    // MARK: - Derived

    var isAuthorized: Bool {
        authorizationStatus == .approved || PreviewEnvironment.isSimulator
    }

    var blockedCount: Int {
        if PreviewEnvironment.isSimulator, selection.isEmpty {
            return PreviewEnvironment.stubBlockedItemCount
        }
        return selection.blockedItemCount
    }
    var isOnBreak: Bool { state.isOnBreak(now: now) }
    var isCoolingDown: Bool { state.isCoolingDown(now: now) }
    var breaksRemaining: Int { state.breaksRemaining(limit: settings.breaksPerDay) }
    var canStartBreak: Bool { breaksRemaining > 0 && !isCoolingDown && state.blockingEnabled }

    var countdownText: String {
        BreakState.countdown(from: state.remainingBreakSeconds(now: now))
    }

    var cooldownText: String {
        BreakState.countdown(from: state.remainingCooldownSeconds(now: now))
    }

    /// How much of the running break is left, 0...1, for the ring on the home
    /// screen. Zero when no break is running, which draws no arc at all.
    var breakProgress: Double {
        let total = Double(settings.breakMinutes * 60)
        guard total > 0 else { return 0 }
        return min(1, max(0, state.remainingBreakSeconds(now: now) / total))
    }

    // MARK: - Authorization

    /// `.individual` asks the current user to authorize restricting *their own*
    /// device. The `.child` variant would require a parent's Apple ID and is not
    /// what a self-control app wants.
    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            errorMessage = "Screen Time access was denied. Enable it in Settings › Screen Time, then reopen ScreenBlock."
        }
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    // MARK: - Lifecycle

    /// Called on launch and every foreground. Repairs any break that expired
    /// while the app was closed, then re-reads whatever the extensions wrote.
    func refresh() {
        BreakEngine.reconcile()
        state = BreakStore.loadState()
        settings = BreakStore.loadSettings()
        selection = BreakStore.loadSelection()
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        now = .now
        updateTicker()
    }

    /// Runs while either countdown is live — the break, or the cooldown that
    /// follows it.
    private func updateTicker() {
        let needsTicking = state.isOnBreak(now: .now) || state.isCoolingDown(now: .now)
        guard needsTicking else {
            ticker = nil
            return
        }
        guard ticker == nil else { return }

        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                guard let self else { return }
                self.now = date

                // The in-app countdown hitting zero is a display concern; the
                // authoritative re-block comes from the monitor extension.
                // Reconciling here turns the finished break into a cooldown so
                // the UI doesn't briefly offer a break it would then refuse.
                if self.state.breakEndsAt != nil, !self.state.isOnBreak(now: date) {
                    self.refresh()
                    return
                }

                if !self.state.isOnBreak(now: date), !self.state.isCoolingDown(now: date) {
                    self.ticker = nil
                }
            }
    }

    // MARK: - Actions

    func commitSelection() {
        BreakStore.saveSelection(selection)
        // Re-apply immediately so newly added apps are blocked without waiting
        // for a toggle, but never while a break is in flight.
        if state.blockingEnabled, !state.isOnBreak(now: .now) {
            ShieldController.applyShield()
        }
        state = BreakStore.loadState()
    }

    func setBlocking(_ enabled: Bool) {
        guard !(enabled && selection.isEmpty && !PreviewEnvironment.isSimulator) else {
            errorMessage = BreakEngine.BreakError.noAppsSelected.errorDescription
            return
        }

        state = BreakStore.mutate { $0.blockingEnabled = enabled }

        if enabled {
            if !state.isOnBreak(now: .now) { ShieldController.applyShield() }
        } else {
            ShieldController.clearShield()
        }
    }

    func startBreak() {
        do {
            state = try BreakEngine.startBreak()
            now = .now
            updateTicker()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Settings

    /// Writes through to the shared container immediately, so the shield
    /// extension picks the change up on its very next launch — there is no
    /// "apply" step and no window where the two disagree.
    func updateSettings(_ body: (inout BreakSettings) -> Void) {
        var updated = settings
        body(&updated)
        updated.breaksPerDay = BreakRules.clampBreaksPerDay(updated.breaksPerDay)
        updated.breakMinutes = BreakRules.clampMinutes(updated.breakMinutes)
        guard updated != settings else { return }
        settings = updated
        BreakStore.saveSettings(updated)
    }

    /// Ending early does **not** refund the break — that's the point of a budget.
    func endBreakEarly() {
        BreakEngine.endBreak()
        refresh()
    }
}
