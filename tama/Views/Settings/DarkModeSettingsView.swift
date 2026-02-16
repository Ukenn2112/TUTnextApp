import SwiftUI

/// 外観モード（ライト/ダーク/システム）を選択するシート
struct DarkModeSettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var appearanceManager: AppearanceManager

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // ヘッダーアイコン
                    HStack(spacing: 20) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 30))
                            .foregroundColor(colorScheme == .light ? .orange : .gray)
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 30))
                            .foregroundColor(colorScheme == .dark ? .blue : .gray)
                    }
                    .padding(.top, 20)

                    // オプションカード
                    VStack(spacing: 16) {
                        appearanceOptionCard(
                            title: NSLocalizedString("システムに従う", comment: ""),
                            icon: "gear",
                            description: NSLocalizedString("デバイスの設定に合わせて自動的に切り替えます", comment: ""),
                            isSelected: appearanceManager.mode == .system
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                appearanceManager.setMode(.system)
                            }
                        }

                        appearanceOptionCard(
                            title: NSLocalizedString("ライトモード", comment: ""),
                            icon: "sun.max.fill",
                            description: NSLocalizedString("明るい外観を常に使用します", comment: ""),
                            isSelected: appearanceManager.mode == .light
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                appearanceManager.setMode(.light)
                            }
                        }

                        appearanceOptionCard(
                            title: NSLocalizedString("ダークモード", comment: ""),
                            icon: "moon.stars.fill",
                            description: NSLocalizedString("暗い外観を常に使用します", comment: ""),
                            isSelected: appearanceManager.mode == .dark
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                appearanceManager.setMode(.dark)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer()
                }
            }
            .navigationTitle("外観モード")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Text("完了")
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
            }
            .preferredColorScheme(appearanceManager.colorSchemeOverride)
        }
    }

    // MARK: - カードコンポーネント

    private func appearanceOptionCard(
        title: String,
        icon: String,
        description: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                                ? Color.blue.opacity(0.2)
                                : Color(UIColor.secondarySystemBackground)
                        )
                        .frame(width: 50, height: 50)
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? .blue : .gray)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.blue)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
