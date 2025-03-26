//
//  TimetableWidgetLiveActivity.swift
//  TimetableWidget
//
//  Created by 维安雨轩 on 2025/03/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TimetableWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var name: String
    }

    var name: String
}

struct TimetableWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimetableWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("時間割 \(context.state.name)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here
                DynamicIslandExpandedRegion(.leading) {
                    Text("時間割")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.name)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("現在の授業を表示")
                }
            } compactLeading: {
                Text("授業")
            } compactTrailing: {
                Text(context.state.name)
            } minimal: {
                Text("授")
            }
            .widgetURL(URL(string: "tamaapp://timetable"))
            .keylineTint(Color.blue)
        }
    }
}

// プレビュー用の拡張
extension TimetableWidgetAttributes {
    fileprivate static var preview: TimetableWidgetAttributes {
        TimetableWidgetAttributes(name: "授業名")
    }
}

extension TimetableWidgetAttributes.ContentState {
    fileprivate static var sample: TimetableWidgetAttributes.ContentState {
        TimetableWidgetAttributes.ContentState(name: "サンプル授業")
    }
}

#Preview("LiveActivity", as: .content, using: TimetableWidgetAttributes.preview) {
   TimetableWidgetLiveActivity()
} contentStates: {
    TimetableWidgetAttributes.ContentState.sample
}
