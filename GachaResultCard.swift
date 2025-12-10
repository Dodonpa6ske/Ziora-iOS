import SwiftUI
import UIKit

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

    @ObservedObject private var likedStore = LikedPhotoStore.shared
    
    // マップ表示用
    @State private var showMap = false
    @State private var mapQuery: String = ""

    var body: some View {
        ZStack {
            // 背景: シンプルな白に戻す
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
                    
                    // 上段: 位置情報タグ（横スクロール）
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            if !country.isEmpty {
                                Button { openMap(for: country) } label: { pill(country) }
                            }
                            if !region.isEmpty {
                                Button {
                                    let query = country.isEmpty ? region : "\(region), \(country)"
                                    openMap(for: query)
                                } label: { pill(region) }
                            }
                            if !city.isEmpty {
                                Button {
                                    var parts: [String] = []
                                    parts.append(city)
                                    if !region.isEmpty { parts.append(region) }
                                    if !country.isEmpty { parts.append(country) }
                                    openMap(for: parts.joined(separator: ", "))
                                } label: { pill(city) }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(.plain)
                    .fixedSize(horizontal: false, vertical: true)
                    // 両端フェード
                    .mask(
                        HStack(spacing: 0) {
                            LinearGradient(gradient: Gradient(colors: [.clear, .black]), startPoint: .leading, endPoint: .trailing).frame(width: 16)
                            Rectangle().fill(Color.black)
                            LinearGradient(gradient: Gradient(colors: [.black, .clear]), startPoint: .leading, endPoint: .trailing).frame(width: 16)
                        }
                    )
                    .padding(.horizontal, -16)

                    
                    // 下段: 撮影日時 + いいねボタン
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
                        
                        // いいねボタン
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
                    // 位置調整
                    .offset(y: -8)
                }
                .padding(.top, 16)
                .padding(.horizontal, 16)
                .padding(.bottom, 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showMap) {
            LocationMapView(searchQuery: mapQuery)
        }
    }
    
    private func openMap(for query: String) {
        self.mapQuery = query
        self.showMap = true
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            // 背景色も元に戻す
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
    }
}
