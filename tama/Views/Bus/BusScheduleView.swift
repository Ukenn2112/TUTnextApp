//
//  BusScheduleView.swift
//  TUTnext
//
//  Glassmorphism Bus Schedule View
//

import SwiftUI
import CoreLocation

struct BusScheduleView: View {
    @State private var selectedScheduleType: BusSchedule.ScheduleType = .weekday
    @State private var selectedRouteType: BusSchedule.RouteType = .fromSeisekiToSchool
    @State private var currentTime = Date()
    @State private var timer: Timer? = nil
    @State private var secondsTimer: Timer? = nil
    @State private var scrollToHour: Int? = nil
    @State private var selectedTimeEntry: BusSchedule.TimeEntry? = nil
    @State private var cardInfoAppeared = false
    @State private var busSchedule: BusSchedule? = nil
    @State private var errorMessage: String? = nil
    
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var ratingService: RatingService
    
    @State private var willEnterForegroundObserver: NSObjectProtocol? = nil
    @State private var busParametersObserver: NSObjectProtocol? = nil
    
    @State private var locationManager: CLLocationManager?
    @State private var locationDelegate: LocationManagerDelegate?
    @State private var userInSchoolArea = false
    
    private let schoolLocation = CLLocationCoordinate2D(latitude: 35.630604, longitude: 139.464382)
    private let geofenceRadius: CLLocationDistance = 400
    
    private let busScheduleService = BusScheduleService.shared
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
    
    var body: some View {
        ZStack {
            ThemeColors.Gradient.fullGradient(for: themeManager.currentTheme)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if let errorMessage = errorMessage {
                    ErrorView(message: errorMessage) {
                        self.errorMessage = nil
                        fetchBusScheduleData()
                    }
                } else if let busSchedule = busSchedule {
                    busScheduleContent(busSchedule)
                } else {
                    LoadingView(message: "時刻表を読み込み中...")
                }
            }
        }
        .onAppear {
            setupTimers()
            setupLocationManager()
            fetchBusScheduleData()
            setupBusParametersObserver()
        }
        .onDisappear {
            cleanupTimers()
            removeObservers()
        }
    }
    
    // MARK: - Content
    private func busScheduleContent(_ busSchedule: BusSchedule) -> some View {
        VStack(spacing: 0) {
            // Temporary Messages
            if let messages = busSchedule.temporaryMessages, !messages.isEmpty {
                temporaryMessagesView(messages)
            }
            
            // Schedule Type Selector
            scheduleTypeSelector
            
            // Route Type Selector
            routeTypeSelector
            
            // Schedule Content
            ZStack(alignment: .top) {
                let topPadding: CGFloat = selectedTimeEntry == nil ? 90 : 110
                scheduleContent(busSchedule)
                    .padding(.top, topPadding)
                
                // Floating Current Time Card
                currentTimeCard
                    .padding(.horizontal)
                    .padding(.top, 10)
            }
        }
        .background(Color.clear)
        .onTapGesture {
            selectedTimeEntry = nil
        }
    }
    
    // MARK: - Temporary Messages
    private func temporaryMessagesView(_ messages: [BusSchedule.TemporaryMessage]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(messages, id: \.title) { message in
                    temporaryMessageCard(message)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .padding(.top, 4)
        }
    }
    
    private func temporaryMessageCard(_ message: BusSchedule.TemporaryMessage) -> some View {
        Group {
            if let url = URL(string: message.url) {
                Link(destination: url) {
                    messageCardContent(message)
                }
            } else {
                messageCardContent(message)
            }
        }
    }
    
    private func messageCardContent(_ message: BusSchedule.TemporaryMessage) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 14))
            
            Text(message.title)
                .typography(.bodySmall)
                .lineLimit(2)
            
            if URL(string: message.url) != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(width: 260)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ThemeColors.Glass.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Schedule Type Selector
    private var scheduleTypeSelector: some View {
        Picker("スケジュールタイプ", selection: $selectedScheduleType) {
            Text("平日").tag(BusSchedule.ScheduleType.weekday)
            Text("水曜日").tag(BusSchedule.ScheduleType.wednesday)
            Text("土曜日").tag(BusSchedule.ScheduleType.saturday)
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
        .padding(.vertical, 12)
        .onChange(of: selectedScheduleType) { _, _ in
            selectedTimeEntry = nil
            updateScrollToHour()
        }
    }
    
    // MARK: - Route Type Selector
    private var routeTypeSelector: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    routeButton(title: "聖蹟桜ヶ丘駅発", type: .fromSeisekiToSchool)
                    routeButton(title: "永山駅発", type: .fromNagayamaToSchool)
                    
                    Divider()
                        .frame(height: 20)
                        .background(Color.gray.opacity(0.3))
                    
                    routeButton(title: "聖蹟桜ヶ丘駅行", type: .fromSchoolToSeiseki)
                    routeButton(title: "永山駅行", type: .fromSchoolToNagayama)
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
    }
    
    private func routeButton(title: String, type: BusSchedule.RouteType) -> some View {
        Button {
            selectedRouteType = type
            selectedTimeEntry = nil
            updateScrollToHour()
        } label: {
            Text(title)
                .typography(.labelMedium)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(selectedRouteType == type ? Color.blue.opacity(0.9) : ThemeColors.Glass.light)
                        .shadow(color: selectedRouteType == type ? Color.blue.opacity(0.3) : .clear, radius: 3, y: 2)
                )
                .foregroundColor(selectedRouteType == type ? .white : .primary)
        }
        .buttonStyle(.plain)
        .id(type.rawValue)
    }
    
    // MARK: - Schedule Content
    private func scheduleContent(_ busSchedule: BusSchedule) -> some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .center, spacing: 16) {
                    scheduleTableView(busSchedule)
                        .onChange(of: scrollToHour) { _, newValue in
                            if let hour = newValue {
                                withAnimation {
                                    scrollProxy.scrollTo("hour_\(hour)", anchor: UnitPoint(x: 0, y: 0.1))
                                }
                            }
                        }
                    
                    specialNotesView(busSchedule)
                }
                .padding()
            }
            .onAppear {
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
    
    // MARK: - Schedule Table
    private func scheduleTableView(_ busSchedule: BusSchedule) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                StyledText("時間", style: .caption)
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .center)
                    .padding(.vertical, 12)
                
                Divider()
                    .frame(width: 1)
                    .background(Color.gray.opacity(0.3))
                
                StyledText("発車時刻", style: .caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            }
            .background(Color.gray.opacity(0.1))
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Wednesday Special Message
            if selectedScheduleType == .wednesday {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    StyledText("水曜日は特別ダイヤで運行しています", style: .bodySmall)
                    Spacer()
                }
                .padding()
                .background(Color.blue.opacity(0.1))
            }
            
            // Hour Schedules
            ForEach(getFilteredSchedule(busSchedule).hourSchedules, id: \.hour) { hourSchedule in
                if !hourSchedule.times.isEmpty {
                    hourScheduleRow(hourSchedule)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .background(ThemeColors.Glass.medium)
    }
    
    private func hourScheduleRow(_ hourSchedule: BusSchedule.HourSchedule) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                StyledText("\(hourSchedule.hour)", style: .titleMedium)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .frame(width: 70, alignment: .center)
                
                Divider()
                    .frame(width: 1)
                    .background(Color.gray.opacity(0.3))
                
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
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedTimeEntry = nil
                }
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
        }
        .id("hour_\(hourSchedule.hour)")
        .background(isCurrentHour(hourSchedule.hour) ? Color.green.opacity(0.1) : Color.clear)
    }
    
    private func timeEntryView(_ time: BusSchedule.TimeEntry) -> some View {
        ZStack(alignment: .topTrailing) {
            StyledText(String(format: "%02d", time.minute), style: .bodyMedium)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(isCurrentOrNextBus(time) || selectedTimeEntry == time ? .white : .primary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selectedTimeEntry == time ? Color.orange.opacity(0.9) : (isCurrentOrNextBus(time) ? Color.blue.opacity(0.9) : Color.clear))
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
            handleTimeEntryTap(time)
        }
    }
    
    // MARK: - Current Time Card
    private var currentTimeCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                StyledText("現在時刻", style: .caption)
                    .foregroundColor(.secondary)
                StyledText(timeFormatter.string(from: currentTime), style: .titleLarge)
            }
            
            Spacer()
            
            if let selectedTime = selectedTimeEntry, isTimeEqual(selectedTime, to: currentTime) {
                VStack(alignment: .trailing, spacing: 4) {
                    StyledText("バスの出発時刻です", style: .caption)
                        .foregroundColor(.orange)
                    StyledText("0分0秒", style: .titleLarge)
                        .foregroundColor(.orange)
                }
            } else if let nextBus = selectedTimeEntry ?? getNextBus() {
                VStack(alignment: .trailing, spacing: 4) {
                    StyledText(selectedTimeEntry != nil ? "選択したバスまで" : "次のバスまで", style: .caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        StyledText(getCountdownText(to: nextBus), style: .titleLarge)
                            .foregroundColor(selectedTimeEntry != nil ? .orange : .green)
                        
                        if let note = nextBus.specialNote {
                            Text(note)
                                .typography(.captionSmall)
                                .foregroundColor(.red)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    if selectedTimeEntry != nil {
                        StyledText("バス時刻: \(String(format: "%02d:%02d", nextBus.hour, nextBus.minute))", style: .captionSmall)
                            .foregroundColor(.orange)
                    }
                }
            } else {
                StyledText("本日の運行は終了", style: .caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(ThemeColors.Glass.medium)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.2), value: selectedTimeEntry)
    }
    
    // MARK: - Special Notes
    private func specialNotesView(_ busSchedule: BusSchedule) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            StyledText("備考", style: .titleSmall)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ForEach(busSchedule.specialNotes ?? [], id: \.symbol) { note in
                HStack(alignment: .top, spacing: 8) {
                    Text(note.symbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(10)
                    
                    StyledText(note.description, style: .bodySmall)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            if selectedScheduleType != .wednesday {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    StyledText("水曜日は特別ダイヤです", style: .bodySmall)
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(ThemeColors.Glass.medium)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Helpers
    private func fetchBusScheduleData() {
        busScheduleService.fetchBusScheduleData { schedule, error in
            if let error = error {
                self.errorMessage = "時刻表の読み込みに失敗しました。"
            } else {
                self.busSchedule = schedule
            }
        }
    }
    
    private func getFilteredSchedule(_ busSchedule: BusSchedule) -> BusSchedule.DaySchedule {
        let schedules: [BusSchedule.DaySchedule]
        
        switch selectedScheduleType {
        case .weekday: schedules = busSchedule.weekdaySchedules
        case .saturday: schedules = busSchedule.saturdaySchedules
        case .wednesday: schedules = busSchedule.wednesdaySchedules
        }
        
        return schedules.first { $0.routeType == selectedRouteType }
            ?? schedules.first
            ?? BusSchedule.DaySchedule(routeType: selectedRouteType, scheduleType: selectedScheduleType, hourSchedules: [])
    }
    
    private func setupTimers() {
        checkIfWeekday()
        updateScrollToHour()
        
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            currentTime = Date()
            updateScrollToHour()
        }
        
        secondsTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            currentTime = Date()
            checkIfSelectedTimePassed()
        }
    }
    
    private func cleanupTimers() {
        timer?.invalidate()
        timer = nil
        secondsTimer?.invalidate()
        secondsTimer = nil
        
        if let locationManager = locationManager {
            locationManager.stopUpdatingLocation()
            locationManager.monitoredRegions.forEach { locationManager.stopMonitoring(for: $0) }
            locationManager.delegate = nil
        }
        
        locationDelegate = nil
        locationManager = nil
    }
    
    private func checkIfWeekday() {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        if weekday == 4 { selectedScheduleType = .wednesday }
        else if weekday == 7 { selectedScheduleType = .saturday }
        else { selectedScheduleType = .weekday }
    }
    
    private func updateScrollToHour() {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour], from: currentTime)
        scrollToHour = nil
        DispatchQueue.main.async {
            self.scrollToHour = components.hour
        }
    }
    
    private func isCurrentHour(_ hour: Int) -> Bool {
        let calendar = Calendar.current
        return calendar.component(.hour, from: currentTime) == hour
    }
    
    private func isCurrentOrNextBus(_ time: BusSchedule.TimeEntry) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: currentTime)
        guard let currentHour = components.hour, let currentMinute = components.minute else { return false }
        
        if time.hour == currentHour && time.minute >= currentMinute { return true }
        
        if time.hour == currentHour + 1 {
            let currentHourSchedule = getFilteredSchedule(busSchedule ?? BusSchedule(weekdaySchedules: [], saturdaySchedules: [], wednesdaySchedules: [], specialNotes: [], temporaryMessages: [], pinMessage: nil)).hourSchedules.first { $0.hour == currentHour }
            if currentHourSchedule?.times.contains(where: { $0.minute > currentMinute }) == false {
                if let nextHourSchedule = getFilteredSchedule(busSchedule ?? BusSchedule(weekdaySchedules: [], saturdaySchedules: [], wednesdaySchedules: [], specialNotes: [], temporaryMessages: [], pinMessage: nil)).hourSchedules.first(where: { $0.hour == currentHour + 1 }),
                   let firstTime = nextHourSchedule.times.first,
                   time.minute == firstTime.minute {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func getNextBus() -> BusSchedule.TimeEntry? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: currentTime)
        guard let currentHour = components.hour, let currentMinute = components.minute else { return nil }
        
        let schedule = getFilteredSchedule(busSchedule ?? BusSchedule(weekdaySchedules: [], saturdaySchedules: [], wednesdaySchedules: [], specialNotes: [], temporaryMessages: [], pinMessage: nil))
        
        if let currentHourSchedule = schedule.hourSchedules.first(where: { $0.hour == currentHour }),
           let nextBus = currentHourSchedule.times.first(where: { $0.minute > currentMinute }) {
            return nextBus
        }
        
        if currentHour < 23 {
            for hour in (currentHour + 1)...23 {
                if let hourSchedule = schedule.hourSchedules.first(where: { $0.hour == hour }),
                   let firstBus = hourSchedule.times.first {
                    return firstBus
                }
            }
        }
        
        return nil
    }
    
    private func isTimeEqual(_ timeEntry: BusSchedule.TimeEntry, to date: Date) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else { return false }
        return timeEntry.hour == hour && timeEntry.minute == minute
    }
    
    private func getCountdownText(to nextBus: BusSchedule.TimeEntry) -> String {
        let calendar = Calendar.current
        var nextBusComponents = calendar.dateComponents([.year, .month, .day], from: currentTime)
        nextBusComponents.hour = nextBus.hour
        nextBusComponents.minute = nextBus.minute
        nextBusComponents.second = 0
        
        guard let nextBusDate = calendar.date(from: nextBusComponents) else { return "" }
        
        let currentComponents = calendar.dateComponents([.hour, .minute], from: currentTime)
        if let currentHour = currentComponents.hour, let currentMinute = currentComponents.minute,
           currentHour == nextBus.hour && currentMinute == nextBus.minute {
            return "0分0秒"
        }
        
        let targetDate = nextBusDate < currentTime ? calendar.date(byAdding: .day, value: 1, to: nextBusDate)! : nextBusDate
        let components = calendar.dateComponents([.hour, .minute, .second], from: currentTime, to: targetDate)
        
        if let hour = components.hour, let minute = components.minute, let second = components.second {
            if hour > 0 { return "\(hour)時間\(minute)分\(second)秒" }
            else { return "\(minute)分\(second)秒" }
        }
        
        return ""
    }
    
    private func handleTimeEntryTap(_ time: BusSchedule.TimeEntry) {
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
                        cardInfoAppeared = true
                    }
                }
            }
        }
    }
    
    private func checkIfSelectedTimePassed() {
        guard let selectedTime = selectedTimeEntry else { return }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: currentTime)
        guard let currentHour = components.hour, let currentMinute = components.minute else { return }
        
        if selectedTime.hour < currentHour || (selectedTime.hour == currentHour && selectedTime.minute <= currentMinute) {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTimeEntry = nil
                cardInfoAppeared = false
            }
        }
    }
    
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationDelegate = LocationManagerDelegate(
            didUpdateLocation: { [self] location in
                checkIfUserInSchoolArea(location)
            },
            didEnterRegion: { [self] in
                userInSchoolArea = true
                updateRouteBasedOnLocation()
            },
            didExitRegion: { [self] in
                userInSchoolArea = false
                updateRouteBasedOnLocation()
            }
        )
        
        locationManager?.delegate = locationDelegate
        locationManager?.requestWhenInUseAuthorization()
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        
        setupGeofence()
        locationManager?.startUpdatingLocation()
    }
    
    private func setupGeofence() {
        guard let locationManager = locationManager else { return }
        
        locationManager.monitoredRegions.forEach { region in
            if region is CLCircularRegion {
                locationManager.stopMonitoring(for: region)
            }
        }
        
        let schoolRegion = CLCircularRegion(center: schoolLocation, radius: geofenceRadius, identifier: "SchoolArea")
        schoolRegion.notifyOnEntry = true
        schoolRegion.notifyOnExit = true
        locationManager.startMonitoring(for: schoolRegion)
    }
    
    private func checkIfUserInSchoolArea(_ location: CLLocation) {
        let schoolLocationCL = CLLocation(latitude: schoolLocation.latitude, longitude: schoolLocation.longitude)
        let distance = location.distance(from: schoolLocationCL)
        let isInSchoolArea = distance <= geofenceRadius
        
        if isInSchoolArea != userInSchoolArea {
            userInSchoolArea = isInSchoolArea
            updateRouteBasedOnLocation()
        }
    }
    
    private func updateRouteBasedOnLocation() {
        if userInSchoolArea {
            let isSchoolDeparture = selectedRouteType == .fromSchoolToSeiseki || selectedRouteType == .fromSchoolToNagayama
            if !isSchoolDeparture {
                withAnimation {
                    selectedRouteType = .fromSchoolToNagayama
                    updateScrollToHour()
                }
            }
        } else {
            let isStationDeparture = selectedRouteType == .fromSeisekiToSchool || selectedRouteType == .fromNagayamaToSchool
            if !isStationDeparture {
                withAnimation {
                    selectedRouteType = .fromSeisekiToSchool
                    updateScrollToHour()
                }
            }
        }
    }
    
    private func setupBusParametersObserver() {
        busParametersObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("BusParametersFromURL"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo {
                if let routeString = userInfo["route"] as? String {
                    switch routeString {
                    case "fromSeisekiToSchool": self.selectedRouteType = .fromSeisekiToSchool
                    case "fromNagayamaToSchool": self.selectedRouteType = .fromNagayamaToSchool
                    case "fromSchoolToSeiseki": self.selectedRouteType = .fromSchoolToSeiseki
                    case "fromSchoolToNagayama": self.selectedRouteType = .fromSchoolToNagayama
                    default: break
                    }
                }
                
                if let scheduleString = userInfo["schedule"] as? String {
                    switch scheduleString {
                    case "weekday": self.selectedScheduleType = .weekday
                    case "saturday": self.selectedScheduleType = .saturday
                    case "wednesday": self.selectedScheduleType = .wednesday
                    default: break
                    }
                }
            }
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
}

// MARK: - Location Manager Delegate
class LocationManagerDelegate: NSObject, CLLocationManagerDelegate {
    private let didUpdateLocation: (CLLocation) -> Void
    private let didEnterRegion: () -> Void
    private let didExitRegion: () -> Void
    
    init(didUpdateLocation: @escaping (CLLocation) -> Void,
         didEnterRegion: @escaping () -> Void,
         didExitRegion: @escaping () -> Void) {
        self.didUpdateLocation = didUpdateLocation
        self.didEnterRegion = didEnterRegion
        self.didExitRegion = didExitRegion
        super.init()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last { didUpdateLocation(location) }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if region.identifier == "SchoolArea" { didEnterRegion() }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if region.identifier == "SchoolArea" { didExitRegion() }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default: break
        }
    }
}

#Preview {
    BusScheduleView()
        .environmentObject(ThemeManager.shared)
        .environmentObject(RatingService.shared)
}
