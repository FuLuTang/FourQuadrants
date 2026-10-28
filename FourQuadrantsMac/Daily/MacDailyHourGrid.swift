import SwiftUI

struct MacDailyHourGrid: View {
    /// Receives the y offset of a click on empty grid, in grid coordinates.
    let onEmptyClick: (CGFloat) -> Void

    private typealias Metrics = MacDailyTimelineMetrics

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack(alignment: .top, spacing: 0) {
                    Text(String(format: "%02d:00", hour))
                        .font(.system(.caption, design: .rounded).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: Metrics.timeColumnWidth - Metrics.timeLabelGap, alignment: .trailing)
                        .padding(.trailing, Metrics.timeLabelGap)
                        .offset(y: Metrics.timeLabelOffset)

                    Rectangle()
                        .fill(Color.primary.opacity(0.11))
                        .frame(height: 1)
                }
                .frame(height: Metrics.hourHeight, alignment: .top)
                .id(Metrics.hourID(hour))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Metrics.timelineHeight, alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture { point in onEmptyClick(point.y) }
        .accessibilityHint("单击空白时间段可按 15 分钟间隔新建日程")
    }
}
