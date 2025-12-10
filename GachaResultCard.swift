import SwiftUI
import UIKit

// MARK: - Custom Button Style (沈み込み + ハプティクス)

struct LocationPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
    }
}

// MARK: - Map Destination Model
struct MapDestination: Identifiable {
    let id = UUID()
    let query: String
}

// MARK: - Main Card View

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
    
    // ブロック機能のために投稿者のIDが必要
    var userId: String? = nil
    
    // いいね数と、ボタンを表示するかどうかのフラグ
    let likeCount: Int
    var showLikeButton: Bool = true

    @ObservedObject private var likedStore = LikedPhotoStore.shared
    
    @State private var mapDestination: MapDestination?
    
    // アラート制御用
    @State private var showReportConfirmation = false
    @State private var showBlockConfirmation = false
    @State private var showBlockCompleteMessage = false
    
    // 完了アニメーション制御用
    @State private var showSuccessOverlay = false

    var body: some View {
        ZStack {
            // 背景
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.18),
                        radius: 18, x: 0, y: 10)

            // コンテンツ
            VStack(spacing: 0) {
                // 1. 画像エリア
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .cornerRadius(20)
                    .padding(.top, 10)
                    .padding(.horizontal, 10)
                    // 右上のメニューボタン
                    .overlay(alignment: .topTrailing) {
                        if showLikeButton {
                            Menu {
                                // 通報ボタン
                                Button(role: .destructive) {
                                    showReportConfirmation = true
                                } label: {
                                    Label("Report Inappropriate", systemImage: "exclamationmark.bubble")
                                }
                                
                                // ブロックボタン (userIdがある場合のみ)
                                if userId != nil {
                                    Button(role: .destructive) {
                                        showBlockConfirmation = true
                                    } label: {
                                        Label("Block this User", systemImage: "hand.raised.fill")
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    // 背景の主張を抑える（透明度30%）
                                    .background(Color.black.opacity(0.2))
                                    .clipShape(Circle())
                            }
                            .padding(.trailing, 13)
                            .padding(.top, 18)
                        }
                    }
                
                // 2. 下部情報エリア
                VStack(alignment: .leading, spacing: 8) {
                    
                    // 上段: 位置情報タグ
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            if !country.isEmpty {
                                Button { openMap(for: country) } label: { pill(country) }
                                    .buttonStyle(LocationPillButtonStyle())
                            }
                            if !region.isEmpty {
                                Button {
                                    let query = [region, country].filter { !$0.isEmpty }.joined(separator: ", ")
                                    openMap(for: query)
                                } label: { pill(region) }
                                    .buttonStyle(LocationPillButtonStyle())
                            }
                            if !city.isEmpty {
                                Button {
                                    let query = [city, region, country].filter { !$0.isEmpty }.joined(separator: ", ")
                                    openMap(for: query)
                                } label: { pill(city) }
                                    .buttonStyle(LocationPillButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .mask(
                        HStack(spacing: 0) {
                            LinearGradient(gradient: Gradient(colors: [.clear, .black]), startPoint: .leading, endPoint: .trailing).frame(width: 16)
                            Rectangle().fill(Color.black)
                            LinearGradient(gradient: Gradient(colors: [.black, .clear]), startPoint: .leading, endPoint: .trailing).frame(width: 16)
                        }
                    )
                    .padding(.horizontal, -16)

                    
                    // 下段: 撮影日時 + いいねボタン(または数)
                    HStack(alignment: .center) {
                        
                        // 撮影日時
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text(dateText)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // showLikeButton フラグで分岐
                        if showLikeButton {
                            // いいねボタン (他人の写真用)
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
                                            Task { await PhotoService.shared.sendLike(photoId: photoId) }
                                        } else {
                                            likedStore.remove(id: photoId)
                                        }
                                    }
                                )
                            )
                        } else {
                            // いいね数のみ表示 (自分の写真用: グレー表示で操作不可)
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: "4347E6"))
                                Text("\(likeCount)")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.secondary) // グレーにする
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                        }
                    }
                    .offset(y: -8)
                }
                .padding(.top, 16)
                .padding(.horizontal, 16)
                .padding(.bottom, 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // アニメーション対策: カード全体を1つのレイヤーとして合成
        .compositingGroup()
        
        // 完了アニメーションのオーバーレイ
        .overlay {
            if showSuccessOverlay {
                ZStack {
                    // 全体を少し暗くする背景
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    // 中央のHUD
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(
                                Circle()
                                    .strokeBorder(Color.white, lineWidth: 3)
                            )
                        
                        Text("Done")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(40)
                    // ★修正: すりガラス効果のある暗い背景の正しい実装
                    .background(.ultraThinMaterial) // すりガラス素材
                    .environment(\.colorScheme, .dark) // ダークモード扱いにすることで暗いガラスにする
                    .cornerRadius(20)
                    // ポップアップアニメーション
                    .transition(.scale.combined(with: .opacity))
                }
                // 全体のフェードイン・アウト
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                .zIndex(999) // 最前面に表示
            }
        }
        
        .sheet(item: $mapDestination) { destination in
            LocationMapView(searchQuery: destination.query)
        }
        // 通報確認アラート (Cancelを目立たせるため他をdestructiveに)
        .alert("Report this photo?", isPresented: $showReportConfirmation) {
            Button("Inappropriate Content", role: .destructive) { submitReport(reason: "Inappropriate Content") }
            Button("Spam or Scam", role: .destructive) { submitReport(reason: "Spam or Scam") }
            Button("Cancel", role: .cancel) {}
        }
        // ブロック確認ダイアログ
        .confirmationDialog("Block this user?", isPresented: $showBlockConfirmation, titleVisibility: .visible) {
            Button("Block", role: .destructive) {
                if let uid = userId { submitBlock(targetUserId: uid) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will no longer see photos from this user.")
        }
        
        .alert("Blocked", isPresented: $showBlockCompleteMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This user has been blocked.")
        }
    }
    
    private func openMap(for query: String) {
        self.mapDestination = MapDestination(query: query)
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
    }
    
    // 通報処理
    private func submitReport(reason: String) {
        Task {
            do {
                try await PhotoService.shared.reportPhoto(photoId: photoId, reason: reason)
                await MainActor.run {
                    // 成功の触覚フィードバック
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    // アニメーション付きでオーバーレイを表示
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        showSuccessOverlay = true
                    }
                    
                    // 2秒後に自動で非表示にする
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showSuccessOverlay = false
                        }
                    }
                }
            } catch {
                print("Failed to report: \(error)")
            }
        }
    }
    
    // ブロック処理
    private func submitBlock(targetUserId: String) {
        Task {
            do {
                try await PhotoService.shared.blockUser(blockedUserId: targetUserId)
                await MainActor.run {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    showBlockCompleteMessage = true
                }
            } catch {
                print("Failed to block: \(error)")
            }
        }
    }
}
