import SwiftUI

/// Reads back `BreakLog`, which is the only way to see what the three extensions
/// did — they run out-of-process, briefly, whenever the system feels like it, and
/// cannot be attached to a debugger.
///
/// Times are `HH:mm:ss` because the question being asked here is always "did this
/// happen when it was supposed to".
struct DiagnosticsView: View {
    @State private var entries: [BreakLog.Entry] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenTitle("Diagnostics")

                if entries.isEmpty {
                    Text("Nothing logged yet. Start a break and come back.")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.muted)
                } else {
                    // Not a `RuledList`: the rules here go above each group of
                    // entries rather than under every one.
                    VStack(spacing: 0) {
                        let shown = Array(entries.reversed())
                        ForEach(Array(shown.enumerated()), id: \.element.id) { index, entry in
                            row(entry, showsTime: index == 0 || BreakEngine.clock(shown[index - 1].at) != BreakEngine.clock(entry.at))
                        }
                    }
                }

                Button("Clear log") {
                    BreakLog.clear()
                    entries = []
                }
                .buttonStyle(PillButtonStyle(kind: .secondary))
                .padding(.top, 24)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Theme.background.ignoresSafeArea())
        .pushedScreen("Diagnostics")
        .onAppear { entries = BreakLog.load() }
    }

    /// Entries that share a second are grouped under one time, and the rule
    /// between them dropped, so a burst of work the monitor did in one wake-up
    /// reads as one event rather than five.
    private func row(_ entry: BreakLog.Entry, showsTime: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(BreakEngine.clock(entry.at))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(showsTime ? Theme.foreground : .clear)
                .frame(width: 64, alignment: .leading)
                .accessibilityHidden(!showsTime)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.source)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.faint)
                Text(entry.message)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            if showsTime { Rule() }
        }
    }
}
