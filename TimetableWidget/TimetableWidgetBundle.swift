//
//  TimetableWidgetBundle.swift
//  TimetableWidget
//
//  Created by 维安雨轩 on 2025/03/25.
//

import WidgetKit
import SwiftUI

@main
struct TimetableWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimetableWidget()
        TimetableWidgetLiveActivity()
    }
}
