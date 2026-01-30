import SwiftUI
import MapKit
import CoreLocation

struct LocationMapView: View {
    // 検索クエリ（Country/Region用）
    let searchQuery: String
    
    // ★追加: 直接指定用の座標とスパン（City用）
    var initialCoordinate: CLLocationCoordinate2D? = nil
    var initialSpan: MKCoordinateSpan? = nil

    @Environment(\.dismiss) var dismiss

    // デフォルト: 世界地図
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 100, longitudeDelta: 100)
    )
    
    @State private var pinItem: MapPinItem?

    var body: some View {
        NavigationStack {
            ZStack {
                Map(coordinateRegion: $region, annotationItems: pinItem != nil ? [pinItem!] : []) { item in
                    MapMarker(coordinate: item.coordinate, tint: .red)
                }
                .ignoresSafeArea(edges: .bottom)
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
                // ★修正: 座標が指定されていれば検索せずに直接移動
                if let coord = initialCoordinate {
                    let span = initialSpan ?? MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    
                    // ピンを立てる
                    self.pinItem = MapPinItem(lat: coord.latitude, lon: coord.longitude)
                    
                    // アニメーションで移動
                    withAnimation(.easeInOut(duration: 1.5)) {
                        region = MKCoordinateRegion(center: coord, span: span)
                    }
                } else {
                    // 従来通り検索を実行
                    searchAndFly(to: searchQuery)
                }
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
            
            let coordinate = location.coordinate
            self.pinItem = MapPinItem(lat: coordinate.latitude, lon: coordinate.longitude)
            
            var spanDelta: Double = 0.5
            if let circularRegion = placemark.region as? CLCircularRegion {
                let radiusKm = circularRegion.radius / 1000.0
                spanDelta = (radiusKm / 111.0) * 2.2
                if spanDelta < 0.02 { spanDelta = 0.02 }
                if spanDelta > 60.0 { spanDelta = 60.0 }
            }
            
            withAnimation(.easeInOut(duration: 2.0)) {
                region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: spanDelta, longitudeDelta: spanDelta)
                )
            }
        }
    }
}

// ピン用モデル
struct MapPinItem: Identifiable {
    let id = UUID()
    let lat: Double
    let lon: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
