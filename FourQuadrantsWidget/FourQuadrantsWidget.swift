import AppIntents
import SwiftUI
import WidgetKit

enum FourQuadrantsWidgetMode: String, AppEnum {
    case quadrantTasks
    case todayFocus
    case smartRecommendations
    // Kept so widgets configured by the previous build continue to decode.
    case quadrantOverview

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "widget_parameter_content"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .quadrantTasks: "widget_mode_quadrant_tasks",
        .todayFocus: "widget_today_focus",
        .smartRecommendations: "widget_smart_recommendations",
        .quadrantOverview: "widget_mode_quadrant_tasks"
    ]

    // AppEnum uses CaseIterable to populate the configuration picker. Keep the
    // legacy raw value decodable while excluding it from newly-created choices.
    static var allCases: [Self] { [.quadrantTasks, .todayFocus, .smartRecommendations] }
}

enum FourQuadrantsWidgetQuadrant: String, AppEnum {
    case importantAndUrgent = "important_urgent"
    case importantButNotUrgent = "important_not_urgent"
    case urgentButNotImportant = "urgent_not_important"
    case notImportantAndNotUrgent = "not_important_not_urgent"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "widget_parameter_quadrant"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .importantAndUrgent: "widget_quadrant_important_urgent",
        .importantButNotUrgent: "widget_quadrant_important_not_urgent",
        .urgentButNotImportant: "widget_quadrant_urgent_not_important",
        .notImportantAndNotUrgent: "widget_quadrant_not_important_not_urgent"
    ]
}

struct FourQuadrantsWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "widget_configuration_title"
    static var description = IntentDescription("widget_configuration_description")

    @Parameter(title: "widget_parameter_content", default: .quadrantTasks)
    var mode: FourQuadrantsWidgetMode

    @Parameter(title: "widget_parameter_quadrant", default: .importantAndUrgent)
    var quadrant: FourQuadrantsWidgetQuadrant

    static var parameterSummary: some ParameterSummary {
        Switch(\.$mode) {
            Case(.quadrantTasks) {
                Summary("\(\.$mode), \(\.$quadrant)")
            }
            Case(.quadrantOverview) {
                Summary("\(\.$mode), \(\.$quadrant)")
            }
            DefaultCase() {
                Summary("\(\.$mode)")
            }
        }
    }
}

struct FourQuadrantsWidgetEntry: TimelineEntry {
    let date: Date
    let mode: FourQuadrantsWidgetMode
    let quadrant: FourQuadrantsWidgetQuadrant
    let snapshot: WidgetSnapshot
}

struct FourQuadrantsWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> FourQuadrantsWidgetEntry {
        FourQuadrantsWidgetEntry(date: .now, mode: .quadrantTasks, quadrant: .importantAndUrgent, snapshot: .sample)
    }

    func snapshot(for configuration: FourQuadrantsWidgetConfiguration, in context: Context) async -> FourQuadrantsWidgetEntry {
        FourQuadrantsWidgetEntry(date: .now, mode: configuration.mode, quadrant: configuration.quadrant, snapshot: WidgetSnapshotStore.read())
    }

    func timeline(for configuration: FourQuadrantsWidgetConfiguration, in context: Context) async -> Timeline<FourQuadrantsWidgetEntry> {
        let now = Date.now
        let snapshot = WidgetSnapshotStore.read()
        var entries = [FourQuadrantsWidgetEntry(date: now, mode: configuration.mode, quadrant: configuration.quadrant, snapshot: snapshot)]
        if let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) {
            entries.append(FourQuadrantsWidgetEntry(date: nextDay, mode: configuration.mode, quadrant: configuration.quadrant, snapshot: snapshot))
        }
        return Timeline(entries: entries, policy: .after(now.addingTimeInterval(15 * 60)))
    }
}

enum FourQuadrantsWidgetDeepLink {
    static func task(id: String) -> URL { URL(string: "fourquadrants://task/\(id)")! }
    static func quadrant(key: String) -> URL { URL(string: "fourquadrants://quadrant/\(key)")! }
    static let today = URL(string: "fourquadrants://today")!
}

struct FourQuadrantsWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: FourQuadrantsWidgetEntry

    private var selectedQuadrant: WidgetSnapshot.Quadrant? {
        entry.snapshot.quadrants.first { $0.key == entry.quadrant.rawValue }
    }

    var body: some View {
        Group {
            switch entry.mode {
            case .todayFocus:
                TodayFocusWidget(snapshot: entry.snapshot, compact: family == .systemSmall)
            case .quadrantTasks, .quadrantOverview:
                QuadrantTasksWidget(quadrant: selectedQuadrant, compact: family == .systemSmall, accented: renderingMode == .accented, referenceDate: entry.date)
            case .smartRecommendations:
                RecommendedTasksWidget(
                    tasks: entry.snapshot.recommendedTasks,
                    totalCount: entry.snapshot.openCount,
                    compact: family == .systemSmall,
                    accented: renderingMode == .accented,
                    referenceDate: entry.date
                )
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(backgroundURL)
    }

    private var backgroundURL: URL {
        switch entry.mode {
        case .todayFocus, .smartRecommendations: return FourQuadrantsWidgetDeepLink.today
        case .quadrantTasks, .quadrantOverview:
            return FourQuadrantsWidgetDeepLink.quadrant(key: entry.quadrant.rawValue)
        }
    }
}

struct QuadrantTasksWidget: View {
    let quadrant: WidgetSnapshot.Quadrant?
    let compact: Bool
    let accented: Bool
    let referenceDate: Date

    private var visibleTasks: [WidgetSnapshot.Task] {
        Array((quadrant?.tasks ?? []).prefix(compact ? 3 : 4))
    }

    var body: some View {
        Group {
            if compact {
                QuadrantTasksSmallLayout(quadrant: quadrant, tasks: visibleTasks, accented: accented)
            } else {
                QuadrantTasksMediumLayout(quadrant: quadrant, tasks: visibleTasks, accented: accented, referenceDate: referenceDate)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct QuadrantTasksSmallLayout: View {
    let quadrant: WidgetSnapshot.Quadrant?
    let tasks: [WidgetSnapshot.Task]
    let accented: Bool

    private var shortTitle: LocalizedStringResource {
        switch quadrant?.key {
        case "important_urgent": "widget_short_important_urgent"
        case "important_not_urgent": "widget_short_important_not_urgent"
        case "urgent_not_important": "widget_short_urgent_not_important"
        case "not_important_not_urgent": "widget_short_other"
        default: "widget_mode_quadrant_tasks"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Circle()
                    .fill(accented ? Color.primary : (quadrant?.color ?? Color.secondary))
                    .frame(width: 8, height: 8)
                    .widgetAccentable()
                Text(shortTitle)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .widgetAccentable()
                    .accessibilityLabel(Text(quadrant?.title ?? "Quadrant"))
                Spacer(minLength: 0)
                Text("\(quadrant?.count ?? 0)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            if tasks.isEmpty {
                Spacer(minLength: 0)
                Label("widget_no_open_tasks", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(tasks) { task in
                        CompactWidgetTaskRow(task: task, accented: accented)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
}

private struct QuadrantTasksMediumLayout: View {
    let quadrant: WidgetSnapshot.Quadrant?
    let tasks: [WidgetSnapshot.Task]
    let accented: Bool
    let referenceDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Circle()
                    .fill(accented ? Color.primary : (quadrant?.color ?? Color.secondary))
                    .frame(width: 7, height: 7)
                    .widgetAccentable()
                Text(quadrant?.title ?? "Quadrant")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .widgetAccentable()
                Spacer(minLength: 0)
                Text("\(quadrant?.count ?? 0)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 0) {
                if tasks.isEmpty {
                    Label("widget_no_open_tasks", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tasks) { task in
                        MediumWidgetTaskRow(task: task, accented: accented, referenceDate: referenceDate)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct WidgetTaskRow: View {
    let task: WidgetSnapshot.Task
    let compact: Bool
    let accented: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Button(intent: CompleteWidgetTaskIntent(taskID: task.id)) {
                Image(systemName: "circle")
                    .font(.system(size: compact ? 11 : 13, weight: .medium))
                    .foregroundStyle(accented ? Color.primary : Color.gray.opacity(0.7))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("widget_complete_task"))
            .accessibilityValue(Text(task.title))

            Link(destination: FourQuadrantsWidgetDeepLink.task(id: task.id)) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(task.title)
                        .font(compact ? .caption : .subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(task.dueLabel)
                        .font(.caption2)
                        .foregroundStyle(task.isOverdue && !accented ? .red : .secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
    }
}

struct RecommendedTasksWidget: View {
    let tasks: [WidgetSnapshot.Task]
    let totalCount: Int
    let compact: Bool
    let accented: Bool
    let referenceDate: Date

    var body: some View {
        Group {
            if compact {
                RecommendedTasksSmall(tasks: Array(tasks.prefix(3)), totalCount: totalCount, accented: accented)
            } else {
                RecommendedTasksMedium(tasks: Array(tasks.prefix(4)), totalCount: totalCount, accented: accented, referenceDate: referenceDate)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct RecommendedTasksSmall: View {
    let tasks: [WidgetSnapshot.Task]
    let totalCount: Int
    let accented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.caption2.weight(.semibold))
                    .widgetAccentable()
                Text("widget_smart_recommendations")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .widgetAccentable()
                Spacer(minLength: 0)
                Text("\(totalCount)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            if tasks.isEmpty {
                Label("widget_no_open_tasks", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(tasks) { task in
                        CompactWidgetTaskRow(task: task, accented: accented)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
}

private struct RecommendedTasksMedium: View {
    let tasks: [WidgetSnapshot.Task]
    let totalCount: Int
    let accented: Bool
    let referenceDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Label("widget_smart_recommendations", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .widgetAccentable()
                Spacer(minLength: 0)
                Text("\(totalCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 0) {
                if tasks.isEmpty {
                    Label("widget_no_open_tasks", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tasks) { task in
                        MediumWidgetTaskRow(task: task, accented: accented, referenceDate: referenceDate)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct CompactWidgetTaskRow: View {
    let task: WidgetSnapshot.Task
    let accented: Bool

    private var categoryColor: Color { Color(hex: task.colorHex) }

    var body: some View {
        HStack(spacing: 5) {
            Button(intent: CompleteWidgetTaskIntent(taskID: task.id)) {
                Image(systemName: "circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(accented ? Color.primary : Color.gray.opacity(0.7))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("widget_complete_task"))
            .accessibilityValue(Text(task.title))

            Link(destination: FourQuadrantsWidgetDeepLink.task(id: task.id)) {
                HStack(spacing: 7) {
                    Text(task.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(accented ? Color.primary.opacity(0.08) : categoryColor.opacity(0.10))
                        }

                    if task.hasDueDate == true {
                        Image(systemName: task.isOverdue ? "bell.fill" : "clock")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accented ? Color.primary : (task.isOverdue ? .red : .blue))
                            .widgetAccentable()
                            .frame(width: 16)
                            .accessibilityLabel(Text(task.dueLabel))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MediumWidgetTaskRow: View {
    let task: WidgetSnapshot.Task
    let accented: Bool
    let referenceDate: Date

    private var categoryColor: Color { Color(hex: task.colorHex) }

    var body: some View {
        HStack(spacing: 6) {
            Button(intent: CompleteWidgetTaskIntent(taskID: task.id)) {
                Image(systemName: "circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(accented ? Color.primary : Color.gray.opacity(0.7))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("widget_complete_task"))
            .accessibilityValue(Text(task.title))

            Link(destination: FourQuadrantsWidgetDeepLink.task(id: task.id)) {
                HStack(spacing: 8) {
                    Text(task.title)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(accented ? Color.primary.opacity(0.08) : categoryColor.opacity(0.10))
                        }
                    if let dueDate = task.dueDate {
                        WidgetRelativeDueBadge(dueDate: dueDate, referenceDate: referenceDate, accented: accented, dueLabel: task.dueLabel)
                    } else if task.hasDueDate == true {
                        Image(systemName: task.isOverdue ? "bell.fill" : "clock")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accented ? Color.primary : (task.isOverdue ? .red : .blue))
                            .widgetAccentable()
                            .frame(width: 18)
                            .accessibilityLabel(Text(task.dueLabel))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WidgetRelativeDueBadge: View {
    @Environment(\.calendar) private var calendar

    let dueDate: Date
    let referenceDate: Date
    let accented: Bool
    let dueLabel: String

    private var dayOffset: Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: referenceDate),
            to: calendar.startOfDay(for: dueDate)
        ).day ?? 0
    }

    private var label: String {
        switch dayOffset {
        case 0:
            String(localized: "widget_due_today")
        case 1:
            String(localized: "widget_due_in_one_day")
        case let days where days > 1:
            String.localizedStringWithFormat(String(localized: "widget_due_in_days"), days)
        case -1:
            String(localized: "widget_due_one_day_late")
        default:
            String.localizedStringWithFormat(String(localized: "widget_due_days_late"), -dayOffset)
        }
    }

    var body: some View {
        let tint: Color = accented ? .primary : (dayOffset < 0 ? .red : .blue)

        HStack(spacing: 4) {
            Image(systemName: dayOffset < 0 ? "bell.fill" : "calendar")
                .font(.caption2.weight(.semibold))
            Text(label)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .widgetAccentable()
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(tint.opacity(accented ? 0.12 : 0.14), in: Capsule())
        .accessibilityLabel(Text("\(label), \(dueLabel)"))
    }
}

struct TodayFocusWidget: View {
    let snapshot: WidgetSnapshot
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("widget_today_focus", systemImage: "calendar")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .widgetAccentable()
            if let task = snapshot.focusTask {
                WidgetTaskRow(task: task, compact: compact, accented: false)
                Spacer(minLength: 0)
                Text(String.localizedStringWithFormat(String(localized: "widget_open_count"), snapshot.openCount))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Spacer(minLength: 0)
                Label("widget_no_open_tasks", systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
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
        .configurationDisplayName("widget_display_name")
        .description("widget_description")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    FourQuadrantsWidget()
} timeline: {
    FourQuadrantsWidgetEntry(date: .now, mode: .quadrantTasks, quadrant: .importantAndUrgent, snapshot: .sample)
}

#Preview(as: .systemMedium) {
    FourQuadrantsWidget()
} timeline: {
    FourQuadrantsWidgetEntry(date: .now, mode: .quadrantTasks, quadrant: .importantAndUrgent, snapshot: .sample)
}

#Preview("Recommended small", as: .systemSmall) {
    FourQuadrantsWidget()
} timeline: {
    FourQuadrantsWidgetEntry(date: .now, mode: .smartRecommendations, quadrant: .importantAndUrgent, snapshot: .sample)
}

#Preview("Recommended medium", as: .systemMedium) {
    FourQuadrantsWidget()
} timeline: {
    FourQuadrantsWidgetEntry(date: .now, mode: .smartRecommendations, quadrant: .importantAndUrgent, snapshot: .sample)
}
