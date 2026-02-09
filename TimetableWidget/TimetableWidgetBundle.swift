import WidgetKit
import SwiftUI

@main
struct TimetableWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimetableWidget()
        TimetableWidgetLiveActivity()
    }
}
