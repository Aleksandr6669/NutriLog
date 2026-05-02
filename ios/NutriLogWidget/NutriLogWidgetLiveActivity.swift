//
//  NutriLogWidgetLiveActivity.swift
//  NutriLogWidget
//
//  Created by Александр Рыженков on 02.05.2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct NutriLogWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct NutriLogWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NutriLogWidgetAttributes.self) { context in
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

extension NutriLogWidgetAttributes {
    fileprivate static var preview: NutriLogWidgetAttributes {
        NutriLogWidgetAttributes(name: "World")
    }
}

extension NutriLogWidgetAttributes.ContentState {
    fileprivate static var smiley: NutriLogWidgetAttributes.ContentState {
        NutriLogWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: NutriLogWidgetAttributes.ContentState {
         NutriLogWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: NutriLogWidgetAttributes.preview) {
   NutriLogWidgetLiveActivity()
} contentStates: {
    NutriLogWidgetAttributes.ContentState.smiley
    NutriLogWidgetAttributes.ContentState.starEyes
}
