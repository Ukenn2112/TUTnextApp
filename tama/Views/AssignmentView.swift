import SwiftUI

struct AssignmentView: View {
    @Binding var isLoggedIn: Bool
    @StateObject private var viewModel = AssignmentViewModel()
    @State private var selectedFilter: AssignmentFilter = .all
    @Environment(\.colorScheme) private var colorScheme
    
    enum AssignmentFilter {
        case all, today, thisWeek, thisMonth, overdue
    }
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                ProgressView()
            } else if let errorMessage = viewModel.errorMessage {
                VStack {
                    Text("エラーが発生しました")
                        .font(.headline)
                    
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button {
                        viewModel.loadAssignments()
                    } label: {
                        Text("再読み込み")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding()
            } else if viewModel.assignments.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("課題はありません")
                        .font(.title2)
                    
                    Text("現在提出すべき課題はありません。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        viewModel.loadAssignments()
                    } label: {
                        Text("再読み込み")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding()
            } else {
                VStack(spacing: 0) {
                    // フィルターセグメントコントロール
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            filterButton(title: "すべて", filter: .all)
                            filterButton(title: "今日", filter: .today)
                            filterButton(title: "今週", filter: .thisWeek)
                            filterButton(title: "今月", filter: .thisMonth)
                            filterButton(title: "期限切れ", filter: .overdue)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 5)
                    }
                    .padding(.vertical, 8)
                    .background(Color(UIColor.systemBackground))
                    .shadow(color: Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.2), radius: 2, x: 0, y: 2)
                    
                    // 課題リスト
                    ScrollView {
                        LazyVStack(spacing: 16) {
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
            }
        }
        .onAppear {
            viewModel.loadAssignments()
        }
    }
    
    private var filteredAssignments: [Assignment] {
        switch selectedFilter {
        case .all:
            return viewModel.assignments
        case .today:
            return viewModel.todayAssignments
        case .thisWeek:
            return viewModel.thisWeekAssignments
        case .thisMonth:
            return viewModel.thisMonthAssignments
        case .overdue:
            return viewModel.overdueAssignments
        }
    }
    
    private func filterButton(title: String, filter: AssignmentFilter) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = filter
            }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(selectedFilter == filter ?
                              Color.blue.opacity(0.9) :
                                Color.gray.opacity(colorScheme == .dark ? 0.25 : 0.15))
                        .shadow(color: selectedFilter == filter ?
                                Color.blue.opacity(0.3) :
                                    Color.clear,
                                radius: 3, x: 0, y: 2)
                )
                .foregroundColor(selectedFilter == filter ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview("Assignment View") {
    NavigationView {
        AssignmentView(isLoggedIn: .constant(true))
    }
} 