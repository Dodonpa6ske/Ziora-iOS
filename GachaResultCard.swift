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

    var body: some View {
        ZStack {
            // 背景: シンプルな白に戻しました（グラデーション削除）
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

                // 位置情報ブロック
                HStack(spacing: 6) {
                    pill(country)
                    pill(region)
                    pill(city)
                    Spacer()
                }
                .padding(.horizontal, 16)

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
                                                        // 1. ローカル保存（既存の処理）
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
                                                        
                                                        // 2. ★追加: サーバーへ送信（通知のトリガー）
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
    }

    // ラベル用ピル
    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            // 背景が白になったので、タグが見えるように薄いグレーに戻しました
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
    }
}
