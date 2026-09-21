import CoreLocation
import Foundation

// MARK: - 学内かどうかの判定

/// 学校の敷地（半径400m）の中に居るかどうかを、アプリの中で一箇所だけ持つサービス。
///
/// 元々はバスタブの `BusScheduleViewModel` が自前で `CLLocationManager` とジオフェンスを持っていたが、
/// 時間割タブの「今日」ペインも同じ判定（＝もう学校に着いているか）を使うため、ここへ集約した。
/// 使う側は `start()` / `stop()` で参照数を増減させるだけでよく、複数の画面が同時に使っても
/// `CLLocationManager` は1つしか作らない。
///
/// - 権限は「使用中のみ」。バックグラウンドの位置情報は使わない
/// - 許可を求めるのは、実際に使う画面が現れたとき（`start()`）だけ
/// - 許可されていない・まだ位置が分からない間は `isOnCampus` は nil のままで、
///   使う側は時刻だけで動く作りにしておくこと
@MainActor
final class CampusPresenceService: NSObject, ObservableObject {

    // MARK: - 公開プロパティ

    static let shared = CampusPresenceService()

    /// 学内に居るか（nil＝まだ分からない／許可されていない）
    @Published private(set) var isOnCampus: Bool?

    // MARK: - 定数

    /// 学校の位置（バスタブが以前から使っていた値をそのまま移した）。
    ///
    /// この3つの定数は `CLLocationManagerDelegate` の `nonisolated` な通知からも読むため、
    /// `nonisolated` にして（型の `@MainActor` から外して）おく。
    /// 変わらない値なので、どのスレッドから読んでも安全（Swift 6 でも警告にならない）
    private nonisolated static let schoolLatitude: CLLocationDegrees = 35.630604
    private nonisolated static let schoolLongitude: CLLocationDegrees = 139.464382

    /// 学内と見なす半径（m）
    private nonisolated static let geofenceRadius: CLLocationDistance = 400

    /// ジオフェンスの識別子
    private nonisolated static let regionIdentifier = "SchoolArea"

    /// 学校の位置（座標そのもの）
    private nonisolated static var schoolLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: schoolLatitude, longitude: schoolLongitude)
    }

    // MARK: - プライベートプロパティ

    private var locationManager: CLLocationManager?

    /// この判定を使っている画面の数（0になったら位置情報の更新を止める）
    private var useCount = 0

    private override init() {
        super.init()
    }

    // MARK: - 開始と終了

    /// 位置情報の利用を開始する（必要なら「使用中のみ」の許可を求める）。
    /// 使い終わったら必ず `stop()` を呼ぶこと
    func start() {
        useCount += 1
        guard useCount == 1 else { return }

        let manager = locationManager ?? CLLocationManager()
        locationManager = manager
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        setupGeofence(on: manager)
        manager.startUpdatingLocation()
    }

    /// 位置情報の利用を終了する（最後の利用者が居なくなったときだけ実際に止める）
    func stop() {
        useCount = max(0, useCount - 1)
        guard useCount == 0, let manager = locationManager else { return }

        manager.stopUpdatingLocation()
        manager.monitoredRegions.forEach { manager.stopMonitoring(for: $0) }
        manager.delegate = nil
        locationManager = nil
    }

    // MARK: - プライベートメソッド

    private func setupGeofence(on manager: CLLocationManager) {
        manager.monitoredRegions.forEach { region in
            if region is CLCircularRegion {
                manager.stopMonitoring(for: region)
            }
        }

        let region = CLCircularRegion(
            center: Self.schoolLocation,
            radius: Self.geofenceRadius,
            identifier: Self.regionIdentifier
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        manager.startMonitoring(for: region)
    }

    /// 測位した位置から学内かどうかを決める
    private func apply(location: CLLocation) {
        let center = CLLocation(
            latitude: Self.schoolLatitude, longitude: Self.schoolLongitude)
        apply(isOnCampus: location.distance(from: center) <= Self.geofenceRadius)
    }

    private func apply(isOnCampus newValue: Bool) {
        guard self.isOnCampus != newValue else { return }
        self.isOnCampus = newValue
    }
}

// MARK: - CLLocationManagerDelegate

extension CampusPresenceService: CLLocationManagerDelegate {

    nonisolated func locationManager(
        _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }
        Task { @MainActor in self.apply(location: location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region.identifier == Self.regionIdentifier else { return }
        Task { @MainActor in self.apply(isOnCampus: true) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == Self.regionIdentifier else { return }
        Task { @MainActor in self.apply(isOnCampus: false) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            if let location = manager.location {
                Task { @MainActor in self.apply(location: location) }
            }
        case .denied, .restricted:
            print("CampusPresenceService: 位置情報の使用が拒否または制限されました")
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let error = error as? CLError {
            switch error.code {
            case .denied:
                print("CampusPresenceService: 位置情報の使用が拒否されました")
            case .network:
                print("CampusPresenceService: 位置情報の取得中にネットワークエラーが発生しました")
            case .locationUnknown:
                print("CampusPresenceService: 位置を特定できません")
            default:
                print("CampusPresenceService: 位置情報の取得に失敗しました: \(error.localizedDescription)")
            }
        } else {
            print("CampusPresenceService: 位置情報の取得に失敗しました: \(error.localizedDescription)")
        }
    }
}
