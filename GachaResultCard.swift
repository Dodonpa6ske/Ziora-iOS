import SwiftUI
import UIKit
import MapKit // MKCoordinateSpanのために必要

// MARK: - Custom Button Style (沈み込み + ハプティクス)

struct LocationPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
    }
}

// MARK: - Map Destination Model
struct MapDestination: Identifiable {
    let id = UUID()
    let query: String
    // ★追加: 直接座標指定用
    var coordinate: CLLocationCoordinate2D? = nil
    var span: MKCoordinateSpan? = nil
}

// MARK: - Main Card View

struct GachaResultCard: View {
    let image: UIImage
    let country: String
    let region: String
    let city: String
    let dateText: String
    let latitude: Double?
    let longitude: Double?

    let photoId: String
    let imagePath: String

    @ObservedObject private var likedStore = LikedPhotoStore.shared
    
    @State private var mapDestination: MapDestination?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.18),
                        radius: 18, x: 0, y: 10)

            VStack(spacing: 0) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .cornerRadius(20)
                    .padding(.top, 10)
                    .padding(.horizontal, 10)
                
                VStack(alignment: .leading, spacing: 8) {
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            
                            // Country Button (地名検索)
                            if !country.isEmpty {
                                Button {
                                    openMap(for: country)
                                } label: {
                                    pill(country)
                                }
                                .buttonStyle(LocationPillButtonStyle())
                            }
                            
                            // Region Button (地名検索)
                            if !region.isEmpty {
                                Button {
                                    let query = [region, country].filter { !$0.isEmpty }.joined(separator: ", ")
                                    openMap(for: query)
                                } label: {
                                    pill(region)
                                }
                                .buttonStyle(LocationPillButtonStyle())
                            }
                            
                            // City Button (★修正: 座標への直接ジャンプ)
                            if !city.isEmpty {
                                Button {
                                    if let lat = latitude, let lon = longitude {
                                        // 座標がある場合は直接その場所へ (ズームレベル 0.05 程度)
                                        openMapWithCoordinate(
                                            name: city,
                                            coord: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                        )
                                    } else {
                                        // 座標がない場合のフォールバック（地名検索）
                                        let query = [city, region, country].filter { !$0.isEmpty }.joined(separator: ", ")
                                        openMap(for: query)
                                    }
                                } label: {
                                    pill(city)
                                }
                                .buttonStyle(LocationPillButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .mask(
                        HStack(spacing: 0) {
                            LinearGradient(gradient: Gradient(colors: [.clear, .black]), startPoint: .leading, endPoint: .trailing).frame(width: 16)
                            Rectangle().fill(Color.black)
                            LinearGradient(gradient: Gradient(colors: [.black, .clear]), startPoint: .leading, endPoint: .trailing).frame(width: 16)
                        }
                    )
                    .padding(.horizontal, -16)

                    
                    HStack(alignment: .center) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text(dateText)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        LikeButton(
                            isLiked: Binding(
                                get: { likedStore.isLiked(id: photoId) },
                                set: { newValue in
                                    if newValue {
                                        let lp = LikedPhoto(
                                            id: photoId,
                                            imagePath: imagePath,
                                            country: country,
                                            region: region,
                                            city: city,
                                            dateText: dateText,
                                            latitude: latitude,
                                            longitude: longitude
                                        )
                                        likedStore.add(photo: lp, image: image)
                                        Task { await PhotoService.shared.sendLike(photoId: photoId) }
                                    } else {
                                        likedStore.remove(id: photoId)
                                    }
                                }
                            )
                        )
                    }
                    .offset(y: -8)
                }
                .padding(.top, 16)
                .padding(.horizontal, 16)
                .padding(.bottom, 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: $mapDestination) { destination in
            LocationMapView(
                searchQuery: destination.query,
                initialCoordinate: destination.coordinate, // 座標渡し
                initialSpan: destination.span              // ズームレベル渡し
            )
        }
    }
    
    // 地名検索で開く
    private func openMap(for query: String) {
        print("🗺️ Opening map by query: \(query)")
        self.mapDestination = MapDestination(query: query)
    }
    
    // ★追加: 座標指定で開く
    private func openMapWithCoordinate(name: String, coord: CLLocationCoordinate2D, span: MKCoordinateSpan) {
        print("📍 Opening map by coordinate: \(coord.latitude), \(coord.longitude)")
        self.mapDestination = MapDestination(query: name, coordinate: coord, span: span)
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
    }
}
