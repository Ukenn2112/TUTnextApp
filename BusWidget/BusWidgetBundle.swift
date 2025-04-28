//
//  BusWidgetBundle.swift
//  BusWidget
//
//  Created by 维安雨轩 on 2025/03/22.
//

import SwiftUI
import WidgetKit

@main
struct BusWidgetBundle: WidgetBundle {
    var body: some Widget {
        BusWidget()
        BusWidgetLiveActivity()
    }
}
