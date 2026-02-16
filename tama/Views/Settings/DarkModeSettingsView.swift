import SwiftUI

/// 外観モード（ライト/ダーク/システム）を選択するシート
struct DarkModeSettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appearanceManager: AppearanceManager

    var body: some View {
        NavigationStack {
            Form {
                // プレビューセクション
                Section {
                    HStack {
                        Spacer()
                        appearancePreview(
                            icon: "sun.max.fill",
                            label: NSLocalizedString("ライト", comment: ""),
                            isActive: colorScheme == .light
                        )
                        Spacer()
                        appearancePreview(
                            icon: "moon.stars.fill",
                            label: NSLocalizedString("ダーク", comment: ""),
                            isActive: colorScheme == .dark
                        )
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                }

                // 外観モード選択セクション
                Section {
                    appearanceRow(
                        title: NSLocalizedString("システムに従う", comment: ""),
                        icon: "gear",
                        color: .gray,
                        mode: .system
                    )
                    appearanceRow(
                        title: NSLocalizedString("ライトモード", comment: ""),
                        icon: "sun.max.fill",
                        color: .orange,
                        mode: .light
                    )
                    appearanceRow(
                        title: NSLocalizedString("ダークモード", comment: ""),
                        icon: "moon.stars.fill",
                        color: .indigo,
                        mode: .dark
                    )
                } footer: {
                    Text(NSLocalizedString("「システムに従う」を選択すると、デバイスの設定に合わせて自動的に切り替わります。", comment: ""))
                }
            }
            .navigationBarTitle("外観モード", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    // MARK: - コンポーネント

    /// 外観プレビューアイコン
    private func appearancePreview(
        icon: String,
        label: String,
        isActive: Bool
    ) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(isActive ? (icon.contains("sun") ? .orange : .blue) : .gray)
                .frame(width: 64, height: 64)
                .background(
                    Circle()
                        .fill(isActive ? (icon.contains("sun") ? Color.orange : Color.blue).opacity(0.15) : Color(UIColor.tertiarySystemFill))
                )
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(isActive ? .primary : .secondary)
        }
    }

    /// iOS設定アプリスタイルの選択行
    private func appearanceRow(
        title: String,
        icon: String,
        color: Color,
        mode: AppearanceManager.AppearanceMode
    ) -> some View {
        Button {
            withAnimation { appearanceManager.setMode(mode) }
        } label: {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Text(title)
                    .foregroundStyle(.primary)

                Spacer()

                if appearanceManager.mode == mode {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.blue)
                }
            }
        }
        .tint(.primary)
    }
}
