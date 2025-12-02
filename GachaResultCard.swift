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
            // 背景カード
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.18),
                        radius: 18, x: 0, y: 10)

            // 画像 + テキスト
            VStack(spacing: 0) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: 410)
                    .clipped()
                    .cornerRadius(20)
                    .padding(.top, 10)
                    .padding(.horizontal, 10)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        pill(country)
                        pill(region)
                        pill(city)
                        Spacer()
                    }

                    Text(dateText)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.leading, 12)
                }
                .padding(.top, 10)
                .padding(.bottom, 10)
                .padding(.horizontal, 12)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity,
                   maxHeight: .infinity,
                   alignment: .top)

            // 右下の LikeButton
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    LikeButton(
                        isLiked: Binding(
                            get: { likedStore.isLiked(id: photoId) },
                            set: { newValue in
                                let lp = LikedPhoto(
                                    id: photoId,
                                    image: image,
                                    imagePath: imagePath,
                                    country: country,
                                    region: region,
                                    city: city,
                                    dateText: dateText,
                                    latitude: latitude,
                                    longitude: longitude
                                )
                                likedStore.setLiked(newValue, photo: lp)
                            }
                        )
                    )
                    .padding(.trailing, 15)
                    .padding(.bottom, 15)
                }
            }
            .frame(maxWidth: .infinity,
                   maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity,
               maxHeight: .infinity)
        .drawingGroup()
    }

    // ラベル用ピル
    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(12)
    }
}
