import CoreLocation
import SwiftUI

struct BusScheduleView: View {
    // MARK: - プロパティ
    @State private var selectedScheduleType: BusSchedule.ScheduleType = .weekday
    @State private var selectedRouteType: BusSchedule.RouteType = .fromSeisekiToSchool
    @State private var currentTime = Date()
    @State private var timer: Timer? = nil
    @State private var scrollToHour: Int? = nil
    @State private var secondsTimer: Timer? = nil
    @State private var selectedTimeEntry: BusSchedule.TimeEntry? = nil
    @State private var cardInfoAppeared: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var ratingService: RatingService
    // フォアグラウンド復帰通知オブザーバー
    @State private var willEnterForegroundObserver: NSObjectProtocol? = nil
    @State private var busParametersObserver: NSObjectProtocol?  // URLスキームからのパラメータ通知用

    // 位置情報関連
    @State private var locationManager: CLLocationManager?
    @State private var locationDelegate: LocationManagerDelegate?  // デリゲートへの強い参照を保持するプロパティ
    @State private var userInSchoolArea: Bool = false
    // 学校の位置情報（多摩大学の座標）35.630604, 139.464382
    private let schoolLocation = CLLocationCoordinate2D(latitude: 35.630604, longitude: 139.464382)
    private let geofenceRadius: CLLocationDistance = 400

    // APIから取得したバス時刻表データ
    @State private var busSchedule: BusSchedule? = nil
    @State private var errorMessage: String? = nil

    // 校車時刻表データ
    private let busScheduleService = BusScheduleService.shared

    // MARK: - ボディ
    var body: some View {
        VStack(spacing: 0) {
            if let busSchedule = busSchedule {
                // 臨時ダイヤメッセージがある場合は表示
                if let messages = busSchedule.temporaryMessages, !messages.isEmpty {
                    temporaryMessagesView(messages)
                }

                // 時刻表タイプセレクタ（平日/水曜日/土曜日）
                scheduleTypeSelector

                // 路線セレクタ
                routeTypeSelector

                // 時刻表コンテンツ（浮動時間カードを含む）
                ZStack(alignment: .top) {
                    let topPadding: CGFloat = selectedTimeEntry == nil ? 90 : 110
                    scheduleContent
                        .padding(.top, topPadding)  // 浮動カードのスペースを確保

                    // 浮動現在時刻表示カード
                    currentTimeView
                        .padding(.horizontal)
                        .padding(.top, 10)
                }
            } else if let errorMessage = errorMessage {
                VStack(spacing: 16) {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                        .multilineTextAlignment(.center)

                    Button(action: {
                        self.errorMessage = nil
                        self.fetchBusScheduleData()
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
            // 背景をタップしたら選択解除
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedTimeEntry = nil
                }
        )
        .background(Color(UIColor.systemBackground))
        .edgesIgnoringSafeArea(.bottom)
        .onAppear {
            print("BusScheduleView: onAppear")
            setupTimers()
            
            // バス時刻表表示の重要イベントを記録
            ratingService.recordSignificantEvent()

            // バスページが開かれるたびに位置情報を更新
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // 位置情報マネージャーを初期化して監視を開始
                self.setupLocationManager()
            }

            // バス時刻表データの取得
            fetchBusScheduleData()

            // アプリがフォアグラウンドに戻ってきた時の処理
            willEnterForegroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { _ in
                currentTime = Date()
                fetchBusScheduleData()
            }

            // URLスキームからのバスパラメータ通知を監視
            setupBusParametersObserver()
        }
        .onDisappear {
            print("BusScheduleView: onDisappear - 位置情報の監視を停止します")
            cleanupTimers()
            removeObservers()
        }
    }

    // MARK: - データ取得
    private func fetchBusScheduleData() {
        print("BusScheduleView: fetchBusScheduleData が呼び出されました")
        busScheduleService.fetchBusScheduleData { schedule, error in
            if error != nil {
                self.errorMessage = NSLocalizedString(
                    "時刻表の読み込みに失敗しました。\nネットワーク接続を確認してください。", comment: "")
            } else {
                self.busSchedule = schedule
            }
        }
    }

    // MARK: - 位置情報関連
    private func setupLocationManager() {
        print("BusScheduleView: setupLocationManager が呼び出されました")

        // 既存のlocationManagerがある場合は一度クリア
        if locationManager != nil {
            locationManager?.delegate = nil
            locationManager = nil
            locationDelegate = nil
        }

        // 新しいlocationManagerを作成
        locationManager = CLLocationManager()

        // デリゲートオブジェクトを作成して保持
        locationDelegate = LocationManagerDelegate(
            didUpdateLocation: { location in
                self.checkIfUserInSchoolArea(location)
            },
            didEnterRegion: {
                self.userInSchoolArea = true
                self.updateRouteBasedOnLocation()
            },
            didExitRegion: {
                self.userInSchoolArea = false
                self.updateRouteBasedOnLocation()
            }
        )

        // デリゲートを設定（nilチェックを追加）
        guard let locationManager = locationManager, let locationDelegate = locationDelegate else {
            print("BusScheduleView: locationManagerまたはlocationDelegateがnilです")
            return
        }

        locationManager.delegate = locationDelegate

        // 位置情報の使用許可をリクエスト
        locationManager.requestWhenInUseAuthorization()

        // 位置情報の精度を設定
        locationManager.desiredAccuracy = kCLLocationAccuracyBest

        // ジオフェンスの設定
        setupGeofence()

        // 位置情報の更新を開始
        locationManager.startUpdatingLocation()
    }

    private func setupGeofence() {
        guard let locationManager = locationManager else {
            print("BusScheduleView: setupGeofence - locationManagerがnilです")
            return
        }

        // 既存の全てのジオフェンスを削除
        locationManager.monitoredRegions.forEach { region in
            if region is CLCircularRegion {
                locationManager.stopMonitoring(for: region)
            }
        }

        // 学校エリアのジオフェンスを作成
        let schoolRegion = CLCircularRegion(
            center: schoolLocation,
            radius: geofenceRadius,
            identifier: "SchoolArea"
        )

        // ジオフェンスを有効化（入場・退場両方を監視）
        schoolRegion.notifyOnEntry = true
        schoolRegion.notifyOnExit = true

        // ジオフェンスの監視を開始
        locationManager.startMonitoring(for: schoolRegion)

        print("BusScheduleView: 学校エリアのジオフェンスを設定しました（半径\(geofenceRadius)m）")
    }

    private func checkIfUserInSchoolArea(_ location: CLLocation) {
        // ユーザーの現在位置と学校の位置の距離を計算
        let schoolRegionCenter = CLLocation(
            latitude: schoolLocation.latitude, longitude: schoolLocation.longitude)
        let distance = location.distance(from: schoolRegionCenter)

        // 距離が半径以内かどうかをチェック
        let isInSchoolArea = distance <= geofenceRadius
        print(
            "BusScheduleView: checkIfUserInSchoolArea - 距離: \(distance)メートル, 半径: \(geofenceRadius)メートル"
        )
        print(
            "BusScheduleView: checkIfUserInSchoolArea - 現在の位置: \(location.coordinate.latitude), \(location.coordinate.longitude)"
        )
        print(
            "BusScheduleView: checkIfUserInSchoolArea - 学校の位置: \(schoolLocation.latitude), \(schoolLocation.longitude)"
        )
        print("BusScheduleView: checkIfUserInSchoolArea - 結果: \(isInSchoolArea)")

        // 状態が変化した場合のみ更新
        if isInSchoolArea != userInSchoolArea {
            userInSchoolArea = isInSchoolArea
            updateRouteBasedOnLocation()
        }
    }

    private func updateRouteBasedOnLocation() {
        // ユーザーが学校エリア内にいる場合
        if userInSchoolArea {
            // 現在の選択が「学校発」の路線（聖蹟桜ヶ丘駅行または永山駅行）かどうかをチェック
            let isAlreadySchoolDeparture =
                selectedRouteType == .fromSchoolToSeiseki
                || selectedRouteType == .fromSchoolToNagayama

            // 既に「学校発」の路線が選択されている場合は、ユーザーの選択を尊重して変更しない
            if !isAlreadySchoolDeparture {
                withAnimation {
                    selectedRouteType = .fromSchoolToNagayama
                    // 路線が変更されたときにスクロール位置を更新
                    updateScrollToHour()
                }
            }
        } else {
            // 学校エリア外にいる場合
            // 現在の選択が「駅発」の路線（聖蹟桜ヶ丘駅発または永山駅発）かどうかをチェック
            let isAlreadyStationDeparture =
                selectedRouteType == .fromSeisekiToSchool
                || selectedRouteType == .fromNagayamaToSchool

            // 既に「駅発」の路線が選択されている場合は、ユーザーの選択を尊重して変更しない
            if !isAlreadyStationDeparture {
                withAnimation {
                    selectedRouteType = .fromSeisekiToSchool
                    // 路線が変更されたときにスクロール位置を更新
                    updateScrollToHour()
                }
            }
        }
    }

    // MARK: - 臨時ダイヤメッセージビュー
    private func temporaryMessagesView(_ messages: [BusSchedule.TemporaryMessage]) -> some View {
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

    // 個別のメッセージカード
    private func messageCard(_ message: BusSchedule.TemporaryMessage) -> some View {
        Group {
            if let url = URL(string: message.url) {
                messageCardContent(message, showChevron: true, url: url)
            } else {
                messageCardContent(message, showChevron: false, url: nil)
            }
        }
    }

    // メッセージカードの共通コンテンツ
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

    // MARK: - セットアップとクリーンアップ
    private func setupTimers() {
        fetchBusScheduleData()
        setupTimeUpdater()

        // 位置情報マネージャーの初期化と位置の確認
        setupLocationManager()

        // 1分ごとに現在時刻を更新するタイマー
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [self] _ in
            currentTime = Date()
            updateScrollToHour()
        }

        // 1秒ごとに更新する秒単位のタイマー
        secondsTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [self] _ in
            currentTime = Date()
            checkIfSelectedTimePassed()
        }

        // 平日か水曜日か土曜日かを自動で選択
        checkIfWeekday()

        // スクロール位置を初期化
        updateScrollToHour()
    }

    private func cleanupTimers() {
        timer?.invalidate()
        timer = nil
        secondsTimer?.invalidate()
        secondsTimer = nil

        // 位置情報の更新を停止
        if let locationManager = locationManager {
            print("BusScheduleView: 位置情報の監視を停止します")
            locationManager.stopUpdatingLocation()

            // 監視中のすべてのジオフェンスを停止
            locationManager.monitoredRegions.forEach { region in
                locationManager.stopMonitoring(for: region)
            }

            // デリゲートを解放
            locationManager.delegate = nil
        }

        // 位置情報マネージャーとデリゲートの参照を解放
        locationDelegate = nil
        locationManager = nil

        // 通知オブザーバーを削除
        if let observer = willEnterForegroundObserver {
            NotificationCenter.default.removeObserver(observer)
            willEnterForegroundObserver = nil
        }
    }

    private func checkIfWeekday() {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        if weekday == 4 {  // 4は水曜日
            selectedScheduleType = .wednesday
        } else if weekday == 7 {  // 7は土曜日
            selectedScheduleType = .saturday
        } else {
            selectedScheduleType = .weekday
        }
    }

    // スクロール位置を更新
    private func updateScrollToHour() {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour], from: currentTime)
        // 一度nilに設定してからonChangeイベントを確実にトリガーさせる
        scrollToHour = nil

        // nil値が処理された後に新しい値を設定するためにディレイを使用
        DispatchQueue.main.async {
            self.scrollToHour = components.hour
        }
    }

    // MARK: - UIコンポーネント
    // 時刻表タイプセレクタ（平日/水曜日/土曜日）
    private var scheduleTypeSelector: some View {
        HStack {
            Picker("スケジュールタイプ", selection: $selectedScheduleType) {
                Text("平日（水曜日を除く）").tag(BusSchedule.ScheduleType.weekday)
                Text("水曜日").tag(BusSchedule.ScheduleType.wednesday)
                Text("土曜日").tag(BusSchedule.ScheduleType.saturday)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .onChange(of: selectedScheduleType) { oldValue, newValue in
                selectedTimeEntry = nil
                updateScrollToHour()
            }
        }
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
    }

    // 路線セレクタ
    private var routeTypeSelector: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    // 出発駅グループ
                    routeButton(
                        title: NSLocalizedString("聖蹟桜ヶ丘駅発", comment: ""), type: .fromSeisekiToSchool
                    )
                    .id("fromSeisekiToSchool")
                    routeButton(
                        title: NSLocalizedString("永山駅発", comment: ""), type: .fromNagayamaToSchool
                    )
                    .id("fromNagayamaToSchool")

                    // 分割線
                    Divider()
                        .frame(height: 20)
                        .background(Color.gray.opacity(0.3))

                    // 目的駅グループ
                    routeButton(
                        title: NSLocalizedString("聖蹟桜ヶ丘駅行", comment: ""), type: .fromSchoolToSeiseki
                    )
                    .id("fromSchoolToSeiseki")
                    routeButton(
                        title: NSLocalizedString("永山駅行", comment: ""), type: .fromSchoolToNagayama
                    )
                    .id("fromSchoolToNagayama")
                }
                .padding(.horizontal)
                .padding(.vertical, 5)
            }
            .onChange(of: selectedRouteType) { oldValue, newValue in
                withAnimation {
                    scrollProxy.scrollTo(newValue.rawValue, anchor: .center)
                }
            }
        }
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
    }

    // 路線ボタン
    private func routeButton(title: String, type: BusSchedule.RouteType) -> some View {
        Button(action: {
            selectedRouteType = type
            selectedTimeEntry = nil
            updateScrollToHour()
        }) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            selectedRouteType == type
                                ? Color.blue.opacity(0.9)
                                : Color.gray.opacity(colorScheme == .dark ? 0.25 : 0.15)
                        )
                        .shadow(
                            color: selectedRouteType == type
                                ? Color.blue.opacity(0.3) : Color.clear,
                            radius: 3, x: 0, y: 2)
                )
                .foregroundColor(selectedRouteType == type ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: selectedRouteType)
    }

    // 時刻表コンテンツ
    private var scheduleContent: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .center, spacing: 16) {
                    // 時刻表
                    scheduleTableView
                        .onChange(of: scrollToHour) { oldValue, newValue in
                            if let hour = newValue {
                                withAnimation {
                                    scrollProxy.scrollTo(
                                        "hour_\(hour)", anchor: UnitPoint(x: 0, y: 0.1))
                                }
                            }
                        }

                    // 特別便の説明
                    specialNotesView
                }
                .padding()
            }
            .background(Color(UIColor.systemBackground))
            .onAppear {
                // ビュー表示時に現在時刻にスクロール
                if let hour = scrollToHour {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation {
                            scrollProxy.scrollTo("hour_\(hour)", anchor: UnitPoint(x: 0, y: 0.1))
                        }
                    }
                }
            }
        }
    }

    // 現在時刻表示
    private var currentTimeView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("現在時刻")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(timeFormatter.string(from: currentTime))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
            }

            Spacer()

            // 選択した時間が現在時刻と同じかチェック
            if let selectedTime = selectedTimeEntry,
                isTimeEqual(selectedTime, to: currentTime)
            {
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
            }
            // 次のバス情報
            else if let nextBus = selectedTimeEntry ?? getNextBus() {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(selectedTimeEntry != nil ? "選択したバスまで" : "次のバスまで")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .transition(.opacity)

                    HStack(spacing: 4) {
                        Text(getCountdownText(to: nextBus))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(selectedTimeEntry != nil ? .orange : .green)
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

                    if selectedTimeEntry != nil {
                        HStack {
                            Text("バス時刻")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("\(String(format: "%02d:%02d", nextBus.hour, nextBus.minute))")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.orange)
                        }
                        .opacity(cardInfoAppeared ? 1 : 0)
                        .offset(y: cardInfoAppeared ? 0 : 5)
                        .transition(.opacity)
                    }
                }
            } else {
                Text("本日の運行は終了しました")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
        // タップイベントを親ビューに伝播させない
        .contentShape(Rectangle())
        .onTapGesture {}
        .animation(.easeInOut(duration: 0.2), value: selectedTimeEntry)
    }

    // 時刻表ビュー
    private var scheduleTableView: some View {
        VStack(spacing: 0) {
            // ヘッダー
            tableHeader

            Divider()
                .background(Color.gray.opacity(0.3))

            // ピンメッセージまたは水曜日特別メッセージ
            if let pinMessage = busSchedule?.pin {
                pinMessageView(pinMessage)
            } else if selectedScheduleType == .wednesday {
                wednesdaySpecialMessage
            }

            // 時刻表コンテンツ
            ForEach(getFilteredSchedule().hourSchedules, id: \.hour) { hourSchedule in
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
        // タップイベントを親ビューに伝播させない
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTimeEntry = nil
                cardInfoAppeared = false
            }
        }
    }

    // テーブルヘッダー
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

    // 水曜日特別メッセージ
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

    // ピンメッセージ
    private func pinMessageView(_ pinMessage: BusSchedule.PinMessage) -> some View {
        Button(action: {
            if let url = URL(string: pinMessage.url) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack {
                Image(systemName: "pin.fill")
                    .foregroundColor(.orange)

                Text(pinMessage.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // 時間ごとの行
    private func hourScheduleRow(_ hourSchedule: BusSchedule.HourSchedule) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // 時間
                Text("\(hourSchedule.hour)")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(width: 70, alignment: .center)
                    .padding(.vertical, 12)

                Divider()
                    .frame(width: 1)
                    .background(Color.gray.opacity(0.3))

                // 分リスト - 配置改善
                VStack(alignment: .center) {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.fixed(50), spacing: 8), count: 5),
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
                // 空白部分をタップした場合も選択を解除
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedTimeEntry = nil
                }
            }

            Divider()
                .background(Color.gray.opacity(0.3))
        }
        .id("hour_\(hourSchedule.hour)")
        .background(
            isCurrentHour(hourSchedule.hour)
                ? Color.green.opacity(colorScheme == .dark ? 0.2 : 0.1)
                : (hourSchedule.hour % 2 == 0
                    ? Color(UIColor.systemBackground)
                    : Color.gray.opacity(colorScheme == .dark ? 0.1 : 0.03))
        )
    }

    // 個別の時間エントリービュー
    private func timeEntryView(_ time: BusSchedule.TimeEntry) -> some View {
        ZStack(alignment: .topTrailing) {
            // 時刻数字
            Text("\(String(format: "%02d", time.minute))")
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(
                    isCurrentOrNextBus(time) || selectedTimeEntry == time ? .white : .primary
                )
                .frame(width: 36, height: 36, alignment: .center)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            selectedTimeEntry == time
                                ? Color.orange.opacity(0.9)
                                : (isCurrentOrNextBus(time) ? Color.blue.opacity(0.9) : Color.clear)
                        )
                )

            // 特別マーク
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
            handleTimeEntryTap(time)
        }
    }

    // 時間エントリータップ処理
    private func handleTimeEntryTap(_ time: BusSchedule.TimeEntry) {
        // 同じ時刻を再度タップした場合は選択を解除
        if selectedTimeEntry == time {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTimeEntry = nil
                cardInfoAppeared = false
            }
        } else {
            // それ以外の場合は選択状態にする
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTimeEntry = time
                cardInfoAppeared = false

                // 少し遅延させてから表示アニメーションを開始
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        cardInfoAppeared = true
                    }
                }
            }
        }
    }

    // 特別便の説明ビュー
    private var specialNotesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("備考")
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(busSchedule?.specialNotes ?? [], id: \.symbol) { note in
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

            // 水曜日の場合は特別メッセージを表示しない
            if selectedScheduleType != .wednesday {
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
        // タップイベントを親ビューに伝播させない
        .contentShape(Rectangle())
        .onTapGesture {}
    }

    // 水曜日警告メッセージ
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

    // MARK: - ヘルパーメソッド
    // 日付フォーマッター
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    // フィルタリングされた時刻表を取得
    private func getFilteredSchedule() -> BusSchedule.DaySchedule {
        guard let busSchedule = busSchedule else {
            return BusSchedule.DaySchedule(
                routeType: .fromSeisekiToSchool, scheduleType: selectedScheduleType,
                hourSchedules: [])
        }

        let schedules: [BusSchedule.DaySchedule]

        switch selectedScheduleType {
        case .weekday:
            schedules = busSchedule.weekdaySchedules
        case .saturday:
            schedules = busSchedule.saturdaySchedules
        case .wednesday:
            schedules = busSchedule.wednesdaySchedules
        }

        // 一致する路線時刻表を検索
        if let schedule = schedules.first(where: { $0.routeType == selectedRouteType }) {
            return schedule
        }

        // 一致する路線が見つからない場合、最初の時刻表を返す（クラッシュ防止）
        return schedules.first
            ?? BusSchedule.DaySchedule(
                routeType: .fromSeisekiToSchool,
                scheduleType: selectedScheduleType,
                hourSchedules: []
            )
    }

    // 現在の時間かどうかを判断
    private func isCurrentHour(_ hour: Int) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour], from: currentTime)
        return components.hour == hour
    }

    // 時間が等しいかどうかを判断（時と分）
    private func isTimeEqual(_ timeEntry: BusSchedule.TimeEntry, to date: Date) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)

        guard let hour = components.hour, let minute = components.minute else {
            return false
        }

        return timeEntry.hour == hour && timeEntry.minute == minute
    }

    // 現在または次のバスかどうかを判断
    private func isCurrentOrNextBus(_ time: BusSchedule.TimeEntry) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: currentTime)

        guard let currentHour = components.hour, let currentMinute = components.minute else {
            return false
        }

        // 同じ時間で、分が現在以上の場合
        if time.hour == currentHour && time.minute >= currentMinute {
            return true
        }

        // 次の時間の最初のバスの場合
        if time.hour == currentHour + 1 {
            // 現在の時間のすべての便を取得
            let currentHourSchedule = getFilteredSchedule().hourSchedules.first {
                $0.hour == currentHour
            }

            // 現在の時間にそれ以降の便がなく、これが次の時間の最初のバスの場合
            if let currentHourSchedule = currentHourSchedule,
                !currentHourSchedule.times.contains(where: { $0.minute > currentMinute }),
                let nextHourSchedule = getFilteredSchedule().hourSchedules.first(where: {
                    $0.hour == currentHour + 1
                }),
                let firstTimeInNextHour = nextHourSchedule.times.first,
                time.minute == firstTimeInNextHour.minute
            {
                return true
            }
        }

        return false
    }

    // 次のバスを取得
    private func getNextBus() -> BusSchedule.TimeEntry? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: currentTime)

        guard let currentHour = components.hour, let currentMinute = components.minute else {
            return nil
        }

        let schedule = getFilteredSchedule()

        // 現在の時間内の次のバスを検索（分は現在より大きい必要がある）
        if let currentHourSchedule = schedule.hourSchedules.first(where: { $0.hour == currentHour }
        ),
            let nextBus = currentHourSchedule.times.first(where: { $0.minute > currentMinute })
        {
            return nextBus
        }

        // 後続の時間の最初のバスを検索
        if currentHour < 23 {
            for hour in (currentHour + 1)...23 {
                if let hourSchedule = schedule.hourSchedules.first(where: { $0.hour == hour }),
                    let firstBus = hourSchedule.times.first
                {
                    return firstBus
                }
            }
        }

        // 現在が23時以降、または後続のバスが見つからない場合はnilを返す
        return nil
    }

    // カウントダウンテキストを取得（秒単位まで正確に）
    private func getCountdownText(to nextBus: BusSchedule.TimeEntry) -> String {
        let calendar = Calendar.current

        // 次のバスの日付を作成
        var nextBusDateComponents = calendar.dateComponents(
            [.year, .month, .day], from: currentTime)
        nextBusDateComponents.hour = nextBus.hour
        nextBusDateComponents.minute = nextBus.minute
        nextBusDateComponents.second = 0

        guard let nextBusDate = calendar.date(from: nextBusDateComponents) else {
            return ""
        }

        // 現在時刻かどうかをチェック（時と分が同じ）
        let currentComponents = calendar.dateComponents([.hour, .minute], from: currentTime)
        if let currentHour = currentComponents.hour, let currentMinute = currentComponents.minute,
            currentHour == nextBus.hour && currentMinute == nextBus.minute
        {
            return "0分0秒"
        }

        // 次のバスの時間が現在時刻より早い場合、翌日のバスの可能性がある
        if nextBusDate < currentTime {
            // 1日追加
            guard let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: nextBusDate) else {
                return ""
            }

            return formatTimeDifference(from: currentTime, to: tomorrowDate)
        } else {
            // 時間差を計算
            return formatTimeDifference(from: currentTime, to: nextBusDate)
        }
    }

    // 時間差をフォーマット
    private func formatTimeDifference(from: Date, to: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: from, to: to)

        if let hour = components.hour, let minute = components.minute,
            let second = components.second
        {
            if hour > 0 {
                return "\(hour)時間\(minute)分\(second)秒"
            } else {
                return "\(minute)分\(second)秒"
            }
        }

        return ""
    }

    // 選択した時間が経過したかチェック
    private func checkIfSelectedTimePassed() {
        guard let selectedTime = selectedTimeEntry else { return }

        let calendar = Calendar.current
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute], from: currentTime)

        guard let currentHour = components.hour, let currentMinute = components.minute else {
            return
        }

        // 選択した時間が経過した場合（現在時刻が選択した時間以上）
        if (selectedTime.hour < currentHour)
            || (selectedTime.hour == currentHour && selectedTime.minute <= currentMinute)
        {
            // 自動的に選択を解除
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTimeEntry = nil
                cardInfoAppeared = false
            }
        }
    }

    // キャッシュの有効性をチェックし、必要に応じて更新
    private func checkCacheAndRefreshIfNeeded() {
        // すでにデータを読み込み中の場合は何もしない
        guard busSchedule != nil else { return }

        if !busScheduleService.isCacheValid() {
            print("BusScheduleView: キャッシュが無効なため、データを更新します")
            fetchBusScheduleData()
        } else {
            print("BusScheduleView: 有効なキャッシュデータが存在します")
        }
    }

    private func setupTimeUpdater() {
        // バスページに入った時にキャッシュの有効性をチェック（既にデータがある場合）
        checkCacheAndRefreshIfNeeded()
    }

    // 即座に位置情報を更新するメソッド
    private func updateLocationImmediately() {
        // locationManagerがnilの場合は初期化から
        if locationManager == nil || locationDelegate == nil {
            setupLocationManager()
            return
        }

        guard let locationManager = locationManager, let locationDelegate = locationDelegate else {
            print("BusScheduleView: locationManagerまたはlocationDelegateがnilです")
            return
        }

        print("BusScheduleView: 位置情報の即時更新をリクエストします")

        // デリゲートが正しく設定されているか確認
        if locationManager.delegate == nil {
            locationManager.delegate = locationDelegate
        }

        // 現在の認証状態を確認
        let authStatus = locationManager.authorizationStatus

        switch authStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // 既に許可されている場合は、位置情報を更新
            // 継続的な更新を開始（requestLocationの代わりに）
            locationManager.startUpdatingLocation()

            // 現在地が取得できる場合はすぐにチェック
            if let currentLocation = locationManager.location {
                checkIfUserInSchoolArea(currentLocation)
            }
        case .notDetermined:
            // まだ決定されていない場合は許可をリクエスト
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            // 拒否または制限されている場合は何もしない
            print("BusScheduleView: 位置情報の使用が許可されていません")
        @unknown default:
            break
        }
    }

    // MARK: - URLスキーム処理
    private func setupBusParametersObserver() {
        busParametersObserver = NotificationCenter.default.addObserver(
            forName: .busParametersFromURL,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo {
                // routeパラメータを処理
                if let routeString = userInfo["route"] as? String {
                    switch routeString {
                    case "fromSeisekiToSchool":
                        self.selectedRouteType = .fromSeisekiToSchool
                    case "fromNagayamaToSchool":
                        self.selectedRouteType = .fromNagayamaToSchool
                    case "fromSchoolToSeiseki":
                        self.selectedRouteType = .fromSchoolToSeiseki
                    case "fromSchoolToNagayama":
                        self.selectedRouteType = .fromSchoolToNagayama
                    default:
                        break
                    }
                }

                // scheduleパラメータを処理
                if let scheduleString = userInfo["schedule"] as? String {
                    switch scheduleString {
                    case "weekday":
                        self.selectedScheduleType = .weekday
                    case "saturday":
                        self.selectedScheduleType = .saturday
                    case "wednesday":
                        self.selectedScheduleType = .wednesday
                    default:
                        break
                    }
                }
            }
        }
    }

    // deinitでオブザーバーを解除
    private func removeObservers() {
        if let observer = willEnterForegroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        if let observer = busParametersObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - 位置情報デリゲート
// 位置情報マネージャーのデリゲートを処理するクラス
class LocationManagerDelegate: NSObject, CLLocationManagerDelegate {
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

    // 位置が更新されたときに呼ばれる
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            didUpdateLocation(location)
        }
    }

    // 領域に入ったときに呼ばれる
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if region.identifier == "SchoolArea" {
            didEnterRegion()
        }
    }

    // 領域から出たときに呼ばれる
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if region.identifier == "SchoolArea" {
            didExitRegion()
        }
    }

    // 位置情報の利用許可状態が変わったときに呼ばれる
    func locationManager(
        _ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus
    ) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            // 位置情報の使用が許可された場合
            manager.startUpdatingLocation()
            // 学校エリアにすでにいるかどうかをチェック
            if let location = manager.location {
                didUpdateLocation(location)
            }
        case .denied, .restricted:
            // 位置情報の使用が拒否または制限された場合
            print("位置情報の使用が拒否または制限されました")
        case .notDetermined:
            // まだ決定されていない場合
            manager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }

    // エラーが発生した場合に呼ばれる
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let error = error as? CLError {
            switch error.code {
            case .denied:
                // 位置情報の使用が拒否された場合
                print("位置情報の使用が拒否されました")
            case .network:
                // ネットワークエラーの場合
                print("位置情報の取得中にネットワークエラーが発生しました")
            case .locationUnknown:
                // 位置が不明な場合
                print("位置を特定できません")
            default:
                // その他のエラー
                print("位置情報の取得に失敗しました: \(error.localizedDescription)")
            }
        } else {
            // CLError以外のエラー
            print("位置情報の取得に失敗しました: \(error.localizedDescription)")
        }

        // エラーが発生しても、継続的に位置情報の更新を試みる
        // 重要：requestLocationはエラー後に再度位置情報を取得しないため
        // 継続的な監視が必要な場合はstartUpdatingLocation()を呼び出す
        // manager.startUpdatingLocation()
    }
}

#Preview {
    BusScheduleView()
}
