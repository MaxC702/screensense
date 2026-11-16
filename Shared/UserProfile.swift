import Foundation

/// What the user told onboarding about themselves.
///
/// Lives in the App Group, beside the break state, rather than in the app's own
/// defaults: the block screen is drawn by the shield extension, and the reasons
/// are there to be shown back at exactly that moment.
struct UserProfile: Codable, Equatable {
    var name: String = ""
    var reasons: [Reason] = []
    /// What they typed when they picked `.other`. Kept even if `.other` is
    /// unticked, so ticking it again does not lose what they wrote.
    var otherReason: String = ""
    var role: Role?
    /// Ids of the things they would do with an extra hour.
    var activities: [String] = []

    static let otherReasonLimit = 60

    init() {}

    /// The name as it should be printed, or `nil` if none was given.
    var firstName: String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// The typed reason, or `nil` if `.other` is not picked or nothing was typed.
    var typedReason: String? {
        guard reasons.contains(.other) else { return nil }
        let trimmed = otherReason.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Field by field, and tolerant of ids this build does not know, so a
    /// profile written by a newer or older build never fails to decode and
    /// silently comes back empty.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        reasons = (try container.decodeIfPresent([String].self, forKey: .reasons) ?? [])
            .compactMap(Reason.init(rawValue:))
        otherReason = try container.decodeIfPresent(String.self, forKey: .otherReason) ?? ""
        role = (try container.decodeIfPresent(String.self, forKey: .role)).flatMap(Role.init(rawValue:))
        activities = try container.decodeIfPresent([String].self, forKey: .activities) ?? []
    }

    enum Reason: String, Codable, CaseIterable, Identifiable {
        case focus, sleep, present, scroll, mood, hobby, other

        var id: String { rawValue }

        /// As it reads in the list someone picks from.
        var title: String {
            switch self {
            case .focus: return "Focus on school or work"
            case .sleep: return "Sleep better"
            case .present: return "Be present with people"
            case .scroll: return "Stop doomscrolling"
            case .mood: return "Stop feeling bad after using my phone"
            case .hobby: return "Get back to a hobby"
            case .other: return "Other"
            }
        }
    }

    enum Role: String, Codable, CaseIterable, Identifiable {
        case school, college, work, other

        var id: String { rawValue }
    }
}
