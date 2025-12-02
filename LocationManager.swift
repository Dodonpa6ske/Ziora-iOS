import Foundation
import CoreLocation
import Combine

final class LocationManager: NSObject, ObservableObject {

    static let shared = LocationManager()

    /// 直近の生の CLLocation
    @Published var lastLocation: CLLocation?

    /// 直近の地名情報（英語表記）
    @Published var lastPlacemark: CLPlacemark?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// 位置情報の取得をリクエスト
    func requestLocation() {
        let status = manager.authorizationStatus

        switch status {
        case .notDetermined:
            // 初回は許可ダイアログ
            manager.requestWhenInUseAuthorization()

        case .authorizedWhenInUse, .authorizedAlways:
            // 許可済みなら現在地を1回だけ取得
            manager.requestLocation()

        default:
            // 拒否中など。ここで設定アプリへの導線を出してもOK
            break
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }

        // 生の座標を保持
        DispatchQueue.main.async {
            self.lastLocation = loc
        }

        // 英語表記で国名・都市名を取得
        let locale = Locale(identifier: "en_US")
        geocoder.reverseGeocodeLocation(loc, preferredLocale: locale) { [weak self] placemarks, error in
            guard error == nil, let placemark = placemarks?.first else { return }
            DispatchQueue.main.async {
                self?.lastPlacemark = placemark
            }
        }
    }

    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
        print("Location error:", error)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            manager.requestLocation()
        }
    }
}
