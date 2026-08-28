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

    /// Days blocking has been left switched on, counting today.
    var streakDays: Int { state.streakDays(now: now) }
    var bestStreak: Int { state.bestStreak }

    /// True for the rest of a day a run was lost on, whether or not blocking has
    /// since gone back on. The count is held at zero and the flame is out for
    /// all of it — this is what lets the screens say so rather than looking as
    /// though the badge has simply failed to light.
    var streakBrokenToday: Bool { state.streakBrokenToday(now: now) }

    /// What the budget on its own is worth — the level of someone who spends
    /// every minute they allow themselves. Settings shows this, because that is
    /// the screen that sets it, and it moves under the sliders as they drag.
    var configuredStreakLevel: StreakLevel { StreakLevel.level(for: settings) }

    /// What the last week of finished days actually came to.
    ///
    /// This is the number the flame is really about. A generous budget spent
    /// sparingly outranks a tight one spent to the last minute, because a budget
    /// is a promise and this is the record.
    ///
    /// Falls back to the budget until a day has finished — with nothing on the
    /// board, what you set for yourself is the only evidence there is.
    var earnedStreakLevel: StreakLevel {
        guard let average = averageUnblockedMinutes else { return configuredStreakLevel }
        return StreakLevel.level(forDailyMinutes: average)
    }

    /// Unblocked minutes a day across the finished days of this run; `nil` while
    /// the run is still on its first day.
    var averageUnblockedMinutes: Double? { state.averageUnblockedMinutes(now: now) }

    /// Minutes already spent today, which the average deliberately excludes.
    var minutesUsedToday: Int { state.unblocked(on: BreakState.dayKey(for: now)) }

    /// What the flame shows: what was earned, less whatever is still owed for a
    /// lost run.
    var streakLevel: StreakLevel {
        earnedStreakLevel.lowered(by: state.activeLevelPenalty(now: now))
    }

    /// How full the current rung is, 0...1; `nil` when no run is going and there
    /// are no minutes to place.
    ///
    /// Measured against the level actually on show, so during a relight — when
    /// the flame sits a rung below what the minutes earn — it reads full, which
    /// is true: those minutes are comfortably inside that band.
    var levelCharge: Double? {
        guard let average = averageUnblockedMinutes else { return nil }
        return streakLevel.chargeFraction(atDailyMinutes: average)
    }

    /// Minutes a day still available before the flame drops a rung; `nil` at the
    /// bottom of the ladder, or with no run going.
    var levelHeadroom: Double? {
        guard let average = averageUnblockedMinutes else { return nil }
        return streakLevel.headroom(atDailyMinutes: average)
    }

    /// True only while the penalty is really costing a rung. At the bottom of
    /// the ladder there is nothing left to dock, and announcing a demotion the
    /// badge cannot show would be a lie.
    var isRelighting: Bool { streakLevel < earnedStreakLevel }
    var daysToRelight: Int { state.daysToRelight(now: now) }

    /// One point per day for the graph, oldest first. A `nil` level is a day the
    /// app cannot speak for, and the line breaks across it rather than guessing.
    func dailyLevels(days: Int) -> [DayPoint] {
        let calendar = Calendar.current
        return stride(from: days - 1, through: 0, by: -1).compactMap { back -> DayPoint? in
            guard let date = calendar.date(byAdding: .day, value: -back, to: now) else { return nil }
            let key = BreakState.dayKey(for: date, calendar: calendar)
            guard state.hasRecord(for: date, now: now, calendar: calendar) else {
                return DayPoint(date: date, key: key, minutes: nil, level: nil)
            }
            let minutes = state.unblocked(on: key)
            return DayPoint(
                date: date,
                key: key,
                minutes: minutes,
                level: StreakLevel.level(forDailyMinutes: Double(minutes))
            )
        }
    }

    /// One day on the streak graph.
    struct DayPoint: Identifiable {
        let date: Date
        let key: String
        /// `nil` on a day the app was not watching.
        let minutes: Int?
        let level: StreakLevel?

        var id: String { key }
    }
    var dailyUnblockedMinutes: Int { StreakLevel.dailyMinutes(for: settings) }
    var minutesToNextLevel: Int? { StreakLevel.minutesToNextLevel(from: settings) }
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
            errorMessage = "Screen Time access was denied. Enable it in Settings › Screen Time, then reopen ScreenSense."
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

        // The streak moves in the same read-modify-write as the switch itself,
        // so there is no instant where the two disagree about whether a run is
        // in progress.
        state = BreakStore.mutate { state in
            state.blockingEnabled = enabled
            if enabled {
                state.beginStreakIfNeeded()
            } else {
                state.endStreak()
            }
        }

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
    ///
    /// The only call site allowed past `endBreak`'s early-trigger guard, because
    /// it is the only one that is a decision rather than a report.
    func endBreakEarly() {
        BreakEngine.endBreak(source: "app/user", allowEarly: true)
        refresh()
    }
}
