import SwiftUI

struct BusScheduleView: View {
    @State private var selectedScheduleType: BusSchedule.ScheduleType = .weekday
    @State private var selectedRouteType: BusSchedule.RouteType = .fromSeisenToNagayama
    @State private var currentTime = Date()
    @State private var timer: Timer? = nil
    @State private var scrollToHour: Int? = nil
    @State private var secondsTimer: Timer? = nil
    @State private var selectedTimeEntry: BusSchedule.TimeEntry? = nil
    @State private var cardInfoAppeared: Bool = false
    
    // 获取校车时刻表数据
    private let busSchedule = BusScheduleService.shared.getBusScheduleData()
    
    var body: some View {
        VStack(spacing: 0) {
            // 时刻表类型选择器（平日/周六）
            scheduleTypeSelector
            
            // 路线选择器
            routeTypeSelector
            
            // 时刻表内容（包含悬浮的时间卡片）
            ZStack(alignment: .top) {
                scheduleContent
                    .padding(.top, 90) // 为悬浮卡片留出空间
                
                // 悬浮的当前时间显示卡片
                currentTimeView
                    .padding(.horizontal)
                    .padding(.top, 10)
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
        .background(Color(.systemGroupedBackground))
        .edgesIgnoringSafeArea(.bottom)
        .onAppear {
            // 启动定时器，每分钟更新当前时间
            timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                currentTime = Date()
                updateScrollToHour()
            }
            
            // 秒単位のタイマーを追加（1秒ごとに更新）
            secondsTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                currentTime = Date()
                // 選択した時間が経過したかチェック
                checkIfSelectedTimePassed()
            }
            
            // 检查当前是否为周三，如果是则自动选择水曜日时刻表
            let calendar = Calendar.current
            let weekday = calendar.component(.weekday, from: Date())
            if weekday == 4 { // 4 表示周三
                selectedScheduleType = .wednesday
            }
            
            // 初始化滚动位置
            updateScrollToHour()
        }
        .onDisappear {
            // 视图消失时停止定时器
            timer?.invalidate()
            timer = nil
            secondsTimer?.invalidate() // 秒単位のタイマーも停止
            secondsTimer = nil
        }
    }
    
    // 更新滚动位置
    private func updateScrollToHour() {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour], from: currentTime)
        if let currentHour = components.hour {
            scrollToHour = currentHour
        }
    }
    
    // 时刻表类型选择器（平日/周六/水曜日）
    private var scheduleTypeSelector: some View {
        HStack {
            Picker("スケジュールタイプ", selection: $selectedScheduleType) {
                Text("平日（水曜日を除く）").tag(BusSchedule.ScheduleType.weekday)
                Text("水曜日").tag(BusSchedule.ScheduleType.wednesday)
                Text("土曜日").tag(BusSchedule.ScheduleType.saturday)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .onChange(of: selectedScheduleType) { _, _ in
                // スケジュールタイプが変更されたら選択をリセット
                selectedTimeEntry = nil
            }
        }
        .padding(.vertical, 12)
        .background(Color.white)
    }
    
    // 路线选择器
    private var routeTypeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 15) {
                routeButton(title: "聖蹟桜ヶ丘駅発", type: .fromSeisenToNagayama)
                routeButton(title: "永山駅発", type: .fromNagayamaToSeisen)
                routeButton(title: "聖蹟桜ヶ丘駅行", type: .fromSchoolToNagayama)
                routeButton(title: "永山駅行", type: .fromNagayamaToSchool)
            }
            .padding(.horizontal)
            .padding(.vertical, 5)
        }
        .padding(.vertical, 8)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
    
    // 路线按钮
    private func routeButton(title: String, type: BusSchedule.RouteType) -> some View {
        Button(action: {
            selectedRouteType = type
            // 路線タイプが変更されたら選択をリセット
            selectedTimeEntry = nil
        }) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(selectedRouteType == type ?
                              Color.blue.opacity(0.9) :
                                Color.gray.opacity(0.15))
                        .shadow(color: selectedRouteType == type ?
                                Color.blue.opacity(0.3) :
                                    Color.clear,
                                radius: 3, x: 0, y: 2)
                )
                .foregroundColor(selectedRouteType == type ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: selectedRouteType)
    }
    
    // 时刻表内容
    private var scheduleContent: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .center, spacing: 16) {
                    // 时刻表
                    scheduleTableView
                        .onChange(of: scrollToHour) { oldValue, newValue in
                            if let hour = newValue {
                                withAnimation {
                                    scrollProxy.scrollTo("hour_\(hour)", anchor: .top)
                                }
                            }
                        }
                    
                    // 特殊班次说明
                    specialNotesView
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .onAppear {
                // 视图出现时滚动到当前时间
                if let hour = scrollToHour {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation {
                            scrollProxy.scrollTo("hour_\(hour)", anchor: .top)
                        }
                    }
                }
            }
        }
    }
    
    // 当前时间显示
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
            
            // 下一班车信息
            if let nextBus = selectedTimeEntry ?? getNextBus() {
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
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
        )
        // タップイベントを親ビューに伝播させないようにする
        .contentShape(Rectangle())
        .onTapGesture {
            // 何もしない（タップイベントを消費する）
        }
        .animation(.easeInOut(duration: 0.2), value: selectedTimeEntry)
    }
    
    // 获取倒计时文本（秒単位まで精確に）
    private func getCountdownText(to nextBus: BusSchedule.TimeEntry) -> String {
        let calendar = Calendar.current
        
        // 创建下一班车的日期
        var nextBusDateComponents = calendar.dateComponents([.year, .month, .day], from: currentTime)
        nextBusDateComponents.hour = nextBus.hour
        nextBusDateComponents.minute = nextBus.minute
        nextBusDateComponents.second = 0
        
        guard let nextBusDate = calendar.date(from: nextBusDateComponents) else {
            return ""
        }
        
        // 如果下一班车时间早于当前时间，可能是第二天的班车
        if nextBusDate < currentTime {
            // 添加一天
            guard let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: nextBusDate) else {
                return ""
            }
            
            let components = calendar.dateComponents([.hour, .minute, .second], from: currentTime, to: tomorrowDate)
            if let hour = components.hour, let minute = components.minute, let second = components.second {
                if hour > 0 {
                    return "\(hour)時間\(minute)分\(second)秒"
                } else {
                    return "\(minute)分\(second)秒"
                }
            }
        } else {
            // 计算时间差
            let components = calendar.dateComponents([.hour, .minute, .second], from: currentTime, to: nextBusDate)
            if let hour = components.hour, let minute = components.minute, let second = components.second {
                if hour > 0 {
                    return "\(hour)時間\(minute)分\(second)秒"
                } else {
                    return "\(minute)分\(second)秒"
                }
            }
        }
        
        return ""
    }
    
    // 时刻表视图
    private var scheduleTableView: some View {
        VStack(spacing: 0) {
            // 表头
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
            .background(Color.gray.opacity(0.05))
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // 水曜日特別メッセージ（水曜日スケジュールが選択されている場合）
            if selectedScheduleType == .wednesday {
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
                
                Divider()
                    .background(Color.gray.opacity(0.3))
            }
            
            // 时刻表内容
            ForEach(getFilteredSchedule().hourSchedules, id: \.hour) { hourSchedule in
                if !hourSchedule.times.isEmpty {
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            // 小时
                            Text("\(hourSchedule.hour)")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                                .frame(width: 70, alignment: .center)
                                .padding(.vertical, 12)
                            
                            Divider()
                                .frame(width: 1)
                                .background(Color.gray.opacity(0.3))
                            
                            // 分钟列表 - 改进对齐方式
                            VStack(alignment: .center) {
                                LazyVGrid(columns: Array(repeating: GridItem(.fixed(50), spacing: 8), count: 5), alignment: .center, spacing: 12) {
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
                        isCurrentHour(hourSchedule.hour) ?
                        Color.green.opacity(0.1) :
                            (hourSchedule.hour % 2 == 0 ? Color.white : Color.gray.opacity(0.03))
                    )
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        // タップイベントを親ビューに伝播させないようにする
        .contentShape(Rectangle())
        .onTapGesture {
            // 時刻表の空白部分をタップした場合も選択を解除
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTimeEntry = nil
                cardInfoAppeared = false
            }
        }
    }
    
    // 判断是否为当前小时
    private func isCurrentHour(_ hour: Int) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour], from: currentTime)
        return components.hour == hour
    }
    
    // 单个时间条目视图
    private func timeEntryView(_ time: BusSchedule.TimeEntry) -> some View {
        HStack(spacing: 2) {
            Text("\(String(format: "%02d", time.minute))")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isCurrentOrNextBus(time) || selectedTimeEntry == time ? .white : .primary)
                .frame(width: 36, height: 36, alignment: .center)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            selectedTimeEntry == time ? Color.orange.opacity(0.9) :
                                (isCurrentOrNextBus(time) ? Color.blue.opacity(0.9) : Color.clear)
                        )
                )
            
            if let note = time.specialNote {
                Text(note)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(9)
            }
        }
        .frame(height: 36)
        .onTapGesture {
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
    }
    
    // 特殊班次说明视图
    private var specialNotesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("備考")
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading) // 左揃えを明示的に指定
            
            ForEach(busSchedule.specialNotes, id: \.symbol) { note in
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
                        .frame(maxWidth: .infinity, alignment: .leading) // 説明文を左揃えに
                }
            }
            
            // 水曜日の場合は特別メッセージを表示しない
            if selectedScheduleType != .wednesday {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    
                    Text("水曜日は特別ダイヤで運行しています")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.red)
                    
                    Spacer() // 右側にスペースを追加して左揃えを確保
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .frame(width: UIScreen.main.bounds.width - 32) // 画面幅から左右のパディングを引いた幅に設定
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        // タップイベントを親ビューに伝播させないようにする
        .contentShape(Rectangle())
        .onTapGesture {
            // 何もしない（タップイベントを消費する）
        }
    }
    
    // 日期格式化器
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
    
    // 获取筛选后的时刻表
    private func getFilteredSchedule() -> BusSchedule.DaySchedule {
        let schedules: [BusSchedule.DaySchedule]
        
        switch selectedScheduleType {
        case .weekday:
            schedules = busSchedule.weekdaySchedules
        case .saturday:
            schedules = busSchedule.saturdaySchedules
        case .wednesday:
            schedules = busSchedule.wednesdaySchedules
        }
        
        // 查找匹配的路线时刻表
        if let schedule = schedules.first(where: { $0.routeType == selectedRouteType }) {
            return schedule
        }
        
        // 如果没有找到匹配的路线，返回第一个时刻表（防止崩溃）
        return schedules.first ?? BusSchedule.DaySchedule(
            routeType: .fromSeisenToNagayama,
            scheduleType: selectedScheduleType,
            hourSchedules: []
        )
    }
    
    // 判断是否为当前或下一班车
    private func isCurrentOrNextBus(_ time: BusSchedule.TimeEntry) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: currentTime)
        
        guard let currentHour = components.hour, let currentMinute = components.minute else {
            return false
        }
        
        // 如果是同一小时，且分钟大于等于当前分钟
        if time.hour == currentHour && time.minute >= currentMinute {
            return true
        }
        
        // 如果是下一个小时的第一班车
        if time.hour == currentHour + 1 {
            // 获取当前小时的所有班次
            let currentHourSchedule = getFilteredSchedule().hourSchedules.first { $0.hour == currentHour }
            
            // 如果当前小时没有更晚的班次，且这是下一小时的第一班车
            if let currentHourSchedule = currentHourSchedule,
               !currentHourSchedule.times.contains(where: { $0.minute > currentMinute }),
               let nextHourSchedule = getFilteredSchedule().hourSchedules.first(where: { $0.hour == currentHour + 1 }),
               let firstTimeInNextHour = nextHourSchedule.times.first,
               time.minute == firstTimeInNextHour.minute {
                return true
            }
        }
        
        return false
    }
    
    // 获取下一班车
    private func getNextBus() -> BusSchedule.TimeEntry? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: currentTime)
        
        guard let currentHour = components.hour, let currentMinute = components.minute else {
            return nil
        }
        
        let schedule = getFilteredSchedule()
        
        // 查找当前小时内的下一班车
        if let currentHourSchedule = schedule.hourSchedules.first(where: { $0.hour == currentHour }),
           let nextBus = currentHourSchedule.times.first(where: { $0.minute >= currentMinute }) {
            return nextBus
        }
        
        // 查找后续小时的第一班车
        if currentHour < 23 {
            for hour in (currentHour + 1)...23 {
                if let hourSchedule = schedule.hourSchedules.first(where: { $0.hour == hour }),
                   let firstBus = hourSchedule.times.first {
                    return firstBus
                }
            }
        }
        
        // 如果当前是23点以后，或者没有找到后续班车，则返回nil
        return nil
    }
    
    // 检查选择的时间是否已经过期
    private func checkIfSelectedTimePassed() {
        guard let selectedTime = selectedTimeEntry else { return }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: currentTime)
        
        guard let currentHour = components.hour, let currentMinute = components.minute else { return }
        
        // 如果选择的时间已经过期（当前时间已经超过了选择的时间）
        if (selectedTime.hour < currentHour) || 
           (selectedTime.hour == currentHour && selectedTime.minute < currentMinute) {
            // 自动解除选择
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTimeEntry = nil
                cardInfoAppeared = false
            }
        }
    }
}

#Preview {
    BusScheduleView()
}
