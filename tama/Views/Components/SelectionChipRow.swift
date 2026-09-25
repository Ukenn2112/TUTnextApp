import SwiftUI

// MARK: - 選択チップの並び

/// 横に並んだチップから1つを選ぶ部品。選択中の塗り（角丸の帯）がチップの間を滑って移る。
///
/// - 選択の移動は `Motion.quick`。「視差効果を減らす」が有効なら滑らせず、
///   `Motion.reduced` のクロスフェードで切り替える
/// - 利用者が別のチップを押したときだけ「選択」の触覚を返す（コードから選択を変えたときは鳴らさない）
/// - スクロールは持たない。はみ出す可能性がある場所では呼び出し側で `ScrollView(.horizontal)` に入れる
/// - 各チップには `ForEach` の id として `item` 自身が付くので、`ScrollViewReader.scrollTo(item)` で寄せられる
///
/// ```swift
/// ScrollView(.horizontal, showsIndicators: false) {
///     SelectionChipRow(AssignmentFilter.allCases, selection: $selectedFilter) { filter in
///         Text(filter.title)
///     }
///     .padding(.horizontal, 16)
/// }
/// ```
struct SelectionChipRow<Item: Hashable, ChipLabel: View>: View {

    private let items: [Item]
    @Binding private var selection: Item
    private let tint: Color
    private let spacing: CGFloat
    private let fillsWidth: Bool
    private let separatorBefore: Set<Item>
    private let separatorHeight: CGFloat
    private let onSelect: ((Item) -> Void)?
    private let label: (Item) -> ChipLabel

    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 利用者がチップを選び直した回数。触覚のきっかけにだけ使う
    @State private var selectionTapCount = 0

    /// チップの角丸の半径（高さの約半分で、ほぼカプセル形になる）
    private static var cornerRadius: CGFloat { 20 }

    /// - Parameters:
    ///   - items: 並べる項目（重複しないこと）
    ///   - selection: 選択中の項目
    ///   - tint: 選択中のチップの塗り
    ///   - spacing: チップの間隔
    ///   - fillsWidth: `true` なら各チップが与えられた幅を均等に分け合う（横スクロールしない並べ方）
    ///   - separatorBefore: この項目の手前に縦の区切り線を入れる（バスの「駅発」と「駅行」の間など）
    ///   - separatorHeight: 区切り線の高さ
    ///   - onSelect: 利用者が別の項目を選んだあとに呼ばれる（`selection` の更新後）。
    ///     選択中のチップをもう一度押したときは呼ばれない
    ///   - label: チップの中身。文字の大きさ・行数などは呼び出し側で決める（色はこの部品が付ける）
    init(
        _ items: [Item],
        selection: Binding<Item>,
        tint: Color = .appPrimary,
        spacing: CGFloat = 15,
        fillsWidth: Bool = false,
        separatorBefore: Set<Item> = [],
        separatorHeight: CGFloat = 20,
        onSelect: ((Item) -> Void)? = nil,
        @ViewBuilder label: @escaping (Item) -> ChipLabel
    ) {
        self.items = items
        self._selection = selection
        self.tint = tint
        self.spacing = spacing
        self.fillsWidth = fillsWidth
        self.separatorBefore = separatorBefore
        self.separatorHeight = separatorHeight
        self.onSelect = onSelect
        self.label = label
    }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(items, id: \.self) { item in
                if separatorBefore.contains(item) {
                    Divider()
                        .frame(height: separatorHeight)
                        .background(Color.gray.opacity(0.3))
                }
                chip(for: item)
            }
        }
        .sensoryFeedback(.selection, trigger: selectionTapCount)
    }

    private func chip(for item: Item) -> some View {
        let isSelected = item == selection
        return Button {
            select(item)
        } label: {
            label(item)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                            .fill(Color(UIColor.secondarySystemFill))
                        if isSelected {
                            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                                .fill(tint)
                                .shadow(color: tint.opacity(0.3), radius: 3, x: 0, y: 2)
                                .matchedGeometryEffect(id: indicatorID(for: item), in: namespace)
                        }
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// 選択中の塗りの id。
    /// 通常は全チップで1つの id を共有して塗りを滑らせる。
    /// 「視差効果を減らす」が有効なときはチップごとに別の id にし、滑らせずにその場でクロスフェードさせる
    private func indicatorID(for item: Item) -> AnyHashable {
        reduceMotion ? AnyHashable(item) : AnyHashable("selectionIndicator")
    }

    private func select(_ item: Item) {
        guard item != selection else { return }
        withAnimation(Motion.resolved(Motion.quick, reduceMotion: reduceMotion)) {
            selection = item
        }
        selectionTapCount += 1
        onSelect?(item)
    }
}

// MARK: - プレビュー

#Preview("SelectionChipRow") {
    @Previewable @State var filter = "すべて"
    @Previewable @State var route = 0

    let filters = ["すべて", "今日", "今週", "今月", "期限切れ"]
    let routes = ["聖蹟桜ヶ丘駅発", "永山駅発", "聖蹟桜ヶ丘駅行", "永山駅行"]

    VStack(spacing: 24) {
        ScrollView(.horizontal, showsIndicators: false) {
            SelectionChipRow(filters, selection: $filter) { title in
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 5)
        }

        SelectionChipRow(
            Array(routes.indices),
            selection: $route,
            spacing: 8,
            fillsWidth: true,
            separatorBefore: [2]
        ) { index in
            Text(routes[index])
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 16)
    }
}
