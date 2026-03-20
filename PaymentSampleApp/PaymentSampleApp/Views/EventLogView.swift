import SwiftUI

struct EventLogView: View {
    @Environment(SDKState.self) private var sdkState

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }

    var body: some View {
        Group {
            if sdkState.eventLog.isEmpty {
                ContentUnavailableView(
                    "No Events Yet",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Events will appear here as you interact with placements.")
                )
            } else {
                List(sdkState.eventLog) { entry in
                    HStack(alignment: .top) {
                        Text(timeFormatter.string(from: entry.timestamp))
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .leading)

                        Text(entry.message)
                            .font(.caption)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Event Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear") {
                    sdkState.eventLog.removeAll()
                }
                .disabled(sdkState.eventLog.isEmpty)
            }
        }
    }
}
