import SwiftUI

// MARK: - スケルトン表示

extension View {

    /// 読み込み中のスケルトン表示に切り替える。
    ///
    /// - `.redacted(reason: .placeholder)` で文字や画像を塗りつぶしの形に置き換え、
    ///   中身全体を `contentOpacity`（既定 0.5）まで薄くして、灰色の棒をごく淡くする
    /// - その上から、左から右へ流れる淡い光の帯を**1枚だけ**重ねる。帯は中身の形の内側だけを
    ///   明るくする（暗くすることはない）。行ごとではなく、リストや時間割などの入れ物に1回だけ付けること
    /// - 「視差効果を減らす」が有効なとき、またはアプリが前面にないときはきらめかない（静止）
    /// - 表示中は操作を受け付けず、VoiceOver には中身ではなく「読み込み中...」とだけ読ませる
    ///
    /// 中身のビューの同一性は変えないので、切り替えても子の状態は失われない。
    /// 表示中でないときは薄めも帯も掛けないので、本物の中身の見た目は変わらない。
    /// キャッシュからすぐ表示できる可能性があるときは `skeletonDelayed(_:)` を使う
    ///
    /// - Parameter contentOpacity: 表示中の中身の不透明度。時間割のように「読み込み後と同じ形」を
    ///   そのまま出したいときは 1 にする
    func skeleton(_ isActive: Bool, contentOpacity: Double = SkeletonStyle.contentOpacity) -> some View {
        modifier(SkeletonModifier(isActive: isActive, contentOpacity: contentOpacity))
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

// MARK: - 見た目の値

/// スケルトンの濃さ。どれも `Color.primary` 基準なので、暗い外観でも自然に反転する
enum SkeletonStyle {
    /// 表示中の中身（`.redacted` の灰色の棒など）の不透明度
    static let contentOpacity: Double = 0.5
    /// `SkeletonBlock` の塗りの濃さ（`Color.primary` に対する不透明度）
    static let blockFillOpacity: Double = 0.05
    /// きらめきの帯の中心の白の不透明度（明るい外観）
    static let shimmerOpacityLight: Double = 0.5
    /// きらめきの帯の中心の白の不透明度（暗い外観）
    static let shimmerOpacityDark: Double = 0.08
}

private extension EnvironmentValues {
    /// 外側の `skeleton(_:)` が中身に掛けている不透明度（`SkeletonBlock` が打ち消すのに使う）
    @Entry var skeletonContentOpacity: Double = 1
}

// MARK: - 本体

private struct SkeletonModifier: ViewModifier {
    let isActive: Bool
    let contentOpacity: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// きらめきを流すかどうか
    private var sweeps: Bool {
        isActive && !reduceMotion && scenePhase == .active
    }

    private var appliedOpacity: Double {
        isActive ? contentOpacity : 1
    }

    func body(content: Content) -> some View {
        content
            .redacted(reason: isActive ? .placeholder : [])
            .environment(\.skeletonContentOpacity, appliedOpacity)
            .opacity(appliedOpacity)
            .overlay {
                // 流さないときは部品ごと外すので、繰り返しのアニメーションも残らない。
                // `sourceAtop` で中身が描かれているところにだけ光を乗せる（形の外にははみ出さない）
                if sweeps {
                    ShimmerSweep()
                        .blendMode(.sourceAtop)
                        .allowsHitTesting(false)
                }
            }
            .compositingGroup()
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

/// 左から右へ流れる淡い光の帯。表示されている間だけ `Motion.shimmer` で動き続ける。
///
/// 白から透明へのグラデーションを重ねるだけなので、帯の外は元の見た目のまま、帯の中は少し明るくなるだけで、
/// 暗くなることはない
private struct ShimmerSweep: View {
    @State private var phase: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme

    private var bandOpacity: Double {
        colorScheme == .dark ? SkeletonStyle.shimmerOpacityDark : SkeletonStyle.shimmerOpacityLight
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            // 幅3倍のグラデーションの中央に帯を置き、-2w → 0 まで動かすと
            // 帯の中心が内容の左外（-0.5w）から右外（1.5w）まで通り抜ける
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0), location: 0.35),
                    .init(color: .white.opacity(bandOpacity), location: 0.5),
                    .init(color: .white.opacity(0), location: 0.65),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width * 3, height: proxy.size.height)
            .offset(x: -2 * width + phase * 2 * width)
        }
        .accessibilityHidden(true)
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
/// `.redacted` では形が出ないもの（色の帯・アイコンの枠など）の代わりに置く。
/// きらめきは入れ物側の `skeleton(_:)` が1回だけ掛けるので、これ自体は静止した塗りだけ。
/// 塗りは `Color.primary` の 5%（暗い外観では白の 5%）。入れ物が中身を薄めていても、
/// その分を打ち消して見た目の濃さは 5% に揃える
struct SkeletonBlock: View {
    var width: CGFloat?
    var height: CGFloat?
    var cornerRadius: CGFloat = 6

    @Environment(\.skeletonContentOpacity) private var containerOpacity

    private var fillOpacity: Double {
        min(1, SkeletonStyle.blockFillOpacity / max(containerOpacity, 0.01))
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.primary.opacity(fillOpacity))
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
