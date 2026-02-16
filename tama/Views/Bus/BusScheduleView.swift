import CoreLocation
import SwiftUI

struct BusScheduleView: View {
    // MARK: - プロパティ
    @StateObject private var viewModel = BusScheduleViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var ratingService: RatingService

    // MARK: - ボディ
    var body: some View {
        VStack(spacing: 0) {
            if let busSchedule = viewModel.busSchedule {
                // 臨時ダイヤメッセージがある場合は表示
                if let messages = busSchedule.temporaryMessages, !messages.isEmpty {
                    BusTemporaryMessagesView(messages: messages)
                }

                // 時刻表タイプセレクタ（平日/水曜日/土曜日）
                BusScheduleTypeSelector(
                    selectedScheduleType: $viewModel.selectedScheduleType,
                    onChanged: { viewModel.onScheduleTypeChanged() }
                )

                // 路線セレクタ
                BusRouteTypeSelector(
                    selectedRouteType: $viewModel.selectedRouteType,
                    colorScheme: colorScheme,
                    onChanged: { viewModel.onRouteTypeChanged() }
                )

                // 時刻表コンテンツ（浮動時間カードを含む）
                ZStack(alignment: .top) {
                    let basePadding: CGFloat = viewModel.selectedTimeEntry == nil ? 90 : 110
                    let pinExtraPadding: CGFloat = viewModel.busSchedule?.pin != nil ? 56 : 0
                    let topPadding: CGFloat = basePadding + pinExtraPadding
                    BusTimeTableContent(viewModel: viewModel, colorScheme: colorScheme)
                        .padding(.top, topPadding)

                    // 浮動現在時刻表示カード
                    BusTimeCardView(viewModel: viewModel, colorScheme: colorScheme)
                        .padding(.horizontal)
                        .padding(.top, 10)
                }
            } else if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                        .multilineTextAlignment(.center)

                    Button(action: {
                        viewModel.errorMessage = nil
                        viewModel.fetchBusScheduleData()
                    }) {
                        Text("再読み込み")
                    }
                    .padding(.top, 16)
                }
            } else {
                ProgressView("読み込み中...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.clearSelection()
                }
        )
        .background(Color(UIColor.systemBackground))
        .edgesIgnoringSafeArea(.bottom)
        .onAppear {
            viewModel.setupOnAppear()
            ratingService.recordSignificantEvent()
        }
        .onDisappear {
            viewModel.cleanupOnDisappear()
        }
    }
}

// MARK: - 臨時ダイヤメッセージビュー

struct BusTemporaryMessagesView: View {
    let messages: [BusSchedule.TemporaryMessage]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(messages, id: \.title) { message in
                        messageCard(message)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .padding(.top, 4)
            }
        }
        .background(Color(UIColor.systemBackground))
    }

    private func messageCard(_ message: BusSchedule.TemporaryMessage) -> some View {
        Group {
            if let url = URL(string: message.url) {
                messageCardContent(message, showChevron: true, url: url)
            } else {
                messageCardContent(message, showChevron: false, url: nil)
            }
        }
    }

    private func messageCardContent(
        _ message: BusSchedule.TemporaryMessage, showChevron: Bool, url: URL? = nil
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 14))

            Text(message.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if showChevron, let url = url {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(width: 260)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - 時刻表タイプセレクタ

struct BusScheduleTypeSelector: View {
    @Binding var selectedScheduleType: BusSchedule.ScheduleType
    var onChanged: () -> Void

    var body: some View {
        HStack {
            Picker("スケジュールタイプ", selection: $selectedScheduleType) {
                Text("平日（水曜日を除く）").tag(BusSchedule.ScheduleType.weekday)
                Text("水曜日").tag(BusSchedule.ScheduleType.wednesday)
                Text("土曜日").tag(BusSchedule.ScheduleType.saturday)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .onChange(of: selectedScheduleType) { _, _ in
                onChanged()
            }
        }
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - 路線セレクタ

struct BusRouteTypeSelector: View {
    @Binding var selectedRouteType: BusSchedule.RouteType
    let colorScheme: ColorScheme
    var onChanged: () -> Void

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    routeButton(
                        title: NSLocalizedString("聖蹟桜ヶ丘駅発", comment: ""),
                        type: .fromSeisekiToSchool
                    )
                    .id("fromSeisekiToSchool")
                    routeButton(
                        title: NSLocalizedString("永山駅発", comment: ""),
                        type: .fromNagayamaToSchool
                    )
                    .id("fromNagayamaToSchool")

                    Divider()
                        .frame(height: 20)
                        .background(Color.gray.opacity(0.3))

                    routeButton(
                        title: NSLocalizedString("聖蹟桜ヶ丘駅行", comment: ""),
                        type: .fromSchoolToSeiseki
                    )
                    .id("fromSchoolToSeiseki")
                    routeButton(
                        title: NSLocalizedString("永山駅行", comment: ""),
                        type: .fromSchoolToNagayama
                    )
                    .id("fromSchoolToNagayama")
                }
                .padding(.horizontal)
                .padding(.vertical, 5)
            }
            .onChange(of: selectedRouteType) { _, newValue in
                withAnimation {
                    scrollProxy.scrollTo(newValue.rawValue, anchor: .center)
                }
            }
        }
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
    }

    private func routeButton(title: String, type: BusSchedule.RouteType) -> some View {
        Button(action: {
            selectedRouteType = type
            onChanged()
        }) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            selectedRouteType == type
                                ? Color(red: 244 / 255, green: 134 / 255, blue: 142 / 255)
                                : Color.gray.opacity(colorScheme == .dark ? 0.25 : 0.15)
                        )
                        .shadow(
                            color: selectedRouteType == type
                                ? Color(red: 244 / 255, green: 134 / 255, blue: 142 / 255)
                                    .opacity(0.3) : Color.clear,
                            radius: 3, x: 0, y: 2)
                )
                .foregroundColor(selectedRouteType == type ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: selectedRouteType)
    }
}

// MARK: - 浮動時間カードビュー

struct BusTimeCardView: View {
    @ObservedObject var viewModel: BusScheduleViewModel
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("現在時刻")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(viewModel.timeFormatter.string(from: viewModel.currentTime))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                }

                Spacer()

                if let selectedTime = viewModel.selectedTimeEntry,
                    viewModel.isTimeEqual(selectedTime, to: viewModel.currentTime) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("バスの出発時刻です")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                            .transition(.opacity)

                        Text("0分0秒")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.orange)
                            .transition(.opacity)
                    }
                } else if let nextBus = viewModel.selectedTimeEntry ?? viewModel.getNextBus() {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(viewModel.selectedTimeEntry != nil ? "選択したバスまで" : "次のバスまで")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .transition(.opacity)

                        HStack(spacing: 4) {
                            Text(viewModel.getCountdownText(to: nextBus))
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(
                                    viewModel.selectedTimeEntry != nil ? .orange : .green)
                                .transition(.opacity)

                            if let note = nextBus.specialNote {
                                Text(note)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(4)
                                    .transition(.opacity)
                            }
                        }

                        if viewModel.selectedTimeEntry != nil {
                            HStack {
                                Text("バス時刻")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(
                                    "\(String(format: "%02d:%02d", nextBus.hour, nextBus.minute))"
                                )
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.orange)
                            }
                            .opacity(viewModel.cardInfoAppeared ? 1 : 0)
                            .offset(y: viewModel.cardInfoAppeared ? 0 : 5)
                            .transition(.opacity)
                        }
                    }
                } else {
                    Text("本日の運行は終了しました")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if let pinMessage = viewModel.busSchedule?.pin {
                pinMessageRow(pinMessage)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(
                    color: Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.2), radius: 3,
                    x: 0, y: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {}
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedTimeEntry)
    }

    private func pinMessageRow(_ pinMessage: BusSchedule.PinMessage) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "pin.fill")
                .foregroundColor(.orange)

            Text(pinMessage.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.8)

            Spacer()

            if let url = URL(string: pinMessage.url) {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Text("詳細")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.orange)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.08)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.6), lineWidth: 1)
        )
    }
}

// MARK: - 時刻表コンテンツ

struct BusTimeTableContent: View {
    @ObservedObject var viewModel: BusScheduleViewModel
    let colorScheme: ColorScheme

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .center, spacing: 16) {
                    scheduleTableView
                        .onChange(of: viewModel.scrollToHour) { _, newValue in
                            if let hour = newValue {
                                withAnimation {
                                    scrollProxy.scrollTo(
                                        "hour_\(hour)", anchor: UnitPoint(x: 0, y: 0.1))
                                }
                            }
                        }

                    specialNotesView
                }
                .padding()
            }
            .background(Color(UIColor.systemBackground))
            .onAppear {
                if let hour = viewModel.scrollToHour {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation {
                            scrollProxy.scrollTo("hour_\(hour)", anchor: UnitPoint(x: 0, y: 0.1))
                        }
                    }
                }
            }
        }
    }

    // MARK: - サブビュー

    private var scheduleTableView: some View {
        VStack(spacing: 0) {
            tableHeader

            Divider()
                .background(Color.gray.opacity(0.3))

            if viewModel.selectedScheduleType == .wednesday {
                wednesdaySpecialMessage
            }

            ForEach(viewModel.getFilteredSchedule().hourSchedules, id: \.hour) { hourSchedule in
                if !hourSchedule.times.isEmpty {
                    hourScheduleRow(hourSchedule)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(
                    color: Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.1), radius: 3,
                    x: 0, y: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.clearSelection()
        }
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            Text("時間")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .center)
                .padding(.vertical, 12)

            Divider()
                .frame(width: 1)
                .background(Color.gray.opacity(0.3))

            Text("発車時刻")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
        }
        .background(Color.gray.opacity(colorScheme == .dark ? 0.15 : 0.05))
    }

    private var wednesdaySpecialMessage: some View {
        HStack {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)

            Text("水曜日は特別ダイヤで運行しています")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)

            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
    }


    private func hourScheduleRow(_ hourSchedule: BusSchedule.HourSchedule) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("\(hourSchedule.hour)")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(width: 70, alignment: .center)
                    .padding(.vertical, 12)

                Divider()
                    .frame(width: 1)
                    .background(Color.gray.opacity(0.3))

                VStack(alignment: .center) {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.fixed(50), spacing: 8), count: 5),
                        alignment: .center, spacing: 12
                    ) {
                        ForEach(hourSchedule.times, id: \.minute) { time in
                            timeEntryView(time)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.clearSelection()
                }
            }

            Divider()
                .background(Color.gray.opacity(0.3))
        }
        .id("hour_\(hourSchedule.hour)")
        .background(
            viewModel.isCurrentHour(hourSchedule.hour)
                ? Color.green.opacity(colorScheme == .dark ? 0.2 : 0.1)
                : (hourSchedule.hour % 2 == 0
                    ? Color(UIColor.systemBackground)
                    : Color.gray.opacity(colorScheme == .dark ? 0.1 : 0.03))
        )
    }

    private func timeEntryView(_ time: BusSchedule.TimeEntry) -> some View {
        ZStack(alignment: .topTrailing) {
            Text("\(String(format: "%02d", time.minute))")
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(
                    viewModel.isCurrentOrNextBus(time) || viewModel.selectedTimeEntry == time
                        ? .white : .primary
                )
                .frame(width: 36, height: 36, alignment: .center)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            viewModel.selectedTimeEntry == time
                                ? Color.orange.opacity(0.9)
                                : (viewModel.isCurrentOrNextBus(time)
                                    ? Color.blue.opacity(0.9) : Color.clear)
                        )
                )

            if let note = time.specialNote {
                Text(note)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(9)
                    .offset(x: 8, y: -4)
            }
        }
        .frame(width: 50, height: 36)
        .onTapGesture {
            viewModel.handleTimeEntryTap(time)
        }
    }

    private var specialNotesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("備考")
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(viewModel.busSchedule?.specialNotes ?? [], id: \.symbol) { note in
                HStack(alignment: .top, spacing: 8) {
                    Text(note.symbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(10)

                    Text(note.description)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if viewModel.selectedScheduleType != .wednesday {
                wednesdayWarningMessage
            }
        }
        .padding()
        .frame(width: UIScreen.main.bounds.width - 32)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(
                    color: Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.1), radius: 3,
                    x: 0, y: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {}
    }

    private var wednesdayWarningMessage: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)

            Text("水曜日は特別ダイヤで運行しています")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.red)

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - 位置情報デリゲート

final class LocationManagerDelegate: NSObject, CLLocationManagerDelegate {
    private let didUpdateLocation: (CLLocation) -> Void
    private let didEnterRegion: () -> Void
    private let didExitRegion: () -> Void

    init(
        didUpdateLocation: @escaping (CLLocation) -> Void,
        didEnterRegion: @escaping () -> Void,
        didExitRegion: @escaping () -> Void
    ) {
        self.didUpdateLocation = didUpdateLocation
        self.didEnterRegion = didEnterRegion
        self.didExitRegion = didExitRegion
        super.init()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            didUpdateLocation(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if region.identifier == "SchoolArea" {
            didEnterRegion()
        }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if region.identifier == "SchoolArea" {
            didExitRegion()
        }
    }

    func locationManager(
        _ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus
    ) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            if let location = manager.location {
                didUpdateLocation(location)
            }
        case .denied, .restricted:
            print("位置情報の使用が拒否または制限されました")
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let error = error as? CLError {
            switch error.code {
            case .denied:
                print("位置情報の使用が拒否されました")
            case .network:
                print("位置情報の取得中にネットワークエラーが発生しました")
            case .locationUnknown:
                print("位置を特定できません")
            default:
                print("位置情報の取得に失敗しました: \(error.localizedDescription)")
            }
        } else {
            print("位置情報の取得に失敗しました: \(error.localizedDescription)")
        }
    }
}

// MARK: - プレビュー

#Preview {
    BusScheduleView()
}
