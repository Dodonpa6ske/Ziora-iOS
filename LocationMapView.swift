import SwiftUI
import MapKit
import CoreLocation

struct LocationMapView: View {
    // 表示したい場所の名前（例: "Japan", "Osaka, Japan"）
    let searchQuery: String

    @Environment(\.dismiss) var dismiss

    // マップの表示領域（初期値は世界全体を表示）
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 100, longitudeDelta: 100)
    )
    
    // 見つかった場所に立てるピン
    @State private var pinItem: MapPinItem?

    var body: some View {
        NavigationStack {
            ZStack {
                // 地図
                Map(coordinateRegion: $region, annotationItems: pinItem != nil ? [pinItem!] : []) { item in
                    MapMarker(coordinate: item.coordinate, tint: .red)
                }
                .ignoresSafeArea(edges: .bottom)
                
                // 検索中の場合などにインジケータを出しても良いですが、
                // 今回はシンプルにアニメーションのみにします
            }
            .navigationTitle(searchQuery)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // 画面が表示されたら、地名から場所を探して移動する
                searchAndFly(to: searchQuery)
            }
        }
    }
    
    private func searchAndFly(to query: String) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(query) { placemarks, error in
            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                print("Location not found: \(query)")
                return
            }
            
            // 1. ピンの位置を設定
            let coordinate = location.coordinate
            self.pinItem = MapPinItem(lat: coordinate.latitude, lon: coordinate.longitude)
            
            // 2. ズームレベル（表示範囲）を計算
            // 国なら広く、都市なら狭く表示するために placemark.region を活用します
            var spanDelta: Double = 0.5
            
            if let circularRegion = placemark.region as? CLCircularRegion {
                // 半径(m)を度数に概算変換 (1度 ≒ 111km)
                let radiusKm = circularRegion.radius / 1000.0
                // 少し余白を持たせる係数をかける
                spanDelta = (radiusKm / 111.0) * 2.2
                
                // あまりに寄りすぎたり引きすぎたりしないよう制限
                if spanDelta < 0.02 { spanDelta = 0.02 } // 最小ズーム（詳細）
                if spanDelta > 60.0 { spanDelta = 60.0 } // 最大ズーム（広域）
            }
            
            // 3. アニメーションで移動（飛んでいく演出）
            withAnimation(.easeInOut(duration: 2.0)) {
                region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: spanDelta, longitudeDelta: spanDelta)
                )
            }
        }
    }
}

// ピン用モデル（前回のまま）
struct MapPinItem: Identifiable {
    let id = UUID()
    let lat: Double
    let lon: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
