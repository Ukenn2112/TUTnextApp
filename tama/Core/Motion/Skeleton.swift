import SwiftUI

// MARK: - スケルトン表示

extension View {

    /// 読み込み中のスケルトン表示に切り替える。
    ///
    /// - `.redacted(reason: .placeholder)` で文字や画像を塗りつぶしの形に置き換える
    /// - その上から、左から右へ流れるきらめき（不透明度 1 → 0.6 → 1）を**1枚だけ**重ねる。
    ///   ふだんはそのままの濃さで、帯が通るところだけ少し地の色に溶かす（暗くする帯にはしない）。
    ///   行ごとではなく、リストや時間割などの入れ物に1回だけ付けること
    /// - 「視差効果を減らす」が有効なとき、またはアプリが前面にないときはきらめかない（静止）
    /// - 表示中は操作を受け付けず、VoiceOver には中身ではなく「読み込み中...」とだけ読ませる
    ///
    /// 中身のビューの同一性は変えないので、切り替えても子の状態は失われない。
    /// キャッシュからすぐ表示できる可能性があるときは `skeletonDelayed(_:)` を使う
    func skeleton(_ isActive: Bool) -> some View {
        modifier(SkeletonModifier(isActive: isActive))
    }

    /// 読み込みが `Motion.skeletonDelay` より長く続いたときだけスケルトンにする。
    ///
    /// キャッシュからすぐに表示できた場合にスケルトンが一瞬ちらつくのを防ぐ。
    /// 読み込みが終わればすぐに（遅れなしで）元に戻る
    func skeletonDelayed(_ isLoading: Bool) -> some View {
        DelayedSkeletonGate(isLoading: isLoading) { showsSkeleton in
            self.skeleton(showsSkeleton)
        }
    }
}

// MARK: - 遅れて出すための門

/// 読み込みが `Motion.skeletonDelay` より長く続いたときだけ `true` を渡す入れ物。
///
/// スケルトン用の仮の行に差し替えるなど、`skeleton(_:)` 以外の出し分けにも使える。
///
/// ```swift
/// DelayedSkeletonGate(isLoading: viewModel.isLoading) { showsSkeleton in
///     if showsSkeleton { PlaceholderRows().skeleton(true) } else { RealRows() }
/// }
/// ```
struct DelayedSkeletonGate<Content: View>: View {
    let isLoading: Bool
    @ViewBuilder let content: (Bool) -> Content

    @State private var showsSkeleton = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(isLoading: Bool, @ViewBuilder content: @escaping (Bool) -> Content) {
        self.isLoading = isLoading
        self.content = content
    }

    var body: some View {
        content(showsSkeleton)
            .task(id: isLoading) {
                guard isLoading else {
                    if showsSkeleton {
                        withAnimation(Motion.resolved(Motion.quick, reduceMotion: reduceMotion)) {
                            showsSkeleton = false
                        }
                    }
                    return
                }
                try? await Task.sleep(for: Motion.skeletonDelay)
                guard !Task.isCancelled else { return }
                withAnimation(Motion.resolved(Motion.quick, reduceMotion: reduceMotion)) {
                    showsSkeleton = true
                }
            }
    }
}

// MARK: - 本体

private struct SkeletonModifier: ViewModifier {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// きらめきを流すかどうか
    private var sweeps: Bool {
        isActive && !reduceMotion && scenePhase == .active
    }

    func body(content: Content) -> some View {
        content
            .redacted(reason: isActive ? .placeholder : [])
            .mask {
                // 流さないときは素通しの黒。流す部品ごと外すので、繰り返しのアニメーションも残らない
                if sweeps {
                    ShimmerSweep()
                } else {
                    Color.black
                }
            }
            .allowsHitTesting(!isActive)
            .accessibilityHidden(isActive)
            .overlay {
                if isActive {
                    Color.clear
                        .accessibilityElement()
                        .accessibilityLabel(Text("読み込み中..."))
                }
            }
    }
}

/// 左から右へ流れるきらめきのマスク。表示されている間だけ `Motion.shimmer` で動き続ける
private struct ShimmerSweep: View {
    @State private var phase: CGFloat = 0

    /// 帯が通るところの不透明度。
    ///
    /// ふだん（帯の外）は 1 のまま＝塗りもセルの枠もそのままの濃さで、読み込み後の見た目とずれない。
    /// 帯の中だけ中身を少し薄くして地の色に近づける。塗りはもともと薄い
    /// `quaternarySystemFill` なので、明るい外観では白く抜ける光の帯、暗い外観では控えめに沈む帯になり、
    /// どちらでも塊が濃く点滅するようには見えない
    private static let bandOpacity: Double = 0.6

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            // 幅3倍のグラデーションの中央に帯を置き、-2w → 0 まで動かすと
            // 帯の中心が内容の左外（-0.5w）から右外（1.5w）まで通り抜ける
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0.35),
                    .init(color: .black.opacity(Self.bandOpacity), location: 0.5),
                    .init(color: .black, location: 0.65),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width * 3, height: proxy.size.height)
            .offset(x: -2 * width + phase * 2 * width)
        }
        .onAppear {
            withAnimation(Motion.shimmer) {
                phase = 1
            }
        }
    }
}

// MARK: - 任意の形のスケルトン

/// スケルトン用の塗りつぶしブロック。
///
/// `.redacted` では形が出ないもの（時間割のセル・色の帯・アイコンの枠など）の代わりに置く。
/// きらめきは入れ物側の `skeleton(_:)` が1回だけ掛けるので、これ自体は静止した塗りだけ。
/// 塗りはいちばん薄い `quaternarySystemFill`（暗い外観にも合わせて変わる）にして、重い灰色の壁にしない
struct SkeletonBlock: View {
    var width: CGFloat?
    var height: CGFloat?
    var cornerRadius: CGFloat = 6

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(UIColor.quaternarySystemFill))
            .frame(width: width, height: height)
            .accessibilityHidden(true)
    }
}

// MARK: - プレビュー

#Preview("Skeleton") {
    @Previewable @State var isLoading = true

    VStack(alignment: .leading, spacing: 16) {
        Toggle("読み込み中", isOn: $isLoading)

        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<4, id: \.self) { index in
                HStack(spacing: 12) {
                    SkeletonBlock(width: 44, height: 44, cornerRadius: 10)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("情報処理概論 \(index + 1)")
                            .font(.headline)
                        Text("A棟 201教室・第\(index + 1)時限")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .skeleton(isLoading)
    }
    .padding()
}
