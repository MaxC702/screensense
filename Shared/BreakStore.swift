import FamilyControls
import Foundation

/// Persistence for the shared container.
///
/// Backed by files in the App Group container rather than by `UserDefaults`,
/// because four processes read this and only one of them is long-lived.
///
/// `UserDefaults` serves reads from a per-process snapshot that another
/// process's write does not invalidate. `synchronize()` is supposed to be the
/// lever for that and is unreliable in practice — which showed up as a shield
/// extension the system had kept warm going on drawing a break count that had
/// already been spent, and only telling the truth again once the blocked app was
/// relaunched and the extension came up fresh.
///
/// A file has no such snapshot. Every read here goes to the filesystem, and
/// every write is atomic and complete before it returns, so a process the system
/// kills a millisecond later cannot lose it.
enum BreakStore {
    // Legacy `UserDefaults` keys. Only read now, and only until each payload has
    // been migrated to its file on first load.
    private static let stateKey = "screenblock.state.v1"
    private static let selectionKey = "screenblock.selection.v1"
    private static let settingsKey = "screenblock.settings.v1"

    private static let stateFile = "state.v1.json"
    private static let selectionFile = "selection.v1.json"
    private static let settingsFile = "settings.v1.json"

    // MARK: - Settings

    static func loadSettings() -> BreakSettings {
        load(BreakSettings.self, file: settingsFile, legacyKey: settingsKey) ?? BreakSettings()
    }

    static func saveSettings(_ settings: BreakSettings) {
        write(settings, file: settingsFile)
    }

    // MARK: - Break state

    static func loadState(now: Date = .now) -> BreakState {
        var state = load(BreakState.self, file: stateFile, legacyKey: stateKey) ?? BreakState()

        // Lazy daily reset: whoever reads first after midnight performs it.
        let previous = state
        state.rollDayIfNeeded(now: now)
        if state != previous { save(state) }
        return state
    }

    static func save(_ state: BreakState) {
        write(state, file: stateFile)
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
        load(FamilyActivitySelection.self, file: selectionFile, legacyKey: selectionKey)
            ?? FamilyActivitySelection()
    }

    static func saveSelection(_ selection: FamilyActivitySelection) {
        write(selection, file: selectionFile)
    }

    // MARK: - Files

    /// The App Group container. `nil` only if the group is not provisioned for
    /// this target, which is a build-configuration bug rather than a runtime
    /// condition — `AppIdentifiers` asserts on it for the same reason.
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppIdentifiers.appGroup)
    }

    private static func url(for file: String) -> URL? {
        containerURL?.appendingPathComponent(file, isDirectory: false)
    }

    /// File first, then the payload an earlier build left in `UserDefaults`.
    ///
    /// The fallback is the whole migration: the first read after upgrading finds
    /// no file, decodes the old defaults payload, and the next write puts it on
    /// disk where every later read will find it. Nothing is deleted, so a build
    /// that failed to write its file reads the old value rather than a default.
    private static func load<T: Decodable>(_ type: T.Type, file: String, legacyKey: String) -> T? {
        if let url = url(for: file),
           let data = try? Data(contentsOf: url),
           let value = try? JSONDecoder().decode(type, from: data) {
            return value
        }
        if let data = UserDefaults.shared.freshData(forKey: legacyKey),
           let value = try? JSONDecoder().decode(type, from: data) {
            // Migrate on the spot rather than waiting for something to save.
            // Plenty of reads never write, and until the file exists every one of
            // them is back on the snapshot this change exists to get away from.
            if let url = url(for: file) { try? data.write(to: url, options: .atomic) }
            return value
        }
        return nil
    }

    /// Atomic, so a reader in another process sees either the whole previous
    /// payload or the whole new one — never half of each.
    private static func write<T: Encodable>(_ value: T, file: String) {
        guard let url = url(for: file), let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: .atomic)
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
