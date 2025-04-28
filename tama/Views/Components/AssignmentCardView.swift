import SwiftUI

struct AssignmentCardView: View {
    let assignment: Assignment
    var onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    // 根据课题状态返回适当的颜色
    private var timeColor: Color {
        if assignment.isOverdue {
            return .red
        } else if assignment.isUrgent {
            return .orange
        } else {
            return .primary
        }
    }

    // 根据课题状态返回适当的背景颜色
    private var timeBackgroundColor: Color {
        if assignment.isOverdue {
            return Color.red.opacity(0.1)
        } else if assignment.isUrgent {
            return Color.orange.opacity(0.1)
        } else {
            return Color.gray.opacity(0.1)
        }
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(assignment.courseName)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    // 残り時間を表示
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)

                        Text(assignment.remainingTimeText)
                            .font(.caption)
                    }
                    .foregroundColor(timeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(timeBackgroundColor)
                    )
                }

                Text(assignment.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text(assignment.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack {
                    // 期限日を表示
                    Text("\(formatDate(assignment.dueDate)) 締切")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                ZStack {
                    // ダークモードの場合、白い光彩を追加
                    if colorScheme == .dark {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                            .blur(radius: 1)
                            .padding(-2)
                    }

                    // カードの背景
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.systemBackground))
                }
            )
            .shadow(
                color: colorScheme == .dark
                    ? Color.white.opacity(0.07)
                    : Color.black.opacity(0.1),
                radius: colorScheme == .dark ? 8 : 5,
                x: 0,
                y: colorScheme == .dark ? 0 : 2
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    let calendar = Calendar.current
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
    let urgentDate = calendar.date(byAdding: .hour, value: 1, to: Date())!

    let assignment = Assignment(
        id: "1",
        title: "第3回レポート提出",
        courseId: "CS101",
        courseName: "プログラミング入門",
        dueDate: tomorrow,
        description: "第3章の内容に関するレポートを提出してください。",
        status: .pending,
        url: "https://example.com/assignments/1"
    )

    return VStack {
        AssignmentCardView(assignment: assignment) {
            print("Tapped assignment")
        }
        .padding()

        AssignmentCardView(
            assignment: Assignment(
                id: "2",
                title: "期限切れの課題",
                courseId: "CS102",
                courseName: "データ構造",
                dueDate: calendar.date(byAdding: .day, value: -1, to: Date())!,
                description: "期限切れの課題の例です。",
                status: .pending,
                url: "https://example.com/assignments/2"
            )
        ) {
            print("Tapped overdue assignment")
        }
        .padding()

        AssignmentCardView(
            assignment: Assignment(
                id: "3",
                title: "緊急の課題",
                courseId: "CS103",
                courseName: "アルゴリズム",
                dueDate: urgentDate,
                description: "残り時間が2時間未満の緊急課題です。",
                status: .pending,
                url: "https://example.com/assignments/3"
            )
        ) {
            print("Tapped urgent assignment")
        }
        .padding()
    }
    .background(Color(UIColor.systemGroupedBackground))
    .preferredColorScheme(.dark)
}
