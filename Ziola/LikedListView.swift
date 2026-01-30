import SwiftUI
import CoreLocation

// スクロール量を拾うための PreferenceKey
private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// 画像とメタデータをセットで保持する構造体
struct LikedPhotoItem: Identifiable {
    let id: String
    let photo: LikedPhoto
    let image: UIImage
}

// サムネイルビュー
struct LikedThumbnailView: View {
    let item: LikedPhotoItem
    let index: Int

    @State private var isVisible = false

    var body: some View {
        Image(uiImage: item.image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipped()
            .cornerRadius(20)
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 40)
            .onAppear {
                guard !isVisible else { return }
                withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(Double(index) * 0.12)) {
                    isVisible = true
                }
            }
    }
}

struct LikedListView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var likedStore = LikedPhotoStore.shared

    @State private var items: [LikedPhotoItem] = []
    @State private var isLoading = true

    @State private var selectedPhoto: LikedPhoto? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var cardScale: CGFloat = 0.9
    @State private var scrollOffset: CGFloat = 0
    
    // ★追加: 詳細表示用の動的ローカライズ変数
    @State private var displayCountry: String = ""
    @State private var displayRegion: String = ""
    @State private var displayCity: String = ""
    @State private var displaySubLocality: String? = nil

    // ★追加: 言語設定とヘパー
    @AppStorage("selectedLanguage") private var language: String = "en"
    private func localized(_ key: String) -> String {
        if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
        }
        return key
    }

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {

            Color.zioraLightBackground.ignoresSafeArea()
            
            // 1. メインコンテンツ (リスト)
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if items.isEmpty {
                Text(localized("No liked photos yet"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    GeometryReader { geo in
                        Color.clear.preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .named("likedScroll")).minY)
                    }.frame(height: 0)

                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            LikedThumbnailView(item: item, index: index)
                                .onTapGesture {
                                    // 詳細表示トランジション
                                    var transaction = Transaction()
                                    transaction.disablesAnimations = true
                                    withTransaction(transaction) {
                                        // 座標変換用の情報セット
                                        self.selectedImage = item.image
                                        self.cardScale = 0.85 // 初期スケール
                                        
                                        // ローカライズ
                                        if let lat = item.photo.latitude, let lon = item.photo.longitude {
                                            displayCountry = item.photo.country // 初期値
                                            displayRegion = item.photo.region
                                            displayCity = item.photo.city
                                            displaySubLocality = item.photo.subLocality
                                            
                                            Task {
                                                let (c, r, city, sub) = await PhotoService.shared.localizeLocation(latitude: lat, longitude: lon)
                                                await MainActor.run {
                                                    if let c = c { displayCountry = c }
                                                    if let r = r { displayRegion = r }
                                                    if let city = city { displayCity = city }
                                                    if let sub = sub { displaySubLocality = sub }
                                                }
                                            }
                                        }
                                        
                                        self.selectedPhoto = item.photo // これでトリガー
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 40) // 開始位置を調整
                    .padding(.bottom, 120)
                }
                .coordinateSpace(name: "likedScroll")
                .ignoresSafeArea() // ★全画面化
                .scrollDisabled(selectedPhoto != nil)
            }
            
            // ★追加: 上下のプログレッシブブラー (すりガラス)
            VStack(spacing: 0) {
                // 上部
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask(
                        LinearGradient(gradient: Gradient(colors: [.black.opacity(0.8), .black.opacity(0)]), startPoint: .top, endPoint: .bottom)
                    )
                    .frame(height: 50) // 幅を狭める
                    .ignoresSafeArea(edges: .top)

                Spacer()

                // 下部
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask(
                        LinearGradient(gradient: Gradient(colors: [.black.opacity(0), .black]), startPoint: .top, endPoint: .bottom)
                    )
                    .frame(height: 200) // 高さを上げて底切れを防ぐ
                    .ignoresSafeArea(edges: .bottom)
                    .offset(y: 50) // ★修正: 画面外へ少し押し下げる
            }
            .allowsHitTesting(false)

            // 閉じるボタン
            LiquidGlassCloseButton { dismiss() }
            .padding(.trailing, 33)
            .padding(.bottom, 50)
            .opacity(selectedPhoto == nil ? 1 : 0)

            // --- 詳細オーバーレイ (SentListViewの構造を完全コピー) ---
            if let photo = selectedPhoto, let image = selectedImage {
                ZStack {
                    // 背景 (SentListと同じ easeInOut 0.2s)
                    Color.black.opacity(0.3)
                        .ignoresSafeArea().zIndex(1)
                        .onTapGesture {
                            // 閉じるアニメーション (SentListと同じ easeOut 0.2s)
                            withAnimation(.easeOut(duration: 0.2)) {
                                selectedPhoto = nil
                                selectedImage = nil
                            }
                        }
                        .transition(.opacity.animation(.easeInOut(duration: 0.2)))

                    // カード本体
                    VStack(spacing: 0) {
                        Spacer()
                            GachaResultCard(
                                image: image,
                                country: displayCountry, // ★修正: 動的変数を使用
                                region: displayRegion,   // ★修正
                                city: displayCity,       // ★修正
                                subLocality: displaySubLocality, // ★修正
                                dateText: photo.dateText,
                                latitude: photo.latitude,
                                longitude: photo.longitude,
                                photoId: photo.id,
                                imagePath: photo.imagePath,
                            likeCount: 0,
                            showLikeButton: true,
                            likerCountry: LocationManager.shared.lastPlacemark?.country ?? localized("Unknown"), // ★追加: 自分の現在地
                            likerCountryCode: LocationManager.shared.lastPlacemark?.isoCountryCode // ★追加: 自分の国コード
                        )
                        .frame(height: 520)
                        // カード幅を画面幅基準で固定 (SentListと同じ)
                        .frame(width: UIScreen.main.bounds.width - 48)
                        .scaleEffect(cardScale)
                        .onAppear { withAnimation(.interpolatingSpring(stiffness: 420, damping: 26)) { cardScale = 1.0 } }
                        Spacer()
                    }
                    .zIndex(2)
                    // トランジション (SentListと同じ opacity 0.15s)
                    .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                }
            }
        }
        .task {
            await loadImages()
            await validatePhotos()
        }
        .onChange(of: likedStore.photos) { newPhotos in
            syncItems(with: newPhotos)
        }
    }

    private func loadImages() async {
        if items.isEmpty { isLoading = true }
        defer { isLoading = false }
        
        let photos = likedStore.photos
        var loadedItems: [LikedPhotoItem] = []

        await withTaskGroup(of: LikedPhotoItem?.self) { group in
            for photo in photos {
                group.addTask {
                    if let image = await LikedPhotoStore.shared.loadLocalImage(for: photo) {
                        return LikedPhotoItem(id: photo.id, photo: photo, image: image)
                    }
                    return nil
                }
            }
            for await item in group { if let item = item { loadedItems.append(item) } }
        }
        
        let orderMap = Dictionary(uniqueKeysWithValues: photos.enumerated().map { ($0.element.id, $0.offset) })
        loadedItems.sort { (orderMap[$0.id] ?? 0) < (orderMap[$1.id] ?? 0) }

        await MainActor.run { self.items = loadedItems }
    }

    private func validatePhotos() async {
        let currentIds = items.map { $0.id }
        guard !currentIds.isEmpty else { return }
        let validIds = await PhotoService.shared.validateExistence(ids: currentIds)
        let validIdSet = Set(validIds)
        let deletedIds = currentIds.filter { !validIdSet.contains($0) }
        if !deletedIds.isEmpty {
            await MainActor.run { for id in deletedIds { likedStore.remove(id: id) } }
        }
    }
    
    private func syncItems(with newPhotos: [LikedPhoto]) {
        let newIds = Set(newPhotos.map { $0.id })
        if let selected = selectedPhoto, !newIds.contains(selected.id) {
            // 同期による削除時は違和感がないようSentListと同じ設定で閉じる
            withAnimation(.easeOut(duration: 0.2)) {
                selectedPhoto = nil
                selectedImage = nil
            }
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { items.removeAll { !newIds.contains($0.id) } }
    }
}
