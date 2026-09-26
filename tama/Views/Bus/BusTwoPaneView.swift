import SwiftUI

// MARK: - バスの2列表示

/// バスタブの2列表示（iPhone Duoの内側ディスプレイ・横向き）。
///
/// 1列表示では4つの路線チップから1つだけを選んで見るが、この幅では
/// **同じ駅の両方向**（駅発と駅行）を同時に出せる。行きと帰りを見比べるのに路線を往復しなくてよい。
///
/// 組み方:
/// - 上の帯はページ全体に効く共通の情報と操作（タイトル・臨時ダイヤ・駅・曜日・ピン）
/// - その下を `ArrangementView` で左右に分ける。左＝駅発（学校へ）、右＝駅行（駅へ）
/// - 左右の列は同じ部品・同じ寸法（`BusLayout.TwoPane`）だけで組むので、
///   見出し・時刻カード・時刻表の各行は必ず同じ線に乗る
///
/// 折り目（本のポーズ）への対応:
/// - 押せるもののうち、左右の列の中身は `ArrangementView` が継ぎ目をヒンジへ寄せてくれるので
///   放っておいても折り目に掛からない
/// - 上の帯の操作だけは自分で避ける必要があるため、折り目が**有効なとき**は
///   帯の操作をヒンジ手前の幅に収める（`DuoDivision`）。列の始まる位置は変わらない
@available(iOS 27.1, *)
struct BusTwoPaneView: View {

    // MARK: - プロパティ

    @ObservedObject var viewModel: BusScheduleViewModel

    /// ページのタイトル（縦バーのポーズではページ内容の先頭に描く）
    let title: String

    /// システムのバーが縦バーとして表示されているか
    let isVerticalBarPose: Bool

    /// 折り目が有効なときの左右の列の幅（平らなときは nil＝`ArrangementView` まかせの等幅）
    @State private var columnSplit: DuoColumnSplit?

    /// 左右の列の浮かぶ時刻カードの実測の高さ（列ごと）。
    /// 路線ではなく列で持つので、駅を切り替えても前の駅の路線の高さが残らない
    @State private var timeCardHeights: [ColumnSide: CGFloat] = [:]

    /// 左右どちらの列か
    private enum ColumnSide {
        case leading
        case trailing
    }

    /// 時刻表を下げる量。左右の実測のうち高いほうを両方の列に配るので、
    /// 片方のカードだけが背の高い場面（選択中の「バス時刻」の行）でも
    /// 2つの表の見出し行は必ず同じ線に乗る
    private var sharedTimeCardHeight: CGFloat {
        timeCardHeights.values.max() ?? 0
    }

    // MARK: - ボディ

    var body: some View {
        VStack(spacing: 0) {
            if isVerticalBarPose {
                // 縦バーのポーズではバーのタイトル帯を無視して上を詰め、
                // グリフ上端がウィンドウ上端から VerticalBarLayout.edgeMargin の位置に来るように描く
                VerticalBarPageTitle(title: title)
                    .padding(.bottom, BusLayout.TwoPane.titleBottomSpacing)
            }

            if viewModel.busSchedule != nil {
                loadedContent
            } else if let errorMessage = viewModel.errorMessage {
                BusLoadFailureView(message: errorMessage) {
                    viewModel.errorMessage = nil
                    viewModel.fetchBusScheduleData()
                }
            } else {
                // 読み込みが長引いたときだけ、左右2列分の時刻カードと表の形を出す
                BusLoadingPlaceholder(columnCount: 2)
                    .padding(.top, BusLayout.TwoPane.bandBottomSpacing)
            }
        }
        // 折り目はページのローカル座標で読む（起動直後は報告されないので nil のまま＝平らと同じ扱い）
        .onGeometryChange(for: DuoColumnSplit?.self) { proxy in
            DuoColumnSplit.make(proxy: proxy, padding: BusLayout.horizontalPadding)
        } action: { columnSplit = $0 }
    }

    // MARK: - サブビュー

    /// 時刻表を読み込めたときの中身（共通の帯＋左右2列）
    private var loadedContent: some View {
        VStack(spacing: 0) {
            // 読む順は「知らせ → 操作 → 時刻表」。
            // 臨時ダイヤとピンは同じ「知らせ」なので続けて置き、
            // 駅と曜日の操作は、それが効く2つの列のすぐ上に置く
            //
            // 本のポーズではどちらも左の列（ヒンジの手前）に収め、折り目をまたいでスクロール・表示しない。
            // 親の VStack は中央揃えなので、外側でもう一度ページの先頭側へ寄せる
            if let messages = viewModel.busSchedule?.temporaryMessages, !messages.isEmpty {
                BusTemporaryMessagesView(messages: messages)
                    // 横スクロールの行は自分で左右の余白を持つので、ページの端からヒンジの手前まで
                    .frame(
                        maxWidth: columnSplit.map { $0.leadingWidth + BusLayout.horizontalPadding }
                            ?? .infinity,
                        alignment: .leading
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let pinMessage = viewModel.busSchedule?.pin {
                PinMessageRowView(pinMessage: pinMessage)
                    .frame(maxWidth: columnSplit.map { $0.leadingWidth } ?? .infinity,
                           alignment: .leading)
                    .padding(.horizontal, BusLayout.horizontalPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            BusTwoPaneControls(
                station: viewModel.selectedStation,
                scheduleType: viewModel.selectedScheduleType,
                columnSplit: columnSplit,
                // 利用者がセグメントを押したときだけ呼ばれる（利用者の操作なので静かに動かす）。
                // 左右の時刻表は行やチップを動かさず、表ごとクロスフェードで入れ替わる（`BusTimeTableContent`）
                onStationSelected: { station in
                    withMotion(Motion.standard) {
                        viewModel.selectedStation = station
                        viewModel.onStationChanged()
                    }
                },
                onScheduleTypeSelected: { scheduleType in
                    withMotion(Motion.standard) {
                        viewModel.selectedScheduleType = scheduleType
                        viewModel.onScheduleTypeChanged()
                    }
                }
            )
            .padding(.horizontal, BusLayout.horizontalPadding)
            .padding(.top, BusLayout.Spacing.s)

            columns
                .padding(.top, BusLayout.TwoPane.bandBottomSpacing)
        }
        #if DEBUG
        // 起動引数で指定されたときだけ、読み込み後に駅発の次の便を選んだ状態にする
        .onChange(of: viewModel.busSchedule != nil, initial: true) { _, isLoaded in
            applyDebugSelectionIfNeeded(isLoaded: isLoaded)
        }
        #endif
    }

    /// 左＝駅発（学校へ）、右＝駅行（駅へ）。
    /// `ArrangementView` が継ぎ目を持つので、列の中身は折り目を自分で避けなくてよい
    private var columns: some View {
        ArrangementView {
            column(
                route: viewModel.selectedStation.toSchoolRoute, side: .leading,
                showsSpecialNotes: false)
        } secondary: {
            // 備考はページ全体に効く注記（路線ごとには変わらない）なので、右の列だけで1回出す
            column(
                route: viewModel.selectedStation.fromSchoolRoute, side: .trailing,
                showsSpecialNotes: true)
        }
        .arrangementViewStyle(.split.axes(.horizontal))
    }

    /// 片方の列（時刻カードの高さは左右で共有する）
    private func column(
        route: BusSchedule.RouteType, side: ColumnSide, showsSpecialNotes: Bool
    ) -> some View {
        BusDirectionColumnView(
            viewModel: viewModel,
            route: route,
            sharedTimeCardHeight: sharedTimeCardHeight,
            onTimeCardHeightChange: { timeCardHeights[side] = $0 },
            showsSpecialNotes: showsSpecialNotes
        )
    }

    // MARK: - 検証用

    #if DEBUG
    /// `-DuoBusSelectFirstUpcoming YES` のときだけ、駅発の次の便を選んだ状態にする。
    /// CLIからは時刻表のセルを押せないため、選択中のスクリーンショットを撮るための入口
    private func applyDebugSelectionIfNeeded(isLoaded: Bool) {
        guard DuoDebugBus.selectsFirstUpcoming, isLoaded,
              viewModel.selectedTimeEntry == nil
        else {
            return
        }
        let route = viewModel.selectedStation.toSchoolRoute
        guard let next = viewModel.getNextBus(for: route) else { return }
        viewModel.handleTimeEntryTap(next, on: route)
    }
    #endif
}

// MARK: - 駅の表示名

extension BusStation {

    /// 駅セレクタに出す駅の名前（路線名から「発」「行」を取った呼び方）
    var displayName: String {
        switch self {
        case .seiseki: return NSLocalizedString("聖蹟桜ヶ丘", comment: "バスの駅")
        case .nagayama: return NSLocalizedString("永山", comment: "バスの駅")
        }
    }
}

// MARK: - 共通の操作

/// ページ全体に効く2つの操作（駅と曜日）。左右どちらの列にも同じように効く。
///
/// 見た目も並びも下の2列と揃える: 駅セレクタは左の列の幅、曜日セレクタは右の列の幅に広げ、
/// どちらも同じセグメントの体裁・同じ高さで同じ線に乗せる。
/// 本のポーズでは列の幅が折り目で決まるため、操作が折り目に掛かることもない。
///
/// 駅と曜日は、利用者がセグメントを押したときだけ `onStationSelected` / `onScheduleTypeSelected` で返す。
/// ディープリンクや起動時の曜日合わせのようにプログラムから値が変わったときは何も呼ばないので、
/// 選んだ便やライブアクティビティ、ディープリンクで指定した路線が捨てられることはない
private struct BusTwoPaneControls: View {

    let station: BusStation
    let scheduleType: BusSchedule.ScheduleType

    /// 折り目が有効なときの左右の列の幅（平らなときは nil＝等幅）
    let columnSplit: DuoColumnSplit?

    let onStationSelected: (BusStation) -> Void
    let onScheduleTypeSelected: (BusSchedule.ScheduleType) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: columnSplit?.gutter ?? BusLayout.TwoPane.columnGutter) {
            stationPicker
                .frame(maxWidth: columnSplit.map { $0.leadingWidth } ?? .infinity)

            dayPicker
                .frame(maxWidth: columnSplit.map { $0.trailingWidth } ?? .infinity)
        }
    }

    /// 駅セレクタ（曜日セレクタとまったく同じセグメントの体裁）
    private var stationPicker: some View {
        Picker("駅", selection: stationSelection) {
            ForEach(BusStation.allCases, id: \.self) { candidate in
                Text(candidate.displayName).tag(candidate)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
    }

    /// 曜日セレクタ（1列表示と同じ選択肢・同じ体裁）
    private var dayPicker: some View {
        Picker("スケジュールタイプ", selection: scheduleTypeSelection) {
            Text("平日（水曜日を除く）").tag(BusSchedule.ScheduleType.weekday)
            Text("水曜日").tag(BusSchedule.ScheduleType.wednesday)
            Text("土曜日").tag(BusSchedule.ScheduleType.saturday)
        }
        .pickerStyle(SegmentedPickerStyle())
    }

    /// 駅セレクタの選択（押されたときだけ親へ返す）
    private var stationSelection: Binding<BusStation> {
        Binding(
            get: { station },
            set: { newValue in
                guard newValue != station else { return }
                onStationSelected(newValue)
            }
        )
    }

    /// 曜日セレクタの選択（押されたときだけ親へ返す）
    private var scheduleTypeSelection: Binding<BusSchedule.ScheduleType> {
        Binding(
            get: { scheduleType },
            set: { newValue in
                guard newValue != scheduleType else { return }
                onScheduleTypeSelected(newValue)
            }
        )
    }
}

// MARK: - 読み込み失敗

/// 時刻表を読み込めなかったときの表示（1列表示と同じ文言・同じ作り）
private struct BusLoadFailureView: View {

    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(message)
                .foregroundStyle(.red)
                .padding()
                .multilineTextAlignment(.center)

            Button(action: onRetry) {
                Text("再読み込み")
            }
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
