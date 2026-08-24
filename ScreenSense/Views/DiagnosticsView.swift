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
            VStack(spacing: 13) {
                if entries.isEmpty {
                    Card {
                        Text("Nothing logged yet. Start a break and come back.")
                            .font(.system(size: 12.5))
                            .foregroundColor(Theme.muted)
                    }
                } else {
                    Card {
                        ForEach(Array(entries.reversed())) { entry in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 8) {
                                    Text(BreakEngine.clock(entry.at))
                                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                                    Text(entry.source)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Theme.accentSoft)
                                }
                                Text(entry.message)
                                    .font(.system(size: 11.5))
                                    .foregroundColor(Theme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if entry.id != entries.first?.id {
                                Divider().overlay(Theme.hairline)
                            }
                        }
                    }
                }

                Button {
                    BreakLog.clear()
                    entries = []
                } label: {
                    Text("Clear log")
                        .font(.system(size: 13, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            Color.white.opacity(0.07),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .foregroundColor(Theme.muted)
                }
            }
            .padding(.horizontal, 17)
            .padding(.bottom, 17)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { entries = BreakLog.load() }
    }
}
