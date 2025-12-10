import SwiftUI
import UIKit

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

    /// いいね識別用
    let photoId: String
    let imagePath: String
    
    // ★追加: いいね数と、ボタンを表示するかどうかのフラグ
    let likeCount: Int
    var showLikeButton: Bool = true

    @ObservedObject private var likedStore = LikedPhotoStore.shared
    
    @State private var mapDestination: MapDestination?

    var body: some View {
        ZStack {
            // 背景
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.18),
                        radius: 18, x: 0, y: 10)

            // コンテンツ
            VStack(spacing: 0) {
                // 1. 画像エリア
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .cornerRadius(20)
                    .padding(.top, 10)
                    .padding(.horizontal, 10)
                
                // 2. 下部情報エリア
                VStack(alignment: .leading, spacing: 8) {
                    
                    // 上段: 位置情報タグ
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            if !country.isEmpty {
                                Button { openMap(for: country) } label: { pill(country) }
                                    .buttonStyle(LocationPillButtonStyle())
                            }
                            if !region.isEmpty {
                                Button {
                                    let query = [region, country].filter { !$0.isEmpty }.joined(separator: ", ")
                                    openMap(for: query)
                                } label: { pill(region) }
                                    .buttonStyle(LocationPillButtonStyle())
                            }
                            if !city.isEmpty {
                                Button {
                                    let query = [city, region, country].filter { !$0.isEmpty }.joined(separator: ", ")
                                    openMap(for: query)
                                } label: { pill(city) }
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

                    
                    // 下段: 撮影日時 + いいねボタン(または数)
                    HStack(alignment: .center) {
                        
                        // 撮影日時
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text(dateText)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // ★修正: showLikeButton フラグで分岐
                        if showLikeButton {
                            // いいねボタン (他人の写真用)
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
                        } else {
                            // いいね数のみ表示 (自分の写真用: グレー表示で操作不可)
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("\(likeCount)")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.secondary) // グレーにする
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                        }
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
            LocationMapView(searchQuery: destination.query)
        }
    }
    
    private func openMap(for query: String) {
        self.mapDestination = MapDestination(query: query)
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
