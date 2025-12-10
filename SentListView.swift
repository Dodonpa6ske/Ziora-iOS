import SwiftUI
import FirebaseAuth
import UIKit
import FirebaseFirestore

// 送信済み 1 件分
struct SentPhoto: Identifiable, Hashable {
    let id: String
    let document: PhotoDocument
    let image: UIImage

    static func == (lhs: SentPhoto, rhs: SentPhoto) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// サムネイル 1 枚
struct SentThumbnailView: View {
    let photo: SentPhoto
    let index: Int
    let onTap: () -> Void

    @State private var appeared = false

    var body: some View {
        // Grid内のサムネイル構造（LikedListViewと統一）
        Image(uiImage: photo.image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipped()
            .cornerRadius(20)
            // ハートカウントは overlay で乗せる
            .overlay(alignment: .bottomTrailing) {
                if photo.document.likeCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("\(photo.document.likeCount)")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.55))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(8)
                }
            }
            // アニメーション
            .offset(y: appeared ? 0 : 40)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(
                    .spring(response: 0.55, dampingFraction: 0.85)
                        .delay(Double(index % 20) * 0.05) // ページネーション用にディレイ計算を少し調整
                ) {
                    appeared = true
                }
            }
            .onTapGesture {
                onTap()
            }
    }
}

struct SentListView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var photos: [SentPhoto] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    // ★追加: ページネーション用
    @State private var lastSnapshot: DocumentSnapshot? = nil
    @State private var isFinished = false

    @State private var selectedPhoto: SentPhoto?
    @State private var cardScale: CGFloat = 0.9

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        ZStack {
            Color.zioraLightBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                if isLoading && photos.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if photos.isEmpty && isFinished { // ★変更: 読み込み完了時のみ表示
                    Text("No uploaded photos yet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: columns,
                            alignment: .center,
                            spacing: 8
                        ) {
                            ForEach(Array(photos.enumerated()), id: \.element.id) { index, item in
                                SentThumbnailView(
                                    photo: item,
                                    index: index
                                ) {
                                    selectedPhoto = item
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
                                // ★追加: 最後のアイテムが表示されたら次を読み込む
                                .onAppear {
                                    if index == photos.count - 1 {
                                        Task { await loadPhotos() }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20) // 下部パディングを調整
                        
                        // ★追加: 追加読み込み中のインジケータ
                        if isLoading && !photos.isEmpty {
                            ProgressView()
                                .padding(.vertical, 20)
                        }
                        
                        Spacer().frame(height: 100)
                    }
                }
            }

            // 詳細カードオーバーレイ
            if let item = selectedPhoto {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        selectedPhoto = nil
                    }

                // カードを画面中央に配置
                VStack(spacing: 0) {
                    Spacer()

                    GachaResultCard(
                        image: item.image,
                        country: item.document.country,
                        region: item.document.region,
                        city: item.document.city,
                        dateText: item.document.dateText ?? "",
                        latitude: item.document.latitude,
                        longitude: item.document.longitude,
                        photoId: item.document.id,
                        imagePath: item.document.imagePath,
                        likeCount: item.document.likeCount,
                        showLikeButton: false
                    )
                    .frame(height: 520)
                    .scaleEffect(cardScale)
                    .padding(.horizontal, 24)
                    
                    // ボタン類を削除したため、カードのみ表示されます

                    Spacer()
                }
            }

            // 閉じるボタン（右上の×）
            VStack {
                Spacer()
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                            Circle()
                                .stroke(Color.black.opacity(0.1), lineWidth: 1)

                            Image(systemName: "xmark")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        .frame(width: 60, height: 60)
                        .shadow(color: Color.black.opacity(0.1), radius: 0, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.leading, 33)
                .padding(.bottom, 40)
            }
            .opacity(selectedPhoto == nil ? 1 : 0)
            
            // 成功メッセージ（必要であれば残す）
            if let message = successMessage {
                VStack {
                    Spacer()
                    Text(message)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(20)
                        .padding(.bottom, 100)
                }
                .transition(.opacity)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { successMessage = nil }
                    }
                }
            }
        }
        .task {
            // ★変更: まだ読み込んでいなければ読み込む
            if photos.isEmpty && !isLoading {
                await loadPhotos()
            }
        }
    }

    // MARK: - Actions

    private func loadPhotos() async {
        // ★変更: 読み込み中または読み込み完了済みなら何もしない
        guard !isLoading && !isFinished else { return }
        isLoading = true
        // defer { isLoading = false } // append内でfalseにするため削除

        do {
            // ★変更: ページネーション付きメソッド呼び出し
            let result = try await PhotoService.shared.fetchMyPhotos(limit: 20, lastSnapshot: lastSnapshot)
            
            // 続きがなければ終了
            if result.photos.isEmpty {
                isFinished = true
                isLoading = false
                return
            }
            
            self.lastSnapshot = result.lastSnapshot
            // 取得件数がリクエストより少なければ終了フラグを立てる
            if result.photos.count < 20 {
                isFinished = true
            }
            
            var items: [SentPhoto] = []
            
            try await withThrowingTaskGroup(of: SentPhoto?.self) { group in
                for doc in result.photos {
                    group.addTask {
                        do {
                            let image = try await PhotoService.shared
                                .downloadThumbnail(originalPath: doc.imagePath)
                            return SentPhoto(id: doc.id, document: doc, image: image)
                        } catch {
                            print("Failed to download thumbnail for \(doc.id): \(error)")
                            return nil
                        }
                    }
                }
                
                for try await item in group {
                    if let item = item {
                        items.append(item)
                    }
                }
            }

            let sortedItems = items.sorted {
                ($0.document.createdAt?.dateValue() ?? Date()) > ($1.document.createdAt?.dateValue() ?? Date())
            }

            await MainActor.run {
                // ★変更: 配列を置き換えるのではなく追加する
                self.photos.append(contentsOf: sortedItems)
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}
