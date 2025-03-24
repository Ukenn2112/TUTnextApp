//
//  BusWidgetLiveActivity.swift
//  BusWidget
//
//  Created by 维安雨轩 on 2025/03/22.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct BusWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // バスの状態（到着までの残り時間など）
        var remainingTime: Int
        var busTime: String
        var routeName: String
        var scheduleType: String
    }

    // LiveActivityで表示する固定データ
    var routeType: String
}

struct BusWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BusWidgetAttributes.self) { context in
            // ロック画面/通知センターでのLive Activity表示
            ZStack {
                // 背景グラデーション - ダークモード対応
                GeometryReader { geo in
                    // ColorSchemeを@Environmentから取得
                    ColorSchemeAwareBackground()
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    // ヘッダー部分
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "bus.fill")
                                .font(.title3)
                                .foregroundColor(Color.accentColor)
                            
                            Text(context.attributes.routeType)
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        Text(context.state.busTime)
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(Color.accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.accentColor.opacity(0.1))
                            )
                    }
                    
                    Divider()
                        .background(Color.accentColor.opacity(0.2))
                    
                    // 詳細情報
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            // 目的地
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(context.state.routeName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            // ダイヤタイプ
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(context.state.scheduleType)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // 残り時間の表示
                        VStack(alignment: .trailing, spacing: 2) {
                            // 時間表示
                            RemainingTimeView(remainingTime: context.state.remainingTime)
                            
                            // 到着予測
                            if context.state.remainingTime <= 5 {
                                Text("まもなく到着します")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Text("順調に運行中")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
            }
            .activityBackgroundTint(Color.clear)
            .activitySystemActionForegroundColor(.primary)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "bus.fill")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.attributes.routeType)
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Text(context.state.scheduleType)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text(context.state.busTime)
                            .font(.callout)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                }
                
                DynamicIslandExpandedRegion(.center) {
                    // バスの残り時間
                    CompactRemainingTimeView(remainingTime: context.state.remainingTime)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(context.state.routeName)
                            .font(.caption)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if context.state.remainingTime <= 5 {
                            Text("まもなく到着")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .stroke(Color.green, lineWidth: 1)
                                )
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "bus.fill")
                    .foregroundColor(.blue)
            } compactTrailing: {
                CompactRemainingTimeText(remainingTime: context.state.remainingTime)
            } minimal: {
                Image(systemName: getBusIconForMinimal(remainingTime: context.state.remainingTime))
                    .foregroundColor(getMinimalIconColor(remainingTime: context.state.remainingTime))
            }
            .widgetURL(URL(string: "tama://bus"))
            .keylineTint(getKeylineTintColor(remainingTime: context.state.remainingTime))
        }
    }
    
    // Dynamic Island用のアイコン選択
    private func getBusIconForMinimal(remainingTime: Int) -> String {
        if remainingTime <= 5 {
            return "bus.doubledecker.fill"
        } else {
            return "bus.fill"
        }
    }
    
    // Dynamic Island用の色選択
    private func getMinimalIconColor(remainingTime: Int) -> Color {
        if remainingTime <= 5 {
            return .green
        } else if remainingTime <= 10 {
            return .orange
        } else {
            return .blue
        }
    }
    
    // キーラインの色
    private func getKeylineTintColor(remainingTime: Int) -> Color {
        if remainingTime <= 5 {
            return .green
        } else if remainingTime <= 10 {
            return .orange
        } else {
            return .blue
        }
    }
}

// ColorSchemeを環境変数から取得するビュー
struct ColorSchemeAwareBackground: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        // ライト/ダークモードに応じた背景色
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ? [
                Color(uiColor: UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)),
                Color(uiColor: UIColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 1.0))
            ] : [
                Color(uiColor: UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)),
                Color(uiColor: UIColor(red: 0.98, green: 0.98, blue: 1.0, alpha: 1.0))
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// 残り時間表示のサブビュー
struct RemainingTimeView: View {
    let remainingTime: Int
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if remainingTime <= 0 {
                HStack(spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("まもなく")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.green.opacity(colorScheme == .dark ? 0.2 : 0.1))
                )
            } else if remainingTime < 60 {
                HStack(spacing: 2) {
                    Text("\(remainingTime)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(remainingTime <= 5 ? .orange : .accentColor)
                    
                    Text("分後")
                        .font(.subheadline)
                        .foregroundColor(remainingTime <= 5 ? .orange : .accentColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(getTimeBackgroundColor(remainingTime: remainingTime))
                )
            } else {
                let hours = remainingTime / 60
                let minutes = remainingTime % 60
                
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(hours)時間\(minutes)分後")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.accentColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.1))
                )
            }
        }
    }
    
    private func getTimeBackgroundColor(remainingTime: Int) -> Color {
        if remainingTime <= 5 {
            return Color.orange.opacity(colorScheme == .dark ? 0.2 : 0.1)
        } else {
            return Color.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.1)
        }
    }
}

// Compact表示用の残り時間ビュー
struct CompactRemainingTimeView: View {
    let remainingTime: Int
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "timer")
                .font(.caption)
                .foregroundColor(getTimeColor(remainingTime: remainingTime))
            
            if remainingTime <= 0 {
                Text("まもなく到着")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            } else if remainingTime < 60 {
                Text("\(remainingTime)分後")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(getTimeColor(remainingTime: remainingTime))
            } else {
                let hours = remainingTime / 60
                let minutes = remainingTime % 60
                Text("\(hours)時間\(minutes)分後")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
            }
        }
    }
    
    private func getTimeColor(remainingTime: Int) -> Color {
        if remainingTime <= 0 {
            return .green
        } else if remainingTime <= 5 {
            return colorScheme == .dark ? .yellow : .orange
        } else {
            return .accentColor
        }
    }
}

// コンパクト表示用の残り時間テキスト
struct CompactRemainingTimeText: View {
    let remainingTime: Int
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        if remainingTime <= 5 {
            Text("まもなく")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.green)
        } else {
            Text("\(remainingTime)分")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(remainingTime <= 10 ? (colorScheme == .dark ? .yellow : .orange) : .accentColor)
        }
    }
}

extension BusWidgetAttributes {
    fileprivate static var preview: BusWidgetAttributes {
        BusWidgetAttributes(
            routeType: "聖蹟桜ヶ丘駅発"
        )
    }
}

extension BusWidgetAttributes.ContentState {
    fileprivate static var waiting: BusWidgetAttributes.ContentState {
        BusWidgetAttributes.ContentState(
            remainingTime: 12,
            busTime: "10:30",
            routeName: "多摩大学行",
            scheduleType: "平日"
        )
    }
    
    fileprivate static var arriving: BusWidgetAttributes.ContentState {
        BusWidgetAttributes.ContentState(
            remainingTime: 0,
            busTime: "10:30",
            routeName: "多摩大学行",
            scheduleType: "平日"
        )
    }
}

#Preview("Live Activity", as: .content, using: BusWidgetAttributes.preview) {
    BusWidgetLiveActivity()
} contentStates: {
    BusWidgetAttributes.ContentState.waiting
    BusWidgetAttributes.ContentState.arriving
}

#Preview("Notification", as: .content, using: BusWidgetAttributes.preview) {
    BusWidgetLiveActivity()
} contentStates: {
    BusWidgetAttributes.ContentState.waiting
    BusWidgetAttributes.ContentState.arriving
}
