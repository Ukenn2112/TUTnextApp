import SwiftUI
import WidgetKit

@main
struct TimetableWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimetableWidget()
        ClassLiveActivityWidget()
    }
}
