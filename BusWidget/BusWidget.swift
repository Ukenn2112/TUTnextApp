//
//  BusWidget.swift
//  BusWidget
//
//  Refactored for iOS 17+ with Glassmorphism Design System
//

import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Configuration Intent

struct BusConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "バス時刻表設定" }
    static var description: IntentDescription { "学校バスの時刻表を表示します。" }
    
    @Parameter(title: "路線", default: .fromSeisekiToSchool)
    var routeType: BusRouteSelection
}

enum BusRouteSelection: String, AppEnum {
    case fromSeisekiToSchool
    case fromNagayamaToSchool
    case fromSchoolToSeiseki
    case fromSchoolToNagayama
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        return TypeDisplayRepresentation(name: "路線タイプ")
    }
    
    static var caseDisplayRepresentations: [BusRouteSelection: DisplayRepresentation] = [
        .fromSeisekiToSchool: DisplayRepresentation(title: "聖蹟桜ヶ丘駅発 → 学校行"),
        .fromNagayamaToSchool: DisplayRepresentation(title: "永山駅発 → 学校行"),
        .fromSchoolToSeiseki: DisplayRepresentation(title: "学校発 → 聖蹟桜ヶ丘駅行"),
        .fromSchoolToNagayama: DisplayRepresentation(title: "学校発 → 永山駅行"),
    ]
    
    var busRouteType: BusRouteType {
        switch self {
        case .fromSeisekiToSchool: return .fromSeisekiToSchool
        case .fromNagayamaToSchool: return .fromNagayamaToSchool
        case .fromSchoolToSeiseki: return .fromSchoolToSeiseki
        case .fromSchoolToNagayama: return .fromSchoolToNagayama
        }
    }
}

// MARK: - Entry Model

struct BusEntry: TimelineEntry {
    let date: Date
    let configuration: BusConfigurationIntent
    let nextBusTimes: [BusTimeEntry]
    let scheduleType: String
    
    func getBusDeepLink() -> URL {
        var urlComponents = URLComponents()
        urlComponents.scheme = "tama"
        urlComponents.host = "bus"
        urlComponents.queryItems = [
            URLQueryItem(name: "route", value: configuration.routeType.rawValue),
            URLQueryItem(name: "schedule", value: scheduleType),
        ]
        return urlComponents.url ?? URL(string: "tama://bus")!
    }
    
    func getBusTimeAsDate(index: Int) -> Date? {
        guard index < nextBusTimes.count else { return nil }
        
        let busTime = nextBusTimes[index]
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = busTime.hour
        components.minute = busTime.minute
        components.second = 0
        
        guard let busDate = calendar.date(from: components) else { return nil }
        
        if busDate <= date {
            return calendar.date(byAdding: .day, value: 1, to: busDate)
        }
        
        return busDate
    }
    
    func getCurrentBusIndex() -> Int {
        if nextBusTimes.isEmpty {
            return 0
        }
        
        let now = date
        let calendar = Calendar.current
        
        for (index, busTime) in nextBusTimes.enumerated() {
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = busTime.hour
            components.minute = busTime.minute
            components.second = 0
            
            guard let busDate = calendar.date(from: components) else { continue }
            
            var actualBusDate = busDate
            if busDate < now {
                let hasLaterBusesToday = nextBusTimes.dropFirst(index + 1).contains { laterBus in
                    var laterComponents = calendar.dateComponents([.year, .month, .day], from: now)
                    laterComponents.hour = laterBus.hour
                    laterComponents.minute = laterBus.minute
                    laterComponents.second = 0
                    
                    guard let laterBusDate = calendar.date(from: laterComponents) else {
                        return false
                    }
                    return laterBusDate > now
                }
                
                if !hasLaterBusesToday {
                    actualBusDate = calendar.date(byAdding: .day, value: 1, to: busDate)!
                } else {
                    continue
                }
            }
            
            if actualBusDate > now {
                return index
            }
        }
        
        return 0
    }
    
    var currentBus: BusTimeEntry? {
        let index = getCurrentBusIndex()
        return index < nextBusTimes.count ? nextBusTimes[index] : nil
    }
    
    var currentBusDate: Date? {
        let index = getCurrentBusIndex()
        return getBusTimeAsDate(index: index)
    }
    
    var isServiceEndedForToday: Bool {
        guard currentBus != nil, let busDate = currentBusDate else {
            return true
        }
        
        let calendar = Calendar.current
        let busDay = calendar.component(.day, from: busDate)
        let todayDay = calendar.component(.day, from: date)
        
        if busDay != todayDay {
            let timeInterval = busDate.timeIntervalSince(date)
            return timeInterval >= 21600
        }
        
        return false
    }
    
    var upcomingBuses: [BusTimeEntry] {
        if isServiceEndedForToday {
            return []
        }
        
        let now = date
        let calendar = Calendar.current
        let currentIndex = getCurrentBusIndex()
        
        let upcomingIndices = currentIndex + 1..<min(currentIndex + 3, nextBusTimes.count)
        let todayBuses = upcomingIndices.compactMap { index -> BusTimeEntry? in
            let bus = nextBusTimes[index]
            
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = bus.hour
            components.minute = bus.minute
            
            guard let busDate = calendar.date(from: components) else { return nil }
            
            return calendar.isDate(busDate, inSameDayAs: now) ? bus : nil
        }
        
        return todayBuses
    }
}

// MARK: - Timeline Provider

struct BusProvider: AppIntentTimelineProvider {
    typealias Entry = BusEntry
    typealias Intent = BusConfigurationIntent
    
    func placeholder(in context: Context) -> BusEntry {
        BusEntry(
            date: Date(),
            configuration: BusConfigurationIntent(),
            nextBusTimes: sampleBusTimes,
            scheduleType: "weekday"
        )
    }
    
    func snapshot(for configuration: BusConfigurationIntent, in context: Context) async -> BusEntry {
        let currentDate = Date()
        let scheduleType = BusWidgetDataProvider.getScheduleTypeForDate(currentDate)
        
        if context.isPreview {
            return BusEntry(
                date: currentDate,
                configuration: configuration,
                nextBusTimes: sampleBusTimes,
                scheduleType: scheduleType
            )
        }
        
        let nextBusTimes = getNextBusTimes(
            routeType: configuration.routeType.busRouteType,
            from: currentDate
        )
        
        return BusEntry(
            date: currentDate,
            configuration: configuration,
            nextBusTimes: nextBusTimes,
            scheduleType: scheduleType
        )
    }
    
    func timeline(for configuration: BusConfigurationIntent, in context: Context) async -> Timeline<BusEntry> {
        let currentDate = Date()
        var entries: [BusEntry] = []
        
        let busTimes = getNextBusTimes(
            routeType: configuration.routeType.busRouteType,
            from: currentDate
        )
        
        var refreshDates = [currentDate]
        
        if !busTimes.isEmpty {
            let maxBusesToProcess = min(3, busTimes.count)
            
            for i in 0..<maxBusesToProcess {
                let bus = busTimes[i]
                if let busDate = calculateBusDate(from: currentDate, hour: bus.hour, minute: bus.minute) {
                    let timeToNextBus = busDate.timeIntervalSince(currentDate)
                    
                    if timeToNextBus > 0 {
                        if timeToNextBus <= 300 {
                            for second in stride(from: 0, to: min(300, timeToNextBus), by: 10) {
                                refreshDates.append(currentDate.addingTimeInterval(second))
                            }
                        } else if timeToNextBus <= 900 {
                            for second in stride(from: 0, to: min(900, timeToNextBus), by: 30) {
                                refreshDates.append(currentDate.addingTimeInterval(second))
                            }
                        } else if timeToNextBus <= 1800 {
                            for second in stride(from: 0, to: min(1800, timeToNextBus), by: 60) {
                                refreshDates.append(currentDate.addingTimeInterval(second))
                            }
                        }
                        
                        if timeToNextBus <= 1800 {
                            refreshDates.append(busDate.addingTimeInterval(-30))
                            refreshDates.append(busDate.addingTimeInterval(-5))
                        }
                        
                        refreshDates.append(busDate)
                        refreshDates.append(busDate.addingTimeInterval(1))
                        refreshDates.append(busDate.addingTimeInterval(5))
                    }
                }
            }
        } else {
            for minuteOffset in stride(from: 30, to: 180, by: 30) {
                refreshDates.append(Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!)
            }
        }
        
        let calendar = Calendar.current
        var midnight = calendar.startOfDay(for: currentDate)
        midnight = calendar.date(byAdding: .day, value: 1, to: midnight)!
        refreshDates.append(midnight)
        refreshDates.append(calendar.date(byAdding: .second, value: 10, to: midnight)!)
        
        refreshDates = Array(Set(refreshDates)).sorted()
        refreshDates = refreshDates.filter { $0 >= currentDate }
        
        for date in refreshDates {
            let scheduleType = BusWidgetDataProvider.getScheduleTypeForDate(date)
            let times = getNextBusTimes(
                routeType: configuration.routeType.busRouteType,
                from: date
            )
            entries.append(
                BusEntry(
                    date: date,
                    configuration: configuration,
                    nextBusTimes: times,
                    scheduleType: scheduleType
                )
            )
        }
        
        let reloadPolicy: TimelineReloadPolicy
        
        if let firstBus = busTimes.first,
           let firstBusDate = calculateBusDate(from: currentDate, hour: firstBus.hour, minute: firstBus.minute) {
            let timeToFirstBus = firstBusDate.timeIntervalSince(currentDate)
            
            if timeToFirstBus <= 0 {
                reloadPolicy = .after(currentDate.addingTimeInterval(1))
            } else if timeToFirstBus <= 60 {
                reloadPolicy = .after(currentDate.addingTimeInterval(10))
            } else if timeToFirstBus <= 300 {
                reloadPolicy = .after(currentDate.addingTimeInterval(30))
            } else if timeToFirstBus <= 900 {
                reloadPolicy = .after(currentDate.addingTimeInterval(60))
            } else if timeToFirstBus <= 1800 {
                reloadPolicy = .after(currentDate.addingTimeInterval(180))
            } else {
                reloadPolicy = .after(currentDate.addingTimeInterval(900))
            }
        } else {
            reloadPolicy = .after(currentDate.addingTimeInterval(1800))
        }
        
        return Timeline(entries: entries, policy: reloadPolicy)
    }
    
    private func getNextBusTimes(routeType: BusRouteType, from date: Date) -> [BusTimeEntry] {
        let scheduleType = BusWidgetDataProvider.getScheduleTypeForDate(date)
        return BusWidgetDataProvider.getNextBusTimes(
            routeType: routeType.rawValue,
            scheduleType: scheduleType,
            from: date
        )
    }
    
    private func calculateBusDate(from currentDate: Date, hour: Int, minute: Int) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: currentDate)
        components.hour = hour
        components.minute = minute
        components.second = 0
        
        guard var busDate = calendar.date(from: components) else { return nil }
        
        if busDate < currentDate {
            busDate = calendar.date(byAdding: .day, value: 1, to: busDate)!
        }
        
        return busDate
    }
    
    private var sampleBusTimes: [BusTimeEntry] {
        [
            BusTimeEntry(hour: 8, minute: 30),
            BusTimeEntry(hour: 9, minute: 0),
            BusTimeEntry(hour: 9, minute: 30),
            BusTimeEntry(hour: 10, minute: 0),
            BusTimeEntry(hour: 10, minute: 30),
        ]
    }
}

// MARK: - Widget View

struct BusWidgetEntryView: View {
    var entry: BusEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme
    
    var routeName: String {
        switch entry.configuration.routeType {
        case .fromSeisekiToSchool: return "聖蹟桜ヶ丘駅発"
        case .fromNagayamaToSchool: return "永山駅発"
        case .fromSchoolToSeiseki: return "聖蹟桜ヶ丘駅行"
        case .fromSchoolToNagayama: return "永山駅行"
        }
    }
    
    var scheduleTypeName: String {
        BusWidgetDataProvider.getScheduleTypeDisplayName(entry.scheduleType)
    }
    
    var themeColor: Color {
        colorScheme == .dark ? .cyan : .blue
    }
    
    var secondaryTextColor: Color {
        .secondary
    }
    
    var body: some View {
        Link(destination: entry.getBusDeepLink()) {
            if family == .systemSmall {
                smallWidgetLayout
            } else {
                mediumWidgetLayout
            }
        }
        .glassEffect(
            opacity: colorScheme == .dark ? 0.45 : 0.35,
            blurRadius: 20,
            cornerRadius: 16
        )
    }
    
    private func headerView(fontSize: Font = .caption) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "bus.fill")
                .foregroundColor(themeColor)
                .font(fontSize)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(routeName)
                    .font(fontSize)
                    .fontWeight(.bold)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(scheduleTypeName)
                    .font(fontSize == .caption ? .caption2 : .caption)
                    .foregroundColor(secondaryTextColor)
            }
        }
    }
    
    private func noScheduleView(fontSize: Font = .caption, widgetType: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                Image(systemName: "moon.zzz.fill")
                    .font(fontSize == .caption ? .title3 : .title2)
                    .foregroundColor(secondaryTextColor)
                Text(widgetType == "medium" ? "本日の運行終了" : "本日の運行終了")
                    .font(fontSize)
                    .foregroundColor(secondaryTextColor)
            }
            Spacer()
        }
    }
    
    private func timerView(for busDate: Date, fontSize: Font = .caption2, style: Text.DateStyle = .timer) -> some View {
        let timeInterval = busDate.timeIntervalSince(entry.date)
        guard timeInterval > 0 else {
            return AnyView(
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1))
                    
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(fontSize)
                            .foregroundColor(.green)
                        
                        Text("出発済み")
                            .font(fontSize)
                            .fontWeight(.medium)
                            .foregroundColor(secondaryTextColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            )
        }
        
        let maxInterval: TimeInterval = 1800
        let progressWidth = min(1.0, max(0.0, timeInterval / maxInterval))
        
        return AnyView(
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1))
                
                RoundedRectangle(cornerRadius: 6)
                    .fill(getTimeColor(for: busDate).opacity(colorScheme == .dark ? 0.25 : 0.15))
                    .frame(width: progressWidth > 0.05 ? nil : 0, alignment: .leading)
                    .scaleEffect(x: progressWidth, y: 1, anchor: .leading)
                
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(fontSize)
                        .foregroundColor(getTimeColor(for: busDate))
                    
                    Text(busDate, style: style)
                        .font(fontSize)
                        .fontWeight(.medium)
                        .foregroundColor(getTimeColor(for: busDate))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        )
    }
    
    private var smallWidgetLayout: some View {
        VStack(alignment: .leading, spacing: 4) {
            headerView()
            
            Divider()
                .padding(.vertical, 2)
            
            if entry.nextBusTimes.isEmpty || entry.isServiceEndedForToday {
                Spacer()
                noScheduleView(widgetType: "small")
                Spacer()
            } else if let currentBus = entry.currentBus, let currentBusDate = entry.currentBusDate {
                let timeToNextBus = currentBusDate.timeIntervalSince(entry.date)
                let isBusDeparted = timeToNextBus <= 0
                
                VStack(spacing: 2) {
                    HStack {
                        Text("次のバス")
                            .font(.caption2)
                            .foregroundColor(secondaryTextColor)
                        
                        Spacer()
                        
                        if currentBus.isSpecial, let note = currentBus.specialNote {
                            Text(note)
                                .font(.caption2)
                                .bold()
                                .foregroundColor(.red)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.red.opacity(colorScheme == .dark ? 0.2 : 0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(currentBus.formattedTime)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(isBusDeparted ? secondaryTextColor : themeColor)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    timerView(for: currentBusDate)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.top, 4)
                
                Spacer()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .id("widget-\(entry.date.timeIntervalSince1970)")
    }
    
    private var mediumWidgetLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerView(fontSize: .subheadline)
            
            Divider()
                .background(themeColor.opacity(0.2))
            
            if entry.nextBusTimes.isEmpty || entry.isServiceEndedForToday {
                HStack {
                    Spacer()
                    noScheduleView(fontSize: .subheadline, widgetType: "medium")
                    Spacer()
                }
                .padding(.vertical, 10)
            } else {
                HStack(alignment: .top, spacing: 16) {
                    if let currentBus = entry.currentBus, let currentBusDate = entry.currentBusDate {
                        let timeToNextBus = currentBusDate.timeIntervalSince(entry.date)
                        let isBusDeparted = timeToNextBus <= 0
                        
                        nextBusColumn(bus: currentBus, busDate: currentBusDate, isDeparted: isBusDeparted)
                    }
                    
                    upcomingBusesColumn
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .id("widget-\(entry.date.timeIntervalSince1970)")
    }
    
    private func nextBusColumn(bus: BusTimeEntry, busDate: Date, isDeparted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("次のバス")
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)
                
                if bus.isSpecial, let note = bus.specialNote {
                    Text(note)
                        .font(.caption2)
                        .bold()
                        .foregroundColor(.red)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.red.opacity(colorScheme == .dark ? 0.2 : 0.1))
                        .cornerRadius(4)
                }
            }
            
            Text(bus.formattedTime)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(isDeparted ? secondaryTextColor : themeColor)
            
            timerView(for: busDate, fontSize: .caption, style: .relative)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ThemeColors.Glass.light)
        )
    }
    
    private var upcomingBusesColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("その後のバス")
                .font(.caption)
                .foregroundColor(secondaryTextColor)
                .padding(.bottom, 2)
            
            if entry.upcomingBuses.isEmpty {
                Text("本日の次のバスはありません")
                    .font(.caption2)
                    .foregroundColor(secondaryTextColor)
                    .padding(.vertical, 8)
            } else {
                let maxVisibleBuses = 2
                
                ForEach(0..<min(maxVisibleBuses, entry.upcomingBuses.count), id: \.self) { index in
                    busRowView(for: entry.upcomingBuses[index], at: index)
                }
            }
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func busRowView(for bus: BusTimeEntry, at index: Int) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                ZStack(alignment: .topTrailing) {
                    Text(bus.formattedTime)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .padding(.trailing, bus.isSpecial ? 14 : 0)
                    
                    if bus.isSpecial, let note = bus.specialNote {
                        Text(note)
                            .font(.caption2)
                            .bold()
                            .foregroundColor(.red)
                            .padding(.horizontal, 2)
                            .padding(.vertical, 0.3)
                            .background(Color.red.opacity(colorScheme == .dark ? 0.2 : 0.05))
                            .cornerRadius(2)
                            .offset(x: 2, y: 3)
                    }
                }
                
                Spacer()
                
                if let busIndex = entry.nextBusTimes.firstIndex(where: { $0.id == bus.id }),
                   let busDate = entry.getBusTimeAsDate(index: busIndex) {
                    HStack(spacing: 2) {
                        Text(busDate, style: .relative)
                            .font(.caption2)
                            .foregroundColor(secondaryTextColor)
                    }
                }
            }
            
            if index == 0 && entry.upcomingBuses.count > 1 {
                Divider()
                    .padding(.vertical, 4)
                    .padding(.leading, 20)
            }
        }
    }
    
    private func getTimeColor(for busDate: Date) -> Color {
        let timeInterval = busDate.timeIntervalSince(entry.date)
        
        if timeInterval <= 60 {
            return colorScheme == .dark ? .pink : .red
        } else if timeInterval <= 600 {
            return colorScheme == .dark ? .yellow : .orange
        } else {
            return colorScheme == .dark ? .cyan : .blue
        }
    }
}

// MARK: - Widget Definition

struct BusWidget: Widget {
    let kind: String = "BusWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: BusConfigurationIntent.self,
            provider: BusProvider()
        ) { entry in
            BusWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    glassBackground
                }
                .widgetURL(entry.getBusDeepLink())
        }
        .configurationDisplayName("学校バス時刻表")
        .description("次のバスの発車時刻を表示します")
        .supportedFamilies([.systemSmall, .systemMedium])
        .disableContentMarginsIfAvailable()
    }
    
    private var glassBackground: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    ThemeColors.Gradient.startGradient(for: .light),
                    ThemeColors.Gradient.endGradient(for: .light)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay {
                GlassBackground(
                    opacity: 0.3,
                    blurRadius: 20,
                    saturation: 1.5,
                    borderOpacity: 0.3,
                    cornerRadius: 16
                )
            }
        }
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    BusWidget()
} timeline: {
    let times = [
        BusTimeEntry(hour: 10, minute: 0),
        BusTimeEntry(hour: 10, minute: 30),
        BusTimeEntry(hour: 11, minute: 0),
    ]
    BusEntry(
        date: .now,
        configuration: BusConfigurationIntent(),
        nextBusTimes: times,
        scheduleType: "weekday"
    )
}

#Preview(as: .systemMedium) {
    BusWidget()
} timeline: {
    let times = [
        BusTimeEntry(hour: 10, minute: 0),
        BusTimeEntry(hour: 10, minute: 30),
        BusTimeEntry(hour: 11, minute: 0),
    ]
    BusEntry(
        date: .now,
        configuration: BusConfigurationIntent(),
        nextBusTimes: times,
        scheduleType: "weekday"
    )
}
