import SwiftUI

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
    @State private var mapQuery: String = "" // マップに渡す検索ワード

    var body: some View {
        ZStack {
            // 背景
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.18),
                        radius: 18, x: 0, y: 10)

            // コンテンツ
            VStack(spacing: 0) {
                // 画像エリア
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .cornerRadius(20)
                    .padding(.top, 10)
                    .padding(.horizontal, 10)

                // 余白 10px
                Color.clear.frame(height: 10)

                // 位置情報ブロック (ここを修正)
                // ★全体をButtonにするのではなく、各要素をButtonにする
                HStack(spacing: 6) {
                    
                    // 1. Country (例: Japan)
                    if !country.isEmpty {
                        Button {
                            openMap(for: country)
                        } label: {
                            pill(country)
                        }
                    }
                    
                    // 2. Region (例: Osaka)
                    // 検索精度を上げるため "Osaka, Japan" のように国名も足すと良い
                    if !region.isEmpty {
                        Button {
                            let query = country.isEmpty ? region : "\(region), \(country)"
                            openMap(for: query)
                        } label: {
                            pill(region)
                        }
                    }
                    
                    // 3. City (例: Osaka City)
                    if !city.isEmpty {
                        Button {
                            // 地域名があればそれも含める
                            var parts: [String] = []
                            parts.append(city)
                            if !region.isEmpty { parts.append(region) }
                            if !country.isEmpty { parts.append(country) }
                            let query = parts.joined(separator: ", ")
                            openMap(for: query)
                        } label: {
                            pill(city)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                // ボタンのスタイルをリセット（青文字になるのを防ぐ）
                .buttonStyle(.plain)

                // 余白 5px
                Color.clear.frame(height: 5)

                // 撮影時間 & いいねボタン
                HStack {
                    Text(dateText)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)

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
                                    
                                    Task {
                                        await PhotoService.shared.sendLike(photoId: photoId)
                                    }
                                    
                                } else {
                                    likedStore.remove(id: photoId)
                                }
                            }
                        )
                    )
                }
                .padding(.horizontal, 16)
                
                // 余白 15px (カード底辺まで)
                Color.clear.frame(height: 15)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .drawingGroup()
        // シート表示
        .sheet(isPresented: $showMap) {
            LocationMapView(searchQuery: mapQuery)
        }
    }
    
    // マップを開くヘルパー
    private func openMap(for query: String) {
        self.mapQuery = query
        self.showMap = true
    }

    // ラベル用ピル（デザイン調整）
    private func pill(_ text: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 17, weight: .semibold))
            // 虫眼鏡アイコンなどを小さく添えても分かりやすいかもしれません
            // Image(systemName: "magnifyingglass").font(.caption2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}
