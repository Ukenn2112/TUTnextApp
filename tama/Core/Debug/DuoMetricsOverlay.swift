//
//  DuoMetricsOverlay.swift
//  tama
//
//  折りたたみ端末（iPhone Duo）対応の計測用オーバーレイ（DEBUGビルド専用）
//
//  起動引数（UserDefaultsの同名キーでも可）:
//    -DuoMetricsOverlay YES          計測を有効にする（テキストパネルは全項目表示）
//    -DuoMetricsOverlay compact      計測を有効にし、パネルを2行に省略する
//    -DuoMetricsOverlay hidden       計測を有効にし、パネルを出さない（予約領域の枠とログのみ）
//    -DuoMetricsPanel full|compact|hidden
//                                    パネルの表示量を個別に指定する（-DuoMetricsOverlay より優先）
//
//  関連する検証用の起動引数（実装は `ContentView`）:
//    -DuoInitialTab bus|timetable|assignment
//                                    起動時に選ぶタブを指定する。
//                                    `simctl openurl` は確認ダイアログが出てCLIから操作できないため、
//                                    タブごとのスクリーンショットはこの引数で撮る
//
//  いずれの場合もログは同じ内容が出力される（サブシステム: バンドルID、カテゴリ: DuoMetrics）
//

#if DEBUG
import os
import SwiftUI

// MARK: - 公開API

extension View {

    /// 画面サイズ・セーフエリア・予約領域（ReservedRegion）を可視化する計測用オーバーレイを重ねる。
    ///
    /// 起動引数 `-DuoMetricsOverlay YES` （またはUserDefaultsの同名キー）が指定されたときだけ有効になるため、
    /// 通常のデバッグ実行・プレビュー・スクリーンショット撮影には影響しない。
    /// レイアウトを変えないよう、オーバーレイ側ではセーフエリアを無視せず、ヒットテストも行わない
    func duoMetricsOverlay() -> some View {
        modifier(DuoMetricsOverlayModifier())
    }

    /// この位置での計測値（コンテナサイズ・セーフエリア・ウィンドウ内での位置・サイズクラス・
    /// `toolbarVerticalEdge`）を、`label` を付けてログに出力する。
    ///
    /// ルートのオーバーレイはウィンドウ単位の値しか見えないため、`TabView` が自前で付ける余白のように
    /// コンテンツ側にしか現れない差分を捕まえるために使う。
    /// 有効・無効の条件はオーバーレイと同じで、レイアウトにもヒットテストにも影響しない
    func duoMetricsProbe(_ label: String) -> some View {
        modifier(DuoMetricsProbeModifier(label: label))
    }
}

// MARK: - モディファイア

/// 起動引数・UserDefaultsで指定された計測の設定（ファイル先頭のコメントを参照）
private enum DuoMetricsFlags {

    /// テキストパネルの表示量
    enum PanelMode: String {
        case full
        case compact
        case hidden
    }

    private static let overlayValue = UserDefaults.standard.string(forKey: "DuoMetricsOverlay")
    private static let panelValue = UserDefaults.standard.string(forKey: "DuoMetricsPanel")

    /// 計測を有効にするかどうか（真偽値のほか、パネルの表示量を直接指定しても有効になる）
    static let isEnabled: Bool = {
        guard let overlayValue else { return false }
        return (overlayValue as NSString).boolValue || PanelMode(rawValue: overlayValue.lowercased()) != nil
    }()

    /// テキストパネルの表示量（`-DuoMetricsPanel` を優先し、指定がなければ全項目表示）
    static let panelMode: PanelMode = {
        if let panelValue, let mode = PanelMode(rawValue: panelValue.lowercased()) {
            return mode
        }
        if let overlayValue, let mode = PanelMode(rawValue: overlayValue.lowercased()) {
            return mode
        }
        return .full
    }()
}

private struct DuoMetricsOverlayModifier: ViewModifier {

    func body(content: Content) -> some View {
        content.overlay {
            if DuoMetricsFlags.isEnabled {
                DuoMetricsLayer()
            }
        }
    }
}

private struct DuoMetricsProbeModifier: ViewModifier {

    let label: String

    func body(content: Content) -> some View {
        content.background {
            if DuoMetricsFlags.isEnabled {
                DuoMetricsProbeLayer(label: label)
            }
        }
    }
}

// MARK: - プローブ

/// 取り付けた位置の計測値をログに出力するだけの不可視レイヤー
private struct DuoMetricsProbeLayer: View {

    let label: String

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var toolbarEdge = "nil"

    var body: some View {
        GeometryReader { proxy in
            let metrics = DuoProbeMetrics(
                label: label,
                size: proxy.size,
                safeArea: proxy.safeAreaInsets,
                windowFrame: proxy.frame(in: .global),
                horizontalSizeClass: DuoMetricsFormat.name(horizontalSizeClass),
                verticalSizeClass: DuoMetricsFormat.name(verticalSizeClass),
                toolbarVerticalEdge: toolbarEdge
            )

            Color.clear
                .background { toolbarEdgeReader }
                .onChange(of: metrics, initial: true) { _, newValue in
                    DuoMetricsLogger.log(newValue.logLine)
                }
        }
        .allowsHitTesting(false)
    }

    /// toolbarVerticalEdge を読み取るための不可視ビュー（iOS 27.1以降のみ）
    @ViewBuilder
    private var toolbarEdgeReader: some View {
        if #available(iOS 27.1, *) {
            DuoToolbarEdgeReader(edgeName: $toolbarEdge)
        }
    }
}

/// プローブ1回分の計測値
private struct DuoProbeMetrics: Equatable {
    var label: String
    var size: CGSize
    var safeArea: EdgeInsets
    var windowFrame: CGRect
    var horizontalSizeClass: String
    var verticalSizeClass: String
    var toolbarVerticalEdge: String

    /// ログ1行分の文字列
    var logLine: String {
        let frame = "(\(fmt(windowFrame.minX)),\(fmt(windowFrame.minY)) "
            + "\(fmt(windowFrame.width))x\(fmt(windowFrame.height)))"
        return [
            "probe[\(label)]",
            "size \(fmt(size.width))x\(fmt(size.height))",
            "safeArea \(describe(safeArea))",
            "windowFrame\(frame)",
            "sizeClass h:\(horizontalSizeClass) v:\(verticalSizeClass)",
            "toolbarVerticalEdge \(toolbarVerticalEdge)"
        ].joined(separator: " | ")
    }
}

// MARK: - 計測レイヤー

/// 計測値の表示・描画・ログ出力を行うレイヤー
private struct DuoMetricsLayer: View {

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.displayScale) private var displayScale

    @State private var uiKitInsets = DuoUIKitInsets()
    @State private var toolbarEdge = "nil"

    var body: some View {
        GeometryReader { proxy in
            let metrics = makeMetrics(proxy: proxy)

            ZStack(alignment: .bottomLeading) {
                regionShapes(metrics.regions)
                panel(metrics)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .background { DuoUIKitInsetsReader(insets: $uiKitInsets) }
            .background { toolbarEdgeReader }
            .onChange(of: metrics, initial: true) { _, newValue in
                DuoMetricsLogger.log(newValue.logLine)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - サブビュー

    /// 予約領域の枠（遮蔽物＝オレンジ、分割＝シアン。非アクティブは破線かつ淡色）
    @ViewBuilder
    private func regionShapes(_ regions: [DuoRegionInfo]) -> some View {
        ForEach(regions) { region in
            let tint: Color = region.kindName == "occlusion" ? .orange : .cyan
            Rectangle()
                .fill(tint.opacity(region.isActive ? 0.22 : 0.08))
                .overlay {
                    Rectangle()
                        .strokeBorder(
                            tint.opacity(region.isActive ? 0.9 : 0.4),
                            style: StrokeStyle(lineWidth: 1.5, dash: region.isActive ? [] : [4, 4])
                        )
                }
                .frame(width: region.frame.width, height: region.frame.height)
                .position(x: region.frame.midX, y: region.frame.midY)
        }
    }

    /// 計測値のテキストパネル（縦バーに隠れないよう左下に寄せる）。
    /// compactでは2行に省略し、hiddenでは表示しない（スクリーンショットで画面を隠さないため）
    @ViewBuilder
    private func panel(_ metrics: DuoMetrics) -> some View {
        switch DuoMetricsFlags.panelMode {
        case .hidden:
            EmptyView()
        case .compact:
            panelText(metrics.compactSummary)
        case .full:
            panelText(metrics.summary)
        }
    }

    private func panelText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .regular, design: .monospaced))
            .foregroundStyle(.white)
            .padding(6)
            .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 6))
            .padding(8)
    }

    /// toolbarVerticalEdge を読み取るための不可視ビュー（iOS 27.1以降のみ）
    @ViewBuilder
    private var toolbarEdgeReader: some View {
        if #available(iOS 27.1, *) {
            DuoToolbarEdgeReader(edgeName: $toolbarEdge)
        }
    }

    // MARK: - プライベートメソッド

    /// 現在の計測値をまとめる
    private func makeMetrics(proxy: GeometryProxy) -> DuoMetrics {
        DuoMetrics(
            size: proxy.size,
            displayScale: displayScale,
            horizontalSizeClass: DuoMetricsFormat.name(horizontalSizeClass),
            verticalSizeClass: DuoMetricsFormat.name(verticalSizeClass),
            safeArea: proxy.safeAreaInsets,
            uiKitInsets: uiKitInsets,
            toolbarVerticalEdge: toolbarEdge,
            regions: Self.regions(proxy: proxy)
        )
    }

    /// 予約領域（遮蔽物・分割）を非アクティブも含めて取得する
    private static func regions(proxy: GeometryProxy) -> [DuoRegionInfo] {
        guard #available(iOS 27.1, *) else { return [] }

        let occlusions = proxy.reservedRegions(kind: .occlusion, options: .includeInactive)
        let divisions = proxy.reservedRegions(kind: .division, options: .includeInactive)

        return (occlusions.map { ($0, "occlusion") } + divisions.map { ($0, "division") })
            .enumerated()
            .map { index, entry in
                DuoRegionInfo(
                    id: index,
                    kindName: entry.1,
                    frame: entry.0.frame,
                    margins: entry.0.margins,
                    isActive: entry.0.isActive
                )
            }
    }
}

/// 計測値の表示名
private enum DuoMetricsFormat {

    /// サイズクラスの表示名
    static func name(_ sizeClass: UserInterfaceSizeClass?) -> String {
        switch sizeClass {
        case .compact: "compact"
        case .regular: "regular"
        default: "nil"
        }
    }
}

/// `toolbarVerticalEdge` を親へ伝えるだけの不可視ビュー
@available(iOS 27.1, *)
private struct DuoToolbarEdgeReader: View {

    @Environment(\.toolbarVerticalEdge) private var toolbarVerticalEdge
    @Binding var edgeName: String

    var body: some View {
        Color.clear
            .onChange(of: name, initial: true) { _, newValue in
                edgeName = newValue
            }
    }

    private var name: String {
        switch toolbarVerticalEdge {
        case .leading: "leading"
        case .trailing: "trailing"
        default: "nil"
        }
    }
}

// MARK: - UIKit側の余白の読み取り

/// UIKit側のレイアウトマージン・セーフエリアを、自分自身のビュー（とその window）から読み取る
private struct DuoUIKitInsets: Equatable {
    var viewSafeArea: UIEdgeInsets = .zero
    var viewMargins: NSDirectionalEdgeInsets = .zero
    var windowSafeArea: UIEdgeInsets = .zero
    var windowMargins: NSDirectionalEdgeInsets = .zero
}

private struct DuoUIKitInsetsReader: UIViewRepresentable {

    @Binding var insets: DuoUIKitInsets

    func makeUIView(context: Context) -> InsetsProbeView {
        let view = InsetsProbeView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.onUpdate = { newValue in
            // レイアウト中の状態更新を避けるため、次のランループで反映する
            DispatchQueue.main.async {
                if insets != newValue {
                    insets = newValue
                }
            }
        }
        return view
    }

    func updateUIView(_ uiView: InsetsProbeView, context: Context) {}

    /// 自分自身のセーフエリア・レイアウトマージンを通知するプローブ用ビュー
    final class InsetsProbeView: UIView {

        var onUpdate: ((DuoUIKitInsets) -> Void)?

        override func safeAreaInsetsDidChange() {
            super.safeAreaInsetsDidChange()
            report()
        }

        override func layoutMarginsDidChange() {
            super.layoutMarginsDidChange()
            report()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        private func report() {
            onUpdate?(
                DuoUIKitInsets(
                    viewSafeArea: safeAreaInsets,
                    viewMargins: directionalLayoutMargins,
                    windowSafeArea: window?.safeAreaInsets ?? .zero,
                    windowMargins: window?.directionalLayoutMargins ?? .zero
                )
            )
        }
    }
}

// MARK: - 計測値

/// 1回分の計測値
private struct DuoMetrics: Equatable {
    var size: CGSize
    var displayScale: CGFloat
    var horizontalSizeClass: String
    var verticalSizeClass: String
    var safeArea: EdgeInsets
    var uiKitInsets: DuoUIKitInsets
    var toolbarVerticalEdge: String
    var regions: [DuoRegionInfo]
}

/// 予約領域1件分の情報
private struct DuoRegionInfo: Equatable, Identifiable {
    var id: Int
    var kindName: String
    var frame: CGRect
    var margins: EdgeInsets
    var isActive: Bool
}

extension DuoMetrics {

    /// オーバーレイに表示する要約テキスト
    var summary: String {
        var lines = [
            "size \(fmt(size.width))x\(fmt(size.height)) @\(fmt(displayScale))x",
            "sizeClass h:\(horizontalSizeClass) v:\(verticalSizeClass)",
            "safeArea \(describe(safeArea))",
            "viewMargins \(describe(uiKitInsets.viewMargins))",
            "viewSafeArea \(describe(uiKitInsets.viewSafeArea))",
            "winMargins \(describe(uiKitInsets.windowMargins))",
            "winSafeArea \(describe(uiKitInsets.windowSafeArea))",
            "toolbarVerticalEdge \(toolbarVerticalEdge)"
        ]
        if regions.isEmpty {
            lines.append("regions none")
        } else {
            lines.append(contentsOf: regions.map(\.summary))
        }
        return lines.joined(separator: "\n")
    }

    /// パネルを省略表示するときの要約テキスト（2行）
    var compactSummary: String {
        let division = regions.first { $0.kindName == "division" }
        let divisionState = division.map { $0.isActive ? "division active" : "division inactive" }
            ?? "division none"
        return [
            "\(fmt(size.width))x\(fmt(size.height)) h:\(horizontalSizeClass) v:\(verticalSizeClass)",
            "safeArea \(describe(safeArea)) \(divisionState)"
        ].joined(separator: "\n")
    }

    /// ログ1行分の文字列
    var logLine: String {
        summary.replacingOccurrences(of: "\n", with: " | ")
    }
}

extension DuoRegionInfo {

    var summary: String {
        let state = isActive ? "active" : "inactive"
        let rect = "(\(fmt(frame.minX)),\(fmt(frame.minY)) \(fmt(frame.width))x\(fmt(frame.height)))"
        return "\(kindName) \(state) frame\(rect) margins\(describe(margins))"
    }
}

// MARK: - 書式

private func fmt(_ value: CGFloat) -> String {
    String(format: "%.1f", value)
}

private func describe(_ insets: EdgeInsets) -> String {
    "(t\(fmt(insets.top)) l\(fmt(insets.leading)) b\(fmt(insets.bottom)) r\(fmt(insets.trailing)))"
}

private func describe(_ insets: UIEdgeInsets) -> String {
    "(t\(fmt(insets.top)) l\(fmt(insets.left)) b\(fmt(insets.bottom)) r\(fmt(insets.right)))"
}

private func describe(_ insets: NSDirectionalEdgeInsets) -> String {
    "(t\(fmt(insets.top)) l\(fmt(insets.leading)) b\(fmt(insets.bottom)) r\(fmt(insets.trailing)))"
}

// MARK: - ログ

private enum DuoMetricsLogger {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.meikenn.tama",
        category: "DuoMetrics"
    )

    /// 計測値を1行にまとめて出力する（`simctl launch --console-pty` と `log stream` の両方で読めるようにする）
    static func log(_ logLine: String) {
        let line = "[DuoMetrics] \(logLine)"
        print(line)
        logger.log("\(line, privacy: .public)")
    }
}
#endif
