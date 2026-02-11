import CoreLocation
import Foundation
import SwiftUI

/// バス時刻表ViewModel
@MainActor
final class BusScheduleViewModel: ObservableObject {

    // MARK: - 公開プロパティ

    @Published var selectedScheduleType: BusSchedule.ScheduleType = .weekday
    @Published var selectedRouteType: BusSchedule.RouteType = .fromSeisekiToSchool
    @Published var currentTime = Date()
    @Published var scrollToHour: Int? = nil
    @Published var selectedTimeEntry: BusSchedule.TimeEntry? = nil
    @Published var cardInfoAppeared: Bool = false
    @Published var busSchedule: BusSchedule? = nil
    @Published var errorMessage: String? = nil
    @Published var userInSchoolArea: Bool = false

    // MARK: - プライベートプロパティ

    private var timer: Timer? = nil
    private var secondsTimer: Timer? = nil
    private let busScheduleService = BusScheduleService.shared

    // 位置情報関連
    private var locationManager: CLLocationManager?
    private var locationDelegate: LocationManagerDelegate?
    private let schoolLocation = CLLocationCoordinate2D(
        latitude: 35.630604, longitude: 139.464382)
    private let geofenceRadius: CLLocationDistance = 400

    // 通知オブザーバー
    private var willEnterForegroundObserver: NSObjectProtocol? = nil
    private var busParametersObserver: NSObjectProtocol?

    // MARK: - 日付フォーマッター

    var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    // MARK: - データ取得

    func fetchBusScheduleData() {
        busScheduleService.fetchBusScheduleData { [weak self] schedule, error in
            guard let self = self else { return }
            if error != nil {
                self.errorMessage = NSLocalizedString(
                    "時刻表の読み込みに失敗しました。\nネットワーク接続を確認してください。", comment: "")
            } else {
                self.busSchedule = schedule
            }
        }
    }

    // MARK: - セットアップとクリーンアップ

    func setupOnAppear() {
        fetchBusScheduleData()
        checkCacheAndRefreshIfNeeded()
        setupLocationManager()
        setupTimers()
        checkIfWeekday()
        updateScrollToHour()
        setupBusParametersObserver()

        willEnterForegroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.currentTime = Date()
                self?.fetchBusScheduleData()
            }
        }
    }

    func cleanupOnDisappear() {
        cleanupTimers()
        removeObservers()
    }

    private func setupTimers() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.currentTime = Date()
                self?.updateScrollToHour()
            }
        }

        secondsTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.currentTime = Date()
                self?.checkIfSelectedTimePassed()
            }
        }
    }

    private func cleanupTimers() {
        timer?.invalidate()
        timer = nil
        secondsTimer?.invalidate()
        secondsTimer = nil

        if let locationManager = locationManager {
            locationManager.stopUpdatingLocation()
            locationManager.monitoredRegions.forEach { region in
                locationManager.stopMonitoring(for: region)
            }
            locationManager.delegate = nil
        }
        locationDelegate = nil
        locationManager = nil

        if let observer = willEnterForegroundObserver {
            NotificationCenter.default.removeObserver(observer)
            willEnterForegroundObserver = nil
        }
    }

    private func removeObservers() {
        if let observer = willEnterForegroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = busParametersObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - スケジュールロジック

    func checkIfWeekday() {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        if weekday == 4 {
            selectedScheduleType = .wednesday
        } else if weekday == 7 {
            selectedScheduleType = .saturday
        } else {
            selectedScheduleType = .weekday
        }
    }

    func updateScrollToHour() {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour], from: currentTime)
        scrollToHour = nil
        DispatchQueue.main.async {
            self.scrollToHour = components.hour
        }
    }

    func getFilteredSchedule() -> BusSchedule.DaySchedule {
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

        if let schedule = schedules.first(where: { $0.routeType == selectedRouteType }) {
            return schedule
        }

        return schedules.first
            ?? BusSchedule.DaySchedule(
                routeType: .fromSeisekiToSchool,
                scheduleType: selectedScheduleType,
                hourSchedules: []
            )
    }

    func isCurrentHour(_ hour: Int) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour], from: currentTime)
        return components.hour == hour
    }

    func isTimeEqual(_ timeEntry: BusSchedule.TimeEntry, to date: Date) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else {
            return false
        }
        return timeEntry.hour == hour && timeEntry.minute == minute
    }

    func isCurrentOrNextBus(_ time: BusSchedule.TimeEntry) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: currentTime)
        guard let currentHour = components.hour, let currentMinute = components.minute else {
            return false
        }

        if time.hour == currentHour && time.minute >= currentMinute {
            return true
        }

        if time.hour == currentHour + 1 {
            let currentHourSchedule = getFilteredSchedule().hourSchedules.first {
                $0.hour == currentHour
            }
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

    func getNextBus() -> BusSchedule.TimeEntry? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: currentTime)
        guard let currentHour = components.hour, let currentMinute = components.minute else {
            return nil
        }

        let schedule = getFilteredSchedule()

        if let currentHourSchedule = schedule.hourSchedules.first(where: { $0.hour == currentHour }),
            let nextBus = currentHourSchedule.times.first(where: { $0.minute > currentMinute })
        {
            return nextBus
        }

        if currentHour < 23 {
            for hour in (currentHour + 1)...23 {
                if let hourSchedule = schedule.hourSchedules.first(where: { $0.hour == hour }),
                    let firstBus = hourSchedule.times.first
                {
                    return firstBus
                }
            }
        }

        return nil
    }

    func getCountdownText(to nextBus: BusSchedule.TimeEntry) -> String {
        let calendar = Calendar.current

        var nextBusDateComponents = calendar.dateComponents(
            [.year, .month, .day], from: currentTime)
        nextBusDateComponents.hour = nextBus.hour
        nextBusDateComponents.minute = nextBus.minute
        nextBusDateComponents.second = 0

        guard let nextBusDate = calendar.date(from: nextBusDateComponents) else {
            return ""
        }

        let currentComponents = calendar.dateComponents([.hour, .minute], from: currentTime)
        if let currentHour = currentComponents.hour, let currentMinute = currentComponents.minute,
            currentHour == nextBus.hour && currentMinute == nextBus.minute
        {
            return "0分0秒"
        }

        if nextBusDate < currentTime {
            guard let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: nextBusDate) else {
                return ""
            }
            return formatTimeDifference(from: currentTime, to: tomorrowDate)
        } else {
            return formatTimeDifference(from: currentTime, to: nextBusDate)
        }
    }

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

    private func checkIfSelectedTimePassed() {
        guard let selectedTime = selectedTimeEntry else { return }

        let calendar = Calendar.current
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute], from: currentTime)
        guard let currentHour = components.hour, let currentMinute = components.minute else {
            return
        }

        if (selectedTime.hour < currentHour)
            || (selectedTime.hour == currentHour && selectedTime.minute <= currentMinute)
        {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTimeEntry = nil
                cardInfoAppeared = false
            }
        }
    }

    private func checkCacheAndRefreshIfNeeded() {
        guard busSchedule != nil else { return }
        if !busScheduleService.isCacheValid() {
            fetchBusScheduleData()
        }
    }

    // MARK: - 時間エントリー操作

    func handleTimeEntryTap(_ time: BusSchedule.TimeEntry) {
        if selectedTimeEntry == time {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTimeEntry = nil
                cardInfoAppeared = false
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTimeEntry = time
                cardInfoAppeared = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self.cardInfoAppeared = true
                    }
                }
            }
        }
    }

    func clearSelection() {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedTimeEntry = nil
            cardInfoAppeared = false
        }
    }

    func onScheduleTypeChanged() {
        selectedTimeEntry = nil
        updateScrollToHour()
    }

    func onRouteTypeChanged() {
        selectedTimeEntry = nil
        updateScrollToHour()
    }

    // MARK: - 位置情報関連

    func setupLocationManager() {
        if locationManager != nil {
            locationManager?.delegate = nil
            locationManager = nil
            locationDelegate = nil
        }

        locationManager = CLLocationManager()

        locationDelegate = LocationManagerDelegate(
            didUpdateLocation: { [weak self] location in
                Task { @MainActor in
                    self?.checkIfUserInSchoolArea(location)
                }
            },
            didEnterRegion: { [weak self] in
                Task { @MainActor in
                    self?.userInSchoolArea = true
                    self?.updateRouteBasedOnLocation()
                }
            },
            didExitRegion: { [weak self] in
                Task { @MainActor in
                    self?.userInSchoolArea = false
                    self?.updateRouteBasedOnLocation()
                }
            }
        )

        guard let locationManager = locationManager, let locationDelegate = locationDelegate else {
            return
        }

        locationManager.delegate = locationDelegate
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        setupGeofence()
        locationManager.startUpdatingLocation()
    }

    private func setupGeofence() {
        guard let locationManager = locationManager else { return }

        locationManager.monitoredRegions.forEach { region in
            if region is CLCircularRegion {
                locationManager.stopMonitoring(for: region)
            }
        }

        let schoolRegion = CLCircularRegion(
            center: schoolLocation,
            radius: geofenceRadius,
            identifier: "SchoolArea"
        )
        schoolRegion.notifyOnEntry = true
        schoolRegion.notifyOnExit = true
        locationManager.startMonitoring(for: schoolRegion)
    }

    private func checkIfUserInSchoolArea(_ location: CLLocation) {
        let schoolRegionCenter = CLLocation(
            latitude: schoolLocation.latitude, longitude: schoolLocation.longitude)
        let distance = location.distance(from: schoolRegionCenter)
        let isInSchoolArea = distance <= geofenceRadius

        if isInSchoolArea != userInSchoolArea {
            userInSchoolArea = isInSchoolArea
            updateRouteBasedOnLocation()
        }
    }

    private func updateRouteBasedOnLocation() {
        if userInSchoolArea {
            let isAlreadySchoolDeparture =
                selectedRouteType == .fromSchoolToSeiseki
                || selectedRouteType == .fromSchoolToNagayama
            if !isAlreadySchoolDeparture {
                withAnimation {
                    selectedRouteType = .fromSchoolToNagayama
                    updateScrollToHour()
                }
            }
        } else {
            let isAlreadyStationDeparture =
                selectedRouteType == .fromSeisekiToSchool
                || selectedRouteType == .fromNagayamaToSchool
            if !isAlreadyStationDeparture {
                withAnimation {
                    selectedRouteType = .fromSeisekiToSchool
                    updateScrollToHour()
                }
            }
        }
    }

    // MARK: - URLスキーム処理

    private func setupBusParametersObserver() {
        busParametersObserver = NotificationCenter.default.addObserver(
            forName: .busParametersFromURL,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self = self else { return }
                if let userInfo = notification.userInfo {
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
    }
}
