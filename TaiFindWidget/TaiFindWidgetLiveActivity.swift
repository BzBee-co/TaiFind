//
//  TaiFindWidgetLiveActivity.swift
//  TaiFindWidget
//
//  Created by Antoine Moreau on 2026/8/10.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TaiFindWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct TaiFindWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TaiFindWidgetAttributes.self) { context in
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

extension TaiFindWidgetAttributes {
    fileprivate static var preview: TaiFindWidgetAttributes {
        TaiFindWidgetAttributes(name: "World")
    }
}

extension TaiFindWidgetAttributes.ContentState {
    fileprivate static var smiley: TaiFindWidgetAttributes.ContentState {
        TaiFindWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: TaiFindWidgetAttributes.ContentState {
         TaiFindWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: TaiFindWidgetAttributes.preview) {
   TaiFindWidgetLiveActivity()
} contentStates: {
    TaiFindWidgetAttributes.ContentState.smiley
    TaiFindWidgetAttributes.ContentState.starEyes
}
