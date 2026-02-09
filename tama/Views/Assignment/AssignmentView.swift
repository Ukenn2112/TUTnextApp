//
//  AssignmentView.swift
//  TUTnext
//
//  Glassmorphism Assignment View
//

import SwiftUI
import CoreNetworking

struct AssignmentView: View {
    @Binding var isLoggedIn: Bool
    @StateObject private var viewModel = AssignmentViewModel()
    @State private var selectedFilter: AssignmentFilter = .all
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var ratingService: RatingService
    @EnvironmentObject private var oauthService: GoogleOAuthService
    
    @State private var willEnterForegroundObserver: NSObjectProtocol? = nil
    
    enum AssignmentFilter: String, CaseIterable {
        case all = "すべて"
        case today = "今日"
        case thisWeek = "今週"
        case thisMonth = "今月"
        case overdue = "期限切れ"
    }
    
    var body: some View {
        ZStack {
            ThemeColors.Gradient.fullGradient(for: themeManager.currentTheme)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    LoadingView(message: "課題を読み込み中...")
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorView(message: errorMessage) {
                        viewModel.loadAssignments()
                    }
                } else if viewModel.assignments.isEmpty {
                    EmptyAssignmentView()
                } else {
                    filterSelector
                    assignmentList
                }
            }
        }
        .onAppear {
            viewModel.loadAssignments()
            ratingService.recordSignificantEvent()
            setupObservers()
            Task {
                await oauthService.loadAuthorizationStatus()
            }
        }
        .onDisappear {
            cleanupObservers()
        }
        .onReceive(NotificationCenter.default.publisher(for: .googleOAuthSuccess)) { _ in
            viewModel.loadAssignments()
        }
        .onReceive(NotificationCenter.default.publisher(for: .googleOAuthStatusChanged)) { _ in
            viewModel.loadAssignments()
        }
    }
    
    // MARK: - Observers
    private func setupObservers() {
        willEnterForegroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            viewModel.loadAssignments()
            Task {
                await oauthService.loadAuthorizationStatus()
            }
        }
    }
    
    private func cleanupObservers() {
        if let observer = willEnterForegroundObserver {
            NotificationCenter.default.removeObserver(observer)
            willEnterForegroundObserver = nil
        }
    }
    
    // MARK: - Filter Selector
    private var filterSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(AssignmentFilter.allCases, id: \.self) { filter in
                    filterButton(for: filter)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(ThemeColors.Glass.medium)
    }
    
    private func filterButton(for filter: AssignmentFilter) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = filter
            }
        } label: {
            Text(filter.rawValue)
                .typography(.labelMedium)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(selectedFilter == filter ? Color.accentColor : ThemeColors.Glass.light)
                        .shadow(color: selectedFilter == filter ? Color.accentColor.opacity(0.3) : .clear, radius: 3, y: 2)
                )
                .foregroundColor(selectedFilter == filter ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Assignment List
    private var assignmentList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredAssignments) { assignment in
                    AssignmentCardView(assignment: assignment) {
                        if let url = URL(string: assignment.url) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    private var filteredAssignments: [Assignment] {
        switch selectedFilter {
        case .all: return viewModel.assignments
        case .today: return viewModel.todayAssignments
        case .thisWeek: return viewModel.thisWeekAssignments
        case .thisMonth: return viewModel.thisMonthAssignments
        case .overdue: return viewModel.overdueAssignments
        }
    }
}

// MARK: - Assignment Card View
struct AssignmentCardView: View {
    let assignment: Assignment
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    private var daysRemaining: Int? {
        guard let dueDate = assignment.dueDate else { return nil }
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: now, to: dueDate)
        return components.day
    }
    
    private var statusColor: Color {
        guard let days = daysRemaining else { return .gray }
        if days < 0 { return .red }
        if days == 0 { return .orange }
        if days <= 3 { return .yellow }
        return .green
    }
    
    private var statusText: String {
        guard let days = daysRemaining else { return "期限未定" }
        if days < 0 { return "期限切れ" }
        if days == 0 { return "今日截止" }
        return "\(days)日後"
    }
    
    var body: some View {
        InteractiveGlassCard(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Status Indicator
                VStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 12, height: 12)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    // Title
                    StyledText(assignment.title, style: .bodyMedium)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    
                    // Course Name
                    if let courseName = assignment.courseName {
                        StyledText(courseName, style: .caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Due Date
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text(assignment.formattedDueDate)
                            .typography(.caption)
                    }
                    .foregroundColor(statusColor)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

#Preview {
    AssignmentView(isLoggedIn: .constant(true))
        .environmentObject(ThemeManager.shared)
        .environmentObject(RatingService.shared)
        .environmentObject(GoogleOAuthService.shared)
}
