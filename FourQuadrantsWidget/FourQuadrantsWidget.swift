import AppIntents
import SwiftUI
import WidgetKit

enum FourQuadrantsWidgetMode: String, AppEnum {
    case todayFocus
    case quadrantOverview

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Widget style"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .todayFocus: "Today focus",
        .quadrantOverview: "Quadrant overview"
    ]
}

struct FourQuadrantsWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Four Quadrants widget"
    static var description = IntentDescription("Choose the information shown by the widget.")

    @Parameter(title: "Style", default: .todayFocus)
    var mode: FourQuadrantsWidgetMode
}

struct FourQuadrantsWidgetEntry: TimelineEntry {
    let date: Date
    let mode: FourQuadrantsWidgetMode
    let snapshot: WidgetSnapshot
}

struct FourQuadrantsWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> FourQuadrantsWidgetEntry {
        FourQuadrantsWidgetEntry(date: .now, mode: .todayFocus, snapshot: .sample)
    }

    func snapshot(for configuration: FourQuadrantsWidgetConfiguration, in context: Context) async -> FourQuadrantsWidgetEntry {
        FourQuadrantsWidgetEntry(date: .now, mode: configuration.mode, snapshot: WidgetSnapshotStore.read())
    }

    func timeline(for configuration: FourQuadrantsWidgetConfiguration, in context: Context) async -> Timeline<FourQuadrantsWidgetEntry> {
        let entry = FourQuadrantsWidgetEntry(date: .now, mode: configuration.mode, snapshot: WidgetSnapshotStore.read())
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(15 * 60)))
    }
}

struct FourQuadrantsWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FourQuadrantsWidgetEntry

    var body: some View {
        Group {
            switch entry.mode {
            case .todayFocus:
                TodayFocusWidget(snapshot: entry.snapshot, compact: family == .systemSmall)
            case .quadrantOverview:
                QuadrantOverviewWidget(snapshot: entry.snapshot)
            }
        }
        .containerBackground(for: .widget) { Color.black }
        .widgetURL(URL(string: "fourquadrants://today"))
    }
}

struct TodayFocusWidget: View {
    let snapshot: WidgetSnapshot
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            Label("Today", systemImage: "calendar")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if let task = snapshot.focusTask {
                Text(task.title)
                    .font(compact ? .headline : .title3.weight(.semibold))
                    .lineLimit(compact ? 3 : 2)
                HStack(spacing: 5) {
                    Circle().fill(task.color).frame(width: 7, height: 7)
                    Text(task.dueLabel).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                Text("\(snapshot.openCount) open").font(.caption2).foregroundStyle(.secondary)
            } else {
                Spacer(minLength: 0)
                Label("No open tasks", systemImage: "checkmark.circle")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct QuadrantOverviewWidget: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("Four Quadrants", systemImage: "square.grid.2x2.fill")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(snapshot.quadrants) { quadrant in
                    VStack(alignment: .leading, spacing: 3) {
                        Circle().fill(quadrant.color).frame(width: 8, height: 8)
                        Text("\(quadrant.count)").font(.title3.weight(.bold))
                        Text(quadrant.title).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Spacer(minLength: 0)
            Text("Tap to open").font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct FourQuadrantsWidget: Widget {
    let kind = "FourQuadrantsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: FourQuadrantsWidgetConfiguration.self, provider: FourQuadrantsWidgetProvider()) { entry in
            FourQuadrantsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Four Quadrants")
        .description("See your next focus task or the four-quadrant count.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    FourQuadrantsWidget()
} timeline: {
    FourQuadrantsWidgetEntry(date: .now, mode: .todayFocus, snapshot: .sample)
}

#Preview(as: .systemMedium) {
    FourQuadrantsWidget()
} timeline: {
    FourQuadrantsWidgetEntry(date: .now, mode: .quadrantOverview, snapshot: .sample)
}
