//
//  AppIntent.swift
//  TimetableWidget
//
//  Created by 维安雨轩 on 2025/03/25.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "時間割表示設定" }
    static var description: IntentDescription { "時間割ウィジェットの設定" }
}
