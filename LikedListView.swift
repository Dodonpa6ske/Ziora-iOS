import SwiftUI

// スクロール量を拾うための PreferenceKey
private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct LikedListView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var likedStore = LikedPhotoStore.shared

    @State private var selectedPhoto: LikedPhoto? = nil
    @State private var selectedImage: UIImage? = nil // ★ 追加: 拡大表示用の画像保持
    @State private var cardScale: CGFloat = 0.9
    @State private var scrollOffset: CGFloat = 0

    // 2カラム & サムネイル間隔 8pt
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {

            // 背景は F6F6F6 だけ
            Color.zioraLightBackground
                .ignoresSafeArea()

            // サムネイルリスト本体
            VStack(spacing: 0) {
                // 上の余白（ステータスバー＋少し）
                Spacer().frame(height: 40)

                if likedStore.photos.isEmpty {
                    // いいねゼロのとき
                    Text("No liked photos yet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        // スクロール位置取得
                        GeometryReader { geo in
                            Color.clear
                                .preference(
                                    key: ScrollOffsetPreferenceKey.self,
                                    value: geo.frame(in: .named("likedScroll")).minY
                                )
                        }
                        .frame(height: 0)

                        LazyVGrid(
                            columns: columns,
                            alignment: .center,
                            spacing: 8          // ← サムネイル同士の縦間隔も 8
                        ) {
                            ForEach(
                                Array(likedStore.photos.enumerated()),
                                id: \.element.id
                            ) { index, photo in
                                LikedThumbnailView(
                                    photo: photo,
                                    index: index
                                )
                                .onTapGesture {
                                    // ★ 修正: タップされたらローカルから画像をロードしてセット
                                    selectedImage = LikedPhotoStore.shared.loadLocalImage(for: photo)
                                    selectedPhoto = photo
                                    
                                    cardScale = 0.85
                                    withAnimation(
                                        .interpolatingSpring(
                                            stiffness: 420,
                                            damping: 26
                                        )
                                    ) {
                                        cardScale = 1.0
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                    }
                    .coordinateSpace(name: "likedScroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) {
                        scrollOffset = $0
                    }
                    // 上方向のフェード
                    .overlay(
                        VStack(spacing: 0) {
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: Color.zioraLightBackground,
                                          location: 0),
                                    .init(color: Color.zioraLightBackground
                                        .opacity(0),
                                          location: 1)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 40)
                            .opacity(scrollOffset < -10 ? 1 : 0)

                            Spacer()
                        }
                    )
                }

                // 下の余白
                Spacer().frame(height: 40)
            }

            // 右下のバツボタン
            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.black.opacity(0.07), lineWidth: 2)
                        .background(
                            Circle().fill(Color.white)
                        )
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                }
                .frame(width: 72, height: 72)
            }
            .padding(.trailing, 24)
            .padding(.bottom, 40)

            // 拡大カードのオーバーレイ（画面中央）
            // ★ 修正: photo と image 両方が揃っているときだけ表示
            if let photo = selectedPhoto, let image = selectedImage {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        selectedPhoto = nil
                        selectedImage = nil // クリア
                    }

                VStack {
                    Spacer()
                    GachaResultCard(
                        image: image, // ★ 修正: ここでロードした画像を渡す (photo.image ではない)
                        country: photo.country,
                        region: photo.region,
                        city: photo.city,
                        dateText: photo.dateText,
                        latitude: photo.latitude,
                        longitude: photo.longitude,
                        photoId: photo.id,
                        imagePath: photo.imagePath
                    )
                    .scaleEffect(cardScale)
                    .padding(.horizontal, 16)
                    Spacer()
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
