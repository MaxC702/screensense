import Foundation
import os

/// A small shared event log.
///
/// The three extensions run out-of-process, for a few hundred milliseconds, when
/// the system decides — you cannot attach a debugger to them and print statements
/// go nowhere you can read. So each interesting moment is appended here, in the
/// App Group, where the app can display it afterwards.
///
/// This exists to answer one question that cannot be answered from the outside:
/// when a break expires while the user sits inside a blocked app, did our code
/// run late, or did it run on time and iOS decline to draw the shield over an app
/// already on screen? Those have different fixes.
enum BreakLog {
    private static let key = "screenblock.log.v1"
    private static let limit = 80

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "screenblock",
        category: "break"
    )

    struct Entry: Codable, Identifiable {
        var at: Date
        var source: String
        var message: String

        var id: String { "\(at.timeIntervalSince1970)-\(source)-\(message)" }
    }

    /// `source` names the process, since which one of the four ran is usually the
    /// whole point of reading this.
    static func record(_ message: String, source: String, now: Date = .now) {
        logger.log("[\(source, privacy: .public)] \(message, privacy: .public)")

        var entries = load()
        entries.append(Entry(at: now, source: source, message: message))
        if entries.count > limit {
            entries.removeFirst(entries.count - limit)
        }
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.shared.set(data, forKey: key)
    }

    static func load() -> [Entry] {
        guard let data = UserDefaults.shared.data(forKey: key),
              let entries = try? JSONDecoder().decode([Entry].self, from: data)
        else { return [] }
        return entries
    }

    static func clear() {
        UserDefaults.shared.removeObject(forKey: key)
    }
}
