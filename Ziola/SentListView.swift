import SwiftUI
import FirebaseAuth
import UIKit
import FirebaseFirestore

// MARK: - Models

struct SentPhoto: Identifiable, Hashable {
    let id: String
    let document: PhotoDocument
    let image: UIImage

    static func == (lhs: SentPhoto, rhs: SentPhoto) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Subviews

struct SentThumbnailView: View {
    let photo: SentPhoto
    let index: Int
    let onTap: () -> Void
    @State private var appeared = false

    var body: some View {
        Image(uiImage: photo.image)
            .resizable().scaledToFill()
            .frame(height: 220)
            .cornerRadius(20)
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 8) { // Spacing between Like and Impression groups
                    // Like Count
                    if photo.document.likeCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill").font(.system(size: 11, weight: .semibold))
                            Text("\(photo.document.likeCount)").font(.system(size: 11, weight: .semibold))
                        }
                    }
                    
                    // Impression Count (Show if > 0)
                    if photo.document.impressionCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "eye.fill").font(.system(size: 11, weight: .semibold))
                            Text("\(photo.document.impressionCount)").font(.system(size: 11, weight: .semibold))
                        }
                    }
                }
                // 背景はどちらか片方でも表示されていれば適用
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background((photo.document.likeCount > 0 || photo.document.impressionCount > 0) ? Color.black.opacity(0.55) : Color.clear)
                .foregroundColor(.white)
                .cornerRadius(12).padding(8)
            }
            .offset(y: appeared ? 0 : 40).opacity(appeared ? 1 : 0)
            .onAppear {
                if !appeared { withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(Double(index % 20) * 0.05)) { appeared = true } }
            }
            .onTapGesture { onTap() }
    }
}

// MARK: - Main View

struct SentListView: View {
    @Environment(\.dismiss) private var dismiss
    
    // ★追加: 通知から飛んできた場合のID
    var highlightId: String?

    @State private var photos: [SentPhoto] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastSnapshot: DocumentSnapshot? = nil
    @State private var isFinished = false

    @State private var selectedPhoto: SentPhoto?
    @State private var cardScale: CGFloat = 0.85
    
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

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    // ★追加: 該当IDがあれば自動で開く (リストにない場合は取得して開く)
    private func checkHighlight() {
        guard let targetId = highlightId, selectedPhoto == nil else { return }
        
        if let match = photos.first(where: { $0.id == targetId }) {
            // リストにある場合
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                openDetail(photo: match)
            }
        } else {
            // リストにない場合、個別に取得を試みる
            Task {
                do {
                    if let doc = try await PhotoService.shared.fetchPhoto(photoId: targetId) {
                        // 画像も取得
                        let image = try await PhotoService.shared.downloadThumbnail(originalPath: doc.imagePath)
                        let item = SentPhoto(id: doc.id, document: doc, image: image)
                        
                        await MainActor.run {
                            // リストに追加して開く (重複チェック)
                            if !self.photos.contains(where: { $0.id == targetId }) {
                                self.photos.append(item)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                openDetail(photo: item)
                            }
                        }
                    }
                } catch {
                    print("DeepLink Error: \(error)")
                }
            }
        }
    }

    var body: some View {
        // ★修正: 完全な全画面ZStack構造に移行
        ZStack(alignment: .bottomLeading) {
            Color.zioraLightBackground.ignoresSafeArea()

            // 1. メインコンテンツ (リスト)
            if isLoading && photos.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if photos.isEmpty && isFinished {
                Text(localized("No uploaded photos yet"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(Array(photos.enumerated()), id: \.element.id) { index, item in
                            SentThumbnailView(photo: item, index: index) { openDetail(photo: item) }
                                .onAppear { if index >= photos.count - 4 { Task { await loadPhotos() } } }
                        }
                    }
                    .padding(.horizontal, 16)
                    // ★重要: 上下のSafe Area分 + グラデーション分の余白を確保
                    .padding(.top, 40) // 開始位置をさらに調整 (50 -> 40)
                    .padding(.bottom, 120)
                }
                .ignoresSafeArea() // ★修正: ScrollViewも全画面に広げる
                .scrollDisabled(selectedPhoto != nil)
                .onChange(of: photos) { _ in checkHighlight() }
            }
            
            // ★追加: 上下のプログレッシブブラー (すりガラス)
            VStack(spacing: 0) {
                // 上部
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask(
                        LinearGradient(gradient: Gradient(colors: [.black, .black.opacity(0)]), startPoint: .top, endPoint: .bottom)
                    )
                    .frame(height: 50)
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
                    .offset(y: 50) // ★修正: 画面外へ少し押し下げる (200だと消えてしまうため50に戻す)
            }
            .allowsHitTesting(false)

            // 3. 閉じるボタン
            LiquidGlassCloseButton { dismiss() }
            .padding(.leading, 33)
            .padding(.bottom, 90)
            .opacity(selectedPhoto == nil ? 1 : 0)
            .animation(.easeOut(duration: 0.2), value: selectedPhoto == nil)
            .animation(.easeOut(duration: 0.2), value: selectedPhoto == nil)

            // 4. エラー表示
            if let error = errorMessage {
                VStack {
                    Spacer()
                    Text(String(format: localized("Error: %@"), error))
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(10)
                        .padding(.bottom, 100)
                        .onTapGesture { errorMessage = nil }
                }.zIndex(4)
            }

            // 5. 詳細オーバーレイ
            if let item = selectedPhoto {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea().zIndex(1)
                        .onTapGesture { closeDetail() }
                        .transition(.opacity.animation(.easeInOut(duration: 0.2)))

                    VStack(spacing: 0) {
                        Spacer()
                        GachaResultCard(
                            image: item.image,
                            country: displayCountry,
                            region: displayRegion,
                            city: displayCity,
                            subLocality: displaySubLocality,
                            dateText: item.document.dateText ?? "",
                            latitude: item.document.latitude,
                            longitude: item.document.longitude,
                            photoId: item.document.id,
                            imagePath: item.document.imagePath,
                            likeCount: item.document.likeCount,
                            showLikeButton: false,
                            likerCountry: "Self",
                            likerCountryCode: nil,
                            isOwner: true,
                            expireDate: item.document.expireAt?.dateValue(),
                            onDeletePost: {
                                Task {
                                    do {
                                        try await PhotoService.shared.deletePhoto(documentId: item.id, imagePath: item.document.imagePath)
                                        await MainActor.run {
                                            closeDetail()
                                            if let idx = photos.firstIndex(where: { $0.id == item.id }) {
                                                photos.remove(at: idx)
                                            }
                                        }
                                    } catch {
                                        errorMessage = error.localizedDescription
                                    }
                                }
                            },
                            onUpdateLocation: { newCountry, newRegion, newCity, newSubLocality in
                                Task {
                                    do {
                                        try await PhotoService.shared.updateLocationData(
                                            photoId: item.id,
                                            country: newCountry,
                                            region: newRegion,
                                            city: newCity,
                                            subLocality: newSubLocality
                                        )
                                        await MainActor.run {
                                            closeDetail()
                                            photos = []
                                            lastSnapshot = nil
                                            isFinished = false
                                            Task { await loadPhotos() }
                                        }
                                    } catch {
                                        errorMessage = error.localizedDescription
                                    }
                                }
                            }
                        )
                        .frame(height: 520)
                        .frame(width: UIScreen.main.bounds.width - 48)
                        .scaleEffect(cardScale)
                        .onAppear { withAnimation(.interpolatingSpring(stiffness: 420, damping: 26)) { cardScale = 1.0 } }
                        Spacer()
                    }
                    .zIndex(2)
                    .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                }
            }
        }
        .ignoresSafeArea() // ★最重要: ルートで完全に無視させる
        .task { if photos.isEmpty && !isLoading { await loadPhotos() } }
    }

    private func openDetail(photo: SentPhoto) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            self.cardScale = 0.85
            self.selectedPhoto = photo
            
            // 初期表示
            displayCountry = photo.document.country
            displayRegion = photo.document.region
            displayCity = photo.document.city
            displaySubLocality = photo.document.subLocality
            
            // ローカライズ処理
            if let lat = photo.document.latitude, let lon = photo.document.longitude {
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
        }
    }
    
    private func closeDetail() {
        withAnimation(.easeOut(duration: 0.2)) { selectedPhoto = nil }
    }

    private func loadPhotos() async {
        guard !isLoading && !isFinished else { return }
        isLoading = true
        do {
            let result = try await PhotoService.shared.fetchMyPhotos(limit: 6, lastSnapshot: lastSnapshot)
            
            if result.photos.isEmpty { isFinished = true; isLoading = false; return }
            self.lastSnapshot = result.lastSnapshot
            if result.photos.count < 6 { isFinished = true }
            
            var newItems: [SentPhoto] = []
            try await withThrowingTaskGroup(of: SentPhoto?.self) { group in
                for doc in result.photos {
                    group.addTask {
                        do {
                            let image = try await PhotoService.shared.downloadThumbnail(originalPath: doc.imagePath)
                            return SentPhoto(id: doc.id, document: doc, image: image)
                        } catch {
                            print("Thumbnail fetch failed: \(error)")
                            return nil
                        }
                    }
                }
                for try await item in group { if let item = item { newItems.append(item) } }
            }
            
            let sortedNewItems = newItems.sorted { ($0.document.createdAt?.dateValue() ?? Date()) > ($1.document.createdAt?.dateValue() ?? Date()) }
            await MainActor.run {
                let currentIds = Set(self.photos.map { $0.id })
                let uniqueItems = sortedNewItems.filter { !currentIds.contains($0.id) }
                if !uniqueItems.isEmpty { self.photos.append(contentsOf: uniqueItems) }
                self.isLoading = false
            }
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription; self.isLoading = false }
        }
    }
}
