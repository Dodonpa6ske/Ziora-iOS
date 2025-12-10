import SwiftUI

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

// アニメーション修正済みのサムネイルビュー
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
            // アニメーション設定
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 40)
            .onAppear {
                guard !isVisible else { return }
                withAnimation(
                    .spring(response: 0.55, dampingFraction: 0.85)
                        .delay(Double(index) * 0.12)
                ) {
                    isVisible = true
                }
            }
    }
}

struct LikedListView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var likedStore = LikedPhotoStore.shared

    // 事前ロードしたアイテムを保持する配列
    @State private var items: [LikedPhotoItem] = []
    @State private var isLoading = true

    @State private var selectedPhoto: LikedPhoto? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var cardScale: CGFloat = 0.9
    @State private var scrollOffset: CGFloat = 0

    // 2カラム & サムネイル間隔 8pt
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {

            // 背景
            Color.zioraLightBackground
                .ignoresSafeArea()

            // サムネイルリスト本体
            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if items.isEmpty {
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
                            spacing: 8
                        ) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                LikedThumbnailView(
                                    item: item,
                                    index: index
                                )
                                .onTapGesture {
                                    selectedImage = item.image
                                    selectedPhoto = item.photo
                                    
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

                Spacer().frame(height: 40)
            }

            // 右下のバツボタン（ホーム画面と位置・サイズを統一）
            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                    Circle()
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 24, weight: .semibold)) // 24pt
                        .foregroundColor(.black)
                }
                .frame(width: 60, height: 60) // 60pt
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 0)
            }
            .padding(.trailing, 33) // 右端から33pt (HomeViewと統一)
            .padding(.bottom, 40)

            // 拡大カードのオーバーレイ
            if let photo = selectedPhoto, let image = selectedImage {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            selectedPhoto = nil
                            selectedImage = nil
                        }
                    }

                VStack {
                    Spacer()
                    GachaResultCard(
                        image: image,
                        country: photo.country,
                        region: photo.region,
                        city: photo.city,
                        dateText: photo.dateText,
                        latitude: photo.latitude,
                        longitude: photo.longitude,
                        photoId: photo.id,
                        imagePath: photo.imagePath
                    )
                    .frame(height: 520)
                    .scaleEffect(cardScale)
                    .padding(.horizontal, 24)
                    Spacer()
                }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        // .ignoresSafeArea(edges: .bottom) を削除してセーフエリア準拠にする
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
                    if let image = LikedPhotoStore.shared.loadLocalImage(for: photo) {
                        return LikedPhotoItem(id: photo.id, photo: photo, image: image)
                    }
                    return nil
                }
            }
            
            for await item in group {
                if let item = item {
                    loadedItems.append(item)
                }
            }
        }
        
        let orderMap = Dictionary(uniqueKeysWithValues: photos.enumerated().map { ($0.element.id, $0.offset) })
        loadedItems.sort { (orderMap[$0.id] ?? 0) < (orderMap[$1.id] ?? 0) }

        await MainActor.run {
            self.items = loadedItems
        }
    }

    private func validatePhotos() async {
        let currentIds = items.map { $0.id }
        guard !currentIds.isEmpty else { return }
        
        let validIds = await PhotoService.shared.validateExistence(ids: currentIds)
        let validIdSet = Set(validIds)
        let deletedIds = currentIds.filter { !validIdSet.contains($0) }
        
        if !deletedIds.isEmpty {
            await MainActor.run {
                for id in deletedIds {
                    likedStore.remove(id: id)
                }
            }
        }
    }
    
    private func syncItems(with newPhotos: [LikedPhoto]) {
        let newIds = Set(newPhotos.map { $0.id })
        
        if let selected = selectedPhoto, !newIds.contains(selected.id) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedPhoto = nil
                selectedImage = nil
            }
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            items.removeAll { !newIds.contains($0.id) }
        }
    }
}
