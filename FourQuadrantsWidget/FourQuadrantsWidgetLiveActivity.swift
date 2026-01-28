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
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct FourQuadrantsWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FourQuadrantsWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
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
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension FourQuadrantsWidgetAttributes {
    fileprivate static var preview: FourQuadrantsWidgetAttributes {
        FourQuadrantsWidgetAttributes(name: "World")
    }
}

extension FourQuadrantsWidgetAttributes.ContentState {
    fileprivate static var smiley: FourQuadrantsWidgetAttributes.ContentState {
        FourQuadrantsWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: FourQuadrantsWidgetAttributes.ContentState {
         FourQuadrantsWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: FourQuadrantsWidgetAttributes.preview) {
   FourQuadrantsWidgetLiveActivity()
} contentStates: {
    FourQuadrantsWidgetAttributes.ContentState.smiley
    FourQuadrantsWidgetAttributes.ContentState.starEyes
}
