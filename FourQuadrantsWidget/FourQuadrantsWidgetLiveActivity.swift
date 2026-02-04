//
//  FourQuadrantsWidgetLiveActivity.swift
//  FourQuadrantsWidget
//
//  Created by 唐颢宸 on 28/01/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct FourQuadrantsWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var taskId: String        // DailyTask.id.uuidString
        var taskName: String      // 包含 "+N" 重叠标识
        var startTime: Date
        var endTime: Date
    }
    
    // 静态属性（留空，所有数据走 ContentState）
}

struct FourQuadrantsWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FourQuadrantsWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text(context.state.taskName)
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.taskName)
                }
            } compactLeading: {
                Image(systemName: "checklist")
            } compactTrailing: {
                Text(context.state.taskName)
                    .lineLimit(1)
            } minimal: {
                Image(systemName: "checklist")
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension FourQuadrantsWidgetAttributes {
    fileprivate static var preview: FourQuadrantsWidgetAttributes {
        FourQuadrantsWidgetAttributes()
    }
}

extension FourQuadrantsWidgetAttributes.ContentState {
    fileprivate static var sample: FourQuadrantsWidgetAttributes.ContentState {
        FourQuadrantsWidgetAttributes.ContentState(
            taskId: UUID().uuidString,
            taskName: "写代码",
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600)
        )
    }
}

#Preview("Notification", as: .content, using: FourQuadrantsWidgetAttributes.preview) {
    FourQuadrantsWidgetLiveActivity()
} contentStates: {
    FourQuadrantsWidgetAttributes.ContentState.sample
}
