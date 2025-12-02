import SwiftUI
import FirebaseAuth
import UIKit

// 送信済み 1 件分
struct SentPhoto: Identifiable, Hashable {
    let id: String
    let document: PhotoDocument
    let image: UIImage

    // id だけで同一判定
    static func == (lhs: SentPhoto, rhs: SentPhoto) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// サムネイル 1 枚（下からスライドイン + いいねバッジ）
struct SentThumbnailView: View {
    let photo: SentPhoto
    let index: Int
    let onTap: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(uiImage: photo.image)
                .resizable()
                .scaledToFill()
                .frame(height: 220)
                .clipped()
                .cornerRadius(20)

            // いいね数バッジ
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
        .offset(y: appeared ? 0 : 40)   // 下からスライド
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(
                .spring(response: 0.55, dampingFraction: 0.85)
                    .delay(Double(index) * 0.12) // いいねリストと同系の時間差
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

    @State private var selectedPhoto: SentPhoto?
    @State private var cardScale: CGFloat = 0.9

    // 2 カラム・サムネイル間隔 8pt
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        ZStack {
            // 全体背景 (#F6F6F6)
            Color.zioraLightBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 上から少し余白（白背景とのバランス用）
                Spacer().frame(height: 40)

                if isLoading && photos.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if photos.isEmpty {
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
                                    // タップで拡大表示
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
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 120) // 下のバツボタンぶん余白
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

                VStack {
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
                        imagePath: item.document.imagePath
                    )
                    .scaleEffect(cardScale)
                    .padding(.bottom, 16)

                    // いいね数 + 送信取り消しボタン
                    HStack {
                        if item.document.likeCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("\(item.document.likeCount)")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(role: .destructive) {
                            Task { await cancelSending(item) }
                        } label: {
                            Text("Cancel sending")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
            }

            // 下左のバツボタン（ホームの送信リストボタン位置に合わせる）
            // 拡大表示中は非表示にしてカードと被らないようにする
            if selectedPhoto == nil {
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
                                    .stroke(Color.black.opacity(0.08), lineWidth: 2)

                                Image(systemName: "xmark")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.black)
                            }
                            .frame(width: 72, height: 72)
                            .shadow(color: Color.black.opacity(0.12),
                                    radius: 10, x: 0, y: 6)
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                    .padding(.leading, 33)
                    .padding(.bottom, 40)
                }
            }
        }
        .task {
            await loadPhotos()
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Data

    private func loadPhotos() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let docs = try await PhotoService.shared.fetchMyPhotos()

            var items: [SentPhoto] = []
            for doc in docs {
                do {
                    let image = try await PhotoService.shared
                        .downloadImage(imagePath: doc.imagePath)
                    items.append(
                        SentPhoto(id: doc.id, document: doc, image: image)
                    )
                } catch {
                    print("Failed to download image for \(doc.id): \(error)")
                }
            }

            await MainActor.run {
                self.photos = items
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func cancelSending(_ item: SentPhoto) async {
        do {
            try await PhotoService.shared.deletePhoto(
                documentId: item.document.id,
                imagePath: item.document.imagePath
            )

            await MainActor.run {
                photos.removeAll { $0.id == item.id }
                selectedPhoto = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
