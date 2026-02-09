import SwiftUI
import WidgetKit

@main
struct BusWidgetBundle: WidgetBundle {
    var body: some Widget {
        BusWidget()
        BusWidgetLiveActivity()
    }
}
