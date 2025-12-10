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
        .offset(y: appeared ? 0 : 40)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(
                .spring(response: 0.55, dampingFraction: 0.85)
                    .delay(Double(index) * 0.12)
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
                        .padding(.bottom, 120)
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
                    .frame(height: 520)
                    .scaleEffect(cardScale)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

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

            // 下左のバツボタン（ホーム画面と位置・サイズを統一）
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
                                    .stroke(Color.black.opacity(0.1), lineWidth: 1)

                                Image(systemName: "xmark")
                                    .font(.system(size: 24, weight: .semibold)) // 24pt
                                    .foregroundColor(.black)
                            }
                            .frame(width: 60, height: 60) // 60pt
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 0)
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                    .padding(.leading, 33) // 左端から33pt (HomeViewと統一)
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

    private func loadPhotos() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let docs = try await PhotoService.shared.fetchMyPhotos()
            var items: [SentPhoto] = []
            
            try await withThrowingTaskGroup(of: SentPhoto?.self) { group in
                for doc in docs {
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
                self.photos = sortedItems
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
