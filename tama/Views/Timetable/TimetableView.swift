//
//  TimetableView.swift
//  TUTnext
//
//  Glassmorphism Timetable View
//

import SwiftUI
import CoreStorage

struct TimetableView: View {
    @Binding var isLoggedIn: Bool
    @StateObject private var viewModel = TimetableViewModel()
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var ratingService: RatingService
    
    @State private var willEnterForegroundObserver: NSObjectProtocol? = nil
    @State private var announcementSafariDismissObserver: NSObjectProtocol? = nil
    
    private let presetColors: [Color] = [
        .white,
        Color(red: 1.0, green: 0.8, blue: 0.8),
        Color(red: 1.0, green: 0.9, blue: 0.8),
        Color(red: 1.0, green: 1.0, blue: 0.8),
        Color(red: 0.9, green: 1.0, blue: 0.8),
        Color(red: 0.8, green: 1.0, blue: 0.8),
        Color(red: 0.8, green: 1.0, blue: 1.0),
        Color(red: 1.0, green: 0.8, blue: 0.9),
        Color(red: 0.9, green: 0.8, blue: 1.0),
        Color(red: 0.8, green: 0.9, blue: 1.0),
        Color(red: 1.0, green: 0.9, blue: 1.0),
    ]
    
    private func weekdayString(from index: String) -> String {
        guard let idx = Int(index), idx >= 1 && idx <= 7 else { return "" }
        let weekdays = ["月", "火", "水", "木", "金", "土", "日"]
        return weekdays[idx - 1]
    }
    
    var body: some View {
        GeometryReader { geometry in
            let layout = LayoutMetrics(
                geometry: geometry,
                columnCount: viewModel.getWeekdays().count,
                rowCount: viewModel.getPeriods().count
            )
            
            ZStack {
                // Background
                ThemeColors.Gradient.fullGradient(for: themeManager.currentTheme)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if viewModel.isLoading {
                        LoadingView(message: "時間割を読み込み中...")
                    } else if let errorMessage = viewModel.errorMessage {
                        ErrorView(message: errorMessage) {
                            viewModel.fetchTimetableData()
                        }
                    } else {
                        weekdayHeaderView(layout: layout)
                        timeTableGridView(layout: layout)
                    }
                }
                .padding(.leading, layout.leftPadding)
                .padding(.trailing, layout.rightPadding)
                .padding(.top, 8)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .onAppear {
            viewModel.fetchTimetableData()
            ratingService.recordSignificantEvent()
            setupObservers()
        }
        .onDisappear {
            cleanupObservers()
        }
    }
    
    // MARK: - Setup Observers
    private func setupObservers() {
        willEnterForegroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            viewModel.fetchTimetableData()
            NotificationService.shared.checkAuthorizationStatus()
            NotificationService.shared.syncNotificationStatusWithServer()
        }
        
        announcementSafariDismissObserver = NotificationCenter.default.addObserver(
            forName: .announcementSafariDismissed,
            object: nil,
            queue: .main
        ) { _ in
            viewModel.fetchTimetableData()
        }
    }
    
    private func cleanupObservers() {
        if let observer = willEnterForegroundObserver {
            NotificationCenter.default.removeObserver(observer)
            willEnterForegroundObserver = nil
        }
        if let observer = announcementSafariDismissObserver {
            NotificationCenter.default.removeObserver(observer)
            announcementSafariDismissObserver = nil
        }
    }
    
    // MARK: - Header View
    private func weekdayHeaderView(layout: LayoutMetrics) -> some View {
        HStack(spacing: 4) {
            Text("")
                .frame(width: layout.timeColumnWidth)
            
            ForEach(viewModel.getWeekdays(), id: \.self) { day in
                if day == viewModel.getCurrentWeekday() {
                    currentDayView(day: day, width: layout.cellWidth)
                } else {
                    StyledText(weekdayString(from: day), style: .caption)
                        .frame(width: layout.cellWidth, height: 10)
                }
            }
        }
        .frame(height: 10)
        .padding(.bottom, 16)
    }
    
    private func currentDayView(day: String, width: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.green)
                .frame(width: 24, height: 24)
            StyledText(weekdayString(from: day), style: .caption)
                .foregroundColor(.white)
        }
        .frame(width: width, height: 10)
    }
    
    // MARK: - Grid View
    private func timeTableGridView(layout: LayoutMetrics) -> some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(viewModel.getPeriods(), id: \.0) { period, startTime, endTime in
                    HStack(spacing: 4) {
                        timeColumnView(period: period, startTime: startTime, endTime: endTime, layout: layout)
                        periodRowView(period: period, layout: layout)
                    }
                }
            }
        }
    }
    
    private func timeColumnView(period: String, startTime: String, endTime: String, layout: LayoutMetrics) -> some View {
        VStack(spacing: 2) {
            StyledText(startTime, style: .captionSmall)
                .foregroundColor(.secondary)
            StyledText(period, style: .bodyMedium)
            StyledText(endTime, style: .captionSmall)
                .foregroundColor(.secondary)
        }
        .frame(width: layout.timeColumnWidth, height: layout.cellHeight)
    }
    
    private func periodRowView(period: String, layout: LayoutMetrics) -> some View {
        HStack(spacing: 4) {
            ForEach(viewModel.getWeekdays(), id: \.self) { day in
                TimeSlotCell(
                    dayIndex: day,
                    displayDay: weekdayString(from: day),
                    period: period,
                    course: viewModel.courses[day]?[period],
                    presetColors: presetColors,
                    cellWidth: layout.cellWidth,
                    cellHeight: layout.cellHeight,
                    onColorChange: { colorIndex in
                        viewModel.updateCourseColor(day: day, period: period, colorIndex: colorIndex)
                    },
                    isLoggedIn: $isLoggedIn,
                    isCurrentDay: day == viewModel.getCurrentWeekday(),
                    isCurrentPeriod: period == viewModel.getCurrentPeriod()
                )
            }
        }
    }
}

// MARK: - Layout Metrics
private struct LayoutMetrics {
    let timeColumnWidth: CGFloat = 40
    let leftPadding: CGFloat = 8
    let rightPadding: CGFloat = 10
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    
    init(geometry: GeometryProxy, columnCount: Int, rowCount: Int) {
        let safeColumnCount = max(1, columnCount)
        let safeRowCount = max(1, rowCount)
        
        cellWidth = (geometry.size.width - timeColumnWidth - leftPadding - rightPadding - CGFloat(safeColumnCount - 1) * 4) / CGFloat(safeColumnCount)
        cellHeight = (geometry.size.height - 40 - CGFloat(safeRowCount - 1) * 4) / CGFloat(safeRowCount)
    }
}

// MARK: - TimeSlotCell
struct TimeSlotCell: View {
    let dayIndex: String
    let displayDay: String
    let period: String
    let course: CourseModel?
    let presetColors: [Color]
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let onColorChange: (Int) -> Void
    @Binding var isLoggedIn: Bool
    let isCurrentDay: Bool
    let isCurrentPeriod: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingDetail = false
    
    private var adjustedBackgroundColor: Color {
        guard let course = course else {
            return colorScheme == .dark ? Color(UIColor.systemGray6) : .white
        }
        let baseColor = presetColors[course.colorIndex]
        return colorScheme == .dark ? baseColor.opacity(0.8) : baseColor
    }
    
    var body: some View {
        ZStack {
            GlassCard(variant: .flat) {
                if let course = course {
                    VStack(spacing: 2) {
                        StyledText(course.name, style: .captionSmall)
                            .lineLimit(3)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.8)
                        StyledText(course.room, style: .captionSmall)
                            .foregroundColor(.secondary)
                    }
                    .padding(4)
                } else {
                    StyledText("\(displayDay)\(period)", style: .bodySmall)
                        .foregroundColor(.secondary)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        (isCurrentDay && isCurrentPeriod) ? Color.green : Color.clear,
                        lineWidth: (isCurrentDay && isCurrentPeriod) ? 1.5 : 0
                    )
            )
            
            if let course = course, let keijiMidokCnt = course.keijiMidokCnt, keijiMidokCnt > 0 {
                VStack {
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 16, height: 16)
                            Text("\(keijiMidokCnt)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    Spacer()
                }
                .padding(2)
            }
        }
        .frame(width: cellWidth, height: cellHeight)
        .onTapGesture {
            if course != nil {
                showingDetail = true
            }
        }
        .sheet(isPresented: $showingDetail) {
            if let course = course {
                CourseDetailView(
                    course: course,
                    presetColors: presetColors,
                    selectedColorIndex: course.colorIndex,
                    onColorChange: onColorChange,
                    isLoggedIn: $isLoggedIn
                )
            }
        }
    }
}

#Preview {
    TimetableView(isLoggedIn: .constant(true))
        .environmentObject(ThemeManager.shared)
        .environmentObject(RatingService.shared)
}
