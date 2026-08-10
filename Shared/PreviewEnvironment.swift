import Foundation

/// Whether the Screen Time APIs are actually usable in this process.
///
/// In the iOS Simulator they are inert: authorization can never be granted,
/// `FamilyActivityPicker` returns nothing, and `DeviceActivityCenter` refuses to
/// schedule. That leaves the real app permanently stuck on the permission gate,
/// so the interface can't be exercised at all.
///
/// When this is true the app substitutes stub behaviour — a pretend selection,
/// granted authorization, and wall-clock-only break timing — purely so the UI
/// can be driven end to end. The flag is a compile-time constant, so every
/// branch guarded by it is stripped from device builds and none of this code
/// can ever ship as behaviour on a real phone.
enum PreviewEnvironment {
    #if targetEnvironment(simulator)
    static let isSimulator = true
    #else
    static let isSimulator = false
    #endif

    /// Stand-in for "you picked some apps", since the real picker is empty here.
    static let stubBlockedItemCount = 12
}
