import SwiftUI

struct MacDailyCurrentTimeLine: View {
    let date: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            if Calendar.current.isDate(context.date, inSameDayAs: date) {
                let minute = CGFloat(MacDailyTimeMath.minuteOfDay(context.date))
                HStack(spacing: 8) {
                    Text(context.date.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.red)
                        .frame(width: MacDailyTimelineMetrics.timeColumnWidth - 10, alignment: .trailing)
                    Rectangle().fill(.red.opacity(0.78)).frame(height: 1.5)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(y: minute / 60 * MacDailyTimelineMetrics.hourHeight)
            }
        }
    }
}
