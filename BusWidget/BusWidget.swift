import SwiftUI
import WidgetKit

// MARK: - モデル

struct BusWidgetSchedule {
    struct TimeEntry: Codable, Identifiable, Equatable {
        let hour: Int
        let minute: Int
        let isSpecial: Bool
        let specialNote: String?

        var id: String { "\(hour):\(minute)" }

        var formattedTime: String {
            String(format: "%02d:%02d", hour, minute)
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.hour == rhs.hour && lhs.minute == rhs.minute
        }

        init(hour: Int, minute: Int, isSpecial: Bool = false, specialNote: String? = nil) {
            self.hour = hour
            self.minute = minute
            self.isSpecial = isSpecial
            self.specialNote = specialNote
        }

        func date(relativeTo referenceDate: Date) -> Date? {
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
            components.hour = hour
            components.minute = minute
            components.second = 0
            guard let date = calendar.date(from: components) else { return nil }
            return date <= referenceDate ? calendar.date(byAdding: .day, value: 1, to: date) : date
        }
    }
}

// MARK: - ルートテーマ

enum RouteTheme {
    static func color(for route: RouteTypeEnum) -> Color {
        switch route {
        case .fromSeisekiToSchool, .fromSchoolToSeiseki: .blue
        case .fromNagayamaToSchool, .fromSchoolToNagayama: .teal
        }
    }
}

// MARK: - タイムラインプロバイダー

struct Provider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: .now,
            configuration: ConfigurationAppIntent(),
            nextBusTimes: [
                .init(hour: 10, minute: 0),
                .init(hour: 10, minute: 30),
                .init(hour: 11, minute: 0),
            ],
            scheduleType: "weekday"
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let now = Date()
        let scheduleType = BusWidgetDataProvider.getScheduleTypeForDate(now)

        if context.isPreview {
            return SimpleEntry(
                date: now,
                configuration: configuration,
                nextBusTimes: [
                    .init(hour: 8, minute: 30),
                    .init(hour: 9, minute: 0),
                    .init(hour: 9, minute: 30),
                ],
                scheduleType: scheduleType
            )
        }

        let times = fetchNextBusTimes(for: configuration.routeType, from: now)
        return SimpleEntry(date: now, configuration: configuration, nextBusTimes: times, scheduleType: scheduleType)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let now = Date()
        let calendar = Calendar.current
        var entries: [SimpleEntry] = []

        let scheduleType = BusWidgetDataProvider.getScheduleTypeForDate(now)
        let busTimes = fetchNextBusTimes(for: configuration.routeType, from: now)

        // 現在のエントリー（カウントダウンはText(date, style: .relative)で自動更新）
        entries.append(SimpleEntry(date: now, configuration: configuration, nextBusTimes: busTimes, scheduleType: scheduleType))

        // バス出発時にバスリストをローテーションするためのエントリー
        for bus in busTimes {
            guard let busDate = bus.date(relativeTo: now),
                  busDate > now else { continue }

            // 緊急度の色の境界線
            let fiveMinBefore = busDate.addingTimeInterval(-5 * 60)
            if fiveMinBefore > now {
                entries.append(SimpleEntry(date: fiveMinBefore, configuration: configuration, nextBusTimes: busTimes, scheduleType: scheduleType))
            }
            let oneMinBefore = busDate.addingTimeInterval(-60)
            if oneMinBefore > now {
                entries.append(SimpleEntry(date: oneMinBefore, configuration: configuration, nextBusTimes: busTimes, scheduleType: scheduleType))
            }

            // 出発直後 — バスリストを更新
            let shiftDate = busDate.addingTimeInterval(1)
            let updatedType = BusWidgetDataProvider.getScheduleTypeForDate(shiftDate)
            let updatedTimes = fetchNextBusTimes(for: configuration.routeType, from: shiftDate)
            entries.append(SimpleEntry(date: shiftDate, configuration: configuration, nextBusTimes: updatedTimes, scheduleType: updatedType))
        }

        // 明日の真夜中
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
            let midnightType = BusWidgetDataProvider.getScheduleTypeForDate(tomorrow)
            let midnightTimes = fetchNextBusTimes(for: configuration.routeType, from: tomorrow)
            entries.append(SimpleEntry(date: tomorrow, configuration: configuration, nextBusTimes: midnightTimes, scheduleType: midnightType))
        }

        let reloadDate: Date = {
            if let lastBus = busTimes.last,
               let lastDate = lastBus.date(relativeTo: now),
               lastDate > now {
                return lastDate.addingTimeInterval(60)
            }
            return now.addingTimeInterval(1800)
        }()

        return Timeline(entries: entries, policy: .after(reloadDate))
    }

    private func fetchNextBusTimes(for routeType: RouteTypeEnum, from date: Date) -> [BusWidgetSchedule.TimeEntry] {
        let scheduleType = BusWidgetDataProvider.getScheduleTypeForDate(date)
        return BusWidgetDataProvider.getNextBusTimes(
            routeType: routeType.rawValue,
            scheduleType: scheduleType,
            from: date
        )
    }
}

// MARK: - タイムラインエントリー

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let nextBusTimes: [BusWidgetSchedule.TimeEntry]
    let scheduleType: String

    var deepLinkURL: URL {
        var components = URLComponents()
        components.scheme = "tama"
        components.host = "bus"
        components.queryItems = [
            URLQueryItem(name: "route", value: configuration.routeType.rawValue),
            URLQueryItem(name: "schedule", value: scheduleType),
        ]
        return components.url ?? URL(string: "tama://bus")!
    }

    var themeColor: Color { RouteTheme.color(for: configuration.routeType) }
    var currentBus: BusWidgetSchedule.TimeEntry? { nextBusTimes.first }
    var upcomingBuses: [BusWidgetSchedule.TimeEntry] { Array(nextBusTimes.dropFirst().prefix(2)) }
    var isServiceEnded: Bool { nextBusTimes.isEmpty }

    func busDate(for entry: BusWidgetSchedule.TimeEntry) -> Date? {
        entry.date(relativeTo: date)
    }

    func minutesUntil(_ busEntry: BusWidgetSchedule.TimeEntry) -> Int? {
        guard let target = busDate(for: busEntry) else { return nil }
        let seconds = target.timeIntervalSince(date)
        guard seconds > 0 else { return nil }
        return Int(ceil(seconds / 60))
    }
}

// MARK: - ウィジェットビュー

struct BusWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    private var accent: Color { entry.themeColor }

    var routeName: String {
        switch entry.configuration.routeType {
        case .fromSeisekiToSchool: "聖蹟桜ヶ丘駅発"
        case .fromNagayamaToSchool: "永山駅発"
        case .fromSchoolToSeiseki: "聖蹟桜ヶ丘駅行"
        case .fromSchoolToNagayama: "永山駅行"
        }
    }

    var scheduleTypeName: String {
        BusWidgetDataProvider.getScheduleTypeDisplayName(entry.scheduleType)
    }

    var body: some View {
        Link(destination: entry.deepLinkURL) {
            switch family {
            case .systemMedium: mediumLayout
            default: smallLayout
            }
        }
    }

    private func urgencyColor(minutes: Int?) -> Color {
        guard let m = minutes else { return .secondary }
        if m <= 1 { return .red }
        if m <= 5 { return .orange }
        return accent
    }

    // MARK: - 共有サブビュー

    private func headerView(titleSize: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 4) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(accent)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(routeName)
                    .font(.system(size: titleSize, weight: .semibold))
                Text(scheduleTypeName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func countdownView(for bus: BusWidgetSchedule.TimeEntry, fontSize: CGFloat) -> some View {
        let mins = entry.minutesUntil(bus)
        let departed = mins == nil
        return HStack(spacing: 3) {
            if departed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                Text("出発済み")
                    .font(.system(size: fontSize, weight: .medium))
            } else {
                Image(systemName: "clock.fill")
                    .font(.system(size: 11))
                (Text("あと ")
                    .font(.system(size: fontSize, weight: .medium))
                + Text(entry.busDate(for: bus) ?? .now, style: .relative)
                    .font(.system(size: fontSize, weight: .bold, design: .rounded)))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
        }
        .foregroundStyle(departed ? .green : urgencyColor(minutes: mins))
    }

    private func busTimeView(for bus: BusWidgetSchedule.TimeEntry, departed: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(bus.formattedTime)
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.8)
                .lineLimit(1)
                .foregroundColor(departed ? .secondary : .primary)
            if bus.isSpecial, let note = bus.specialNote {
                Text(note)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.red)
            }
        }
    }

    private var serviceEndedView: some View {
        VStack(spacing: 4) {
            Image(systemName: "moon.zzz.fill")
                .font(.title3)
                .foregroundStyle(.tertiary)
            Text("本日の運行終了")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - スモールウィジェット

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView(titleSize: 13)

            if entry.isServiceEnded {
                Spacer()
                serviceEndedView
                Spacer()
            } else if let bus = entry.currentBus {
                let departed = entry.minutesUntil(bus) == nil

                Spacer()

                busTimeView(for: bus, departed: departed)
                    .frame(maxWidth: .infinity, alignment: .center)

                Spacer().frame(height: 6)

                countdownView(for: bus, fontSize: 13)
                    .frame(maxWidth: .infinity)

                Spacer()
            }
        }
        .padding(10)
    }

    // MARK: - ミディアムウィジェット

    private var mediumLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            // 左パネル
            VStack(alignment: .leading, spacing: 0) {
                headerView(titleSize: 14)

                if entry.isServiceEnded {
                    Spacer()
                    serviceEndedView
                    Spacer()
                } else if let bus = entry.currentBus {
                    let departed = entry.minutesUntil(bus) == nil

                    Spacer().frame(height: 10)

                    busTimeView(for: bus, departed: departed)

                    Spacer().frame(height: 4)

                    countdownView(for: bus, fontSize: 14)

                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(.quaternary)
                .frame(width: 0.5)
                .padding(.vertical, 2)

            // 右パネル
            VStack(alignment: .leading, spacing: 0) {
                Text("その後")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                if entry.isServiceEnded || entry.upcomingBuses.isEmpty {
                    Spacer()
                    Text("なし")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    Spacer().frame(height: 10)
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(entry.upcomingBuses) { bus in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(alignment: .firstTextBaseline, spacing: 0) {
                                    Text(bus.formattedTime)
                                        .font(.system(size: 22, weight: .bold, design: .rounded))
                                    if bus.isSpecial, let note = bus.specialNote {
                                        Text(" " + note)
                                            .font(.system(size: 10, weight: .heavy))
                                            .foregroundStyle(.red)
                                    }
                                }
                                Text(entry.busDate(for: bus) ?? .now, style: .relative)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)
        }
        .padding(10)
    }
}

// MARK: - ウィジェット設定

@main
struct BusWidget: Widget {
    let kind: String = "BusWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            BusWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(entry.deepLinkURL)
        }
        .configurationDisplayName("学校バス時刻表")
        .description("次のバスの発車時刻を表示します")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - プレビュー

#Preview(as: .systemSmall) {
    BusWidget()
} timeline: {
    SimpleEntry(
        date: .now,
        configuration: .seiseki,
        nextBusTimes: [
            .init(hour: 10, minute: 0),
            .init(hour: 10, minute: 30),
            .init(hour: 11, minute: 0, isSpecial: true, specialNote: "M"),
        ],
        scheduleType: "weekday"
    )
    SimpleEntry(
        date: .now,
        configuration: .nagayama,
        nextBusTimes: [.init(hour: 9, minute: 45), .init(hour: 10, minute: 15)],
        scheduleType: "wednesday"
    )
    SimpleEntry(
        date: .now, configuration: .seiseki, nextBusTimes: [], scheduleType: "weekday"
    )
}

#Preview(as: .systemMedium) {
    BusWidget()
} timeline: {
    SimpleEntry(
        date: .now,
        configuration: .seiseki,
        nextBusTimes: [
            .init(hour: 10, minute: 0),
            .init(hour: 10, minute: 30),
            .init(hour: 11, minute: 0, isSpecial: true, specialNote: "M"),
        ],
        scheduleType: "weekday"
    )
    SimpleEntry(
        date: .now,
        configuration: .nagayama,
        nextBusTimes: [
            .init(hour: 9, minute: 45),
            .init(hour: 10, minute: 15),
            .init(hour: 10, minute: 45),
        ],
        scheduleType: "wednesday"
    )
    SimpleEntry(
        date: .now, configuration: .seiseki, nextBusTimes: [], scheduleType: "saturday"
    )
}
