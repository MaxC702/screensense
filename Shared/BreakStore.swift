import FamilyControls
import Foundation

/// Persistence for the shared container.
///
/// Extensions are short-lived processes that the system spawns, runs for a few
/// hundred milliseconds, and kills. There is deliberately no in-memory cache
/// here: every read goes to disk, because a cached value in one process is
/// always stale the moment another process writes.
enum BreakStore {
    private static let stateKey = "screenblock.state.v1"
    private static let selectionKey = "screenblock.selection.v1"
    private static let settingsKey = "screenblock.settings.v1"

    // MARK: - Settings

    static func loadSettings() -> BreakSettings {
        guard let data = UserDefaults.shared.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(BreakSettings.self, from: data)
        else { return BreakSettings() }
        return settings
    }

    static func saveSettings(_ settings: BreakSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.shared.set(data, forKey: settingsKey)
    }

    // MARK: - Break state

    static func loadState(now: Date = .now) -> BreakState {
        var state: BreakState
        if let data = UserDefaults.shared.data(forKey: stateKey),
           let decoded = try? JSONDecoder().decode(BreakState.self, from: data) {
            state = decoded
        } else {
            state = BreakState()
        }

        // Lazy daily reset: whoever reads first after midnight performs it.
        let previous = state
        state.rollDayIfNeeded(now: now)
        if state != previous { save(state) }
        return state
    }

    static func save(_ state: BreakState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.shared.set(data, forKey: stateKey)
    }

    /// Read-modify-write in one call so callers can't accidentally save a state
    /// they loaded before some other process changed it.
    @discardableResult
    static func mutate(now: Date = .now, _ body: (inout BreakState) -> Void) -> BreakState {
        var state = loadState(now: now)
        body(&state)
        save(state)
        return state
    }

    // MARK: - Selected apps

    /// `FamilyActivitySelection` is `Codable`, but what it encodes are opaque,
    /// device-bound tokens — not bundle identifiers. They cannot be inspected,
    /// logged, or moved to another device, which is the whole privacy contract
    /// of FamilyControls.
    static func loadSelection() -> FamilyActivitySelection {
        guard let data = UserDefaults.shared.data(forKey: selectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return FamilyActivitySelection() }
        return selection
    }

    static func saveSelection(_ selection: FamilyActivitySelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        UserDefaults.shared.set(data, forKey: selectionKey)
    }
}

extension FamilyActivitySelection {
    /// How many distinct things the user picked. Apps, whole categories, and
    /// websites all count — there is no cap on any of them.
    var blockedItemCount: Int {
        applicationTokens.count + categoryTokens.count + webDomainTokens.count
    }

    var isEmpty: Bool { blockedItemCount == 0 }
}
