import SwiftUI
import UIKit

// MARK: - Map Destination Model
struct MapDestination: Identifiable {
    let id = UUID()
    let query: String
}

// MARK: - Main Card View

struct GachaResultCard: View {
    // 外部からのデータ
    let image: UIImage
    let country: String
    let region: String
    let city: String
    let subLocality: String? // ★追加
    let dateText: String
    let latitude: Double?
    let longitude: Double?

    let photoId: String
    let imagePath: String
    var userId: String? = nil
    
    let likeCount: Int
    var showLikeButton: Bool = true
    
    // ★追加: いいねする側の国名（通知用）
    let likerCountry: String
    let likerCountryCode: String? // ★追加: 国コード
    
    // 投稿者モード用
    var isOwner: Bool = false
    var expireDate: Date? = nil
    
    var onDeletePost: (() -> Void)? = nil
    // 更新用コールバック (country, region, city を渡す)
    var onUpdateLocation: ((String, String, String, String?) -> Void)? = nil

    @ObservedObject private var likedStore = LikedPhotoStore.shared
    
    // 編集用の一時State
    @State private var localCountry: String = ""
    @State private var localRegion: String = ""
    @State private var localCity: String = ""
    @State private var localSubLocality: String = "" // ★追加
    @State private var isInitialized = false
    
    // アラート制御
    @State private var mapDestination: MapDestination?
    @State private var showReportConfirmation = false
    @State private var showBlockConfirmation = false
    @State private var showBlockCompleteMessage = false
    @State private var showDeleteConfirmation = false
    @State private var showSuccessOverlay = false
    
    // 更新確認アラート
    @State private var showUpdateConfirmation = false

    var body: some View {
        // ★修正点1: ZStackをやめ、VStack自体に背景をつける構造に変更
        // これにより、背景がコンテンツサイズを超えて広がる（白いふちが出る）のを防ぎます
        VStack(spacing: 0) {
            // --- 1. 画像エリア ---
            ZStack(alignment: .bottomTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    // 左右のパディング(10pt x 2)を除いた幅を明示的に指定して、はみ出しを確実に防ぐ
                    .frame(width: UIScreen.main.bounds.width - 48 - 20)
                    .frame(maxHeight: .infinity)
                    .clipped()
                    .cornerRadius(20)
                
                // --- オーバーレイ要素 ---
                HStack(alignment: .bottom) {
                    // 左下: 更新ボタン (変更がある場合のみ表示)
                    if hasChanges {
                        Button {
                            showUpdateConfirmation = true
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    Spacer()
                    
                    // 右下: 残り時間表示 (自分の投稿の場合)
                    if isOwner, let expire = expireDate {
                        Text(remainingTimeText(expire: expire))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                    }
                }
                .padding(10)
            }
            .padding(.top, 10)
            .padding(.horizontal, 10)
            
            // 右上のメニューボタン
            .overlay(alignment: .topTrailing) {
                if isOwner || showLikeButton {
                    Menu {
                        if isOwner {
                            // 投稿者用: 削除のみ
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label(localized("Delete Post"), systemImage: "trash")
                            }
                        } else if showLikeButton {
                            // 閲覧者用
                            Button(role: .destructive) { showReportConfirmation = true } label: {
                                Label("Report Inappropriate", systemImage: "exclamationmark.bubble")
                            }
                            if userId != nil {
                                Button(role: .destructive) { showBlockConfirmation = true } label: {
                                    Label("Block this User", systemImage: "hand.raised.fill")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 13)
                    .padding(.top, 18)
                }
            }
            
            // --- 2. 下部情報エリア ---
            VStack(alignment: .leading, spacing: 8) {
                
                // 表示すべき位置情報があるかどうか（ローカル変数で判定して即時反映）
                let hasLocationData = !localCountry.isEmpty || !localRegion.isEmpty || !localCity.isEmpty || !localSubLocality.isEmpty
                
                if hasLocationData {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            // 編集用データ
                            if !localSubLocality.isEmpty {
                                pillView(text: localSubLocality)
                                    // 修正: 検索精度向上のため、RegionとCountryも含めて検索するように変更
                                    // "Kita, Osaka" -> "Kita, Osaka, Osaka, Japan" とすることで曖昧さを回避
                                    .onTapGesture { openMap(for: "\(localSubLocality), \(localCity), \(localRegion), \(localCountry)") }
                                    .contextMenu {
                                        if isOwner {
                                            Button(role: .destructive) {
                                                withAnimation { localSubLocality = "" }
                                            } label: { Label("Delete Area Info", systemImage: "trash") }
                                        }
                                    }
                            }
                            if !localCity.isEmpty {
                                pillView(text: localCity)
                                    .onTapGesture { openMap(for: "\(localCity), \(localRegion), \(localCountry)") }
                                    .contextMenu {
                                        if isOwner {
                                            Button(role: .destructive) {
                                                withAnimation { localCity = "" }
                                            } label: { Label("Delete City Info", systemImage: "trash") }
                                        }
                                    }
                            }
                            if !localRegion.isEmpty && localRegion != localCity {
                                pillView(text: localRegion)
                                    .onTapGesture { openMap(for: "\(localRegion), \(localCountry)") }
                                    .contextMenu {
                                        if isOwner {
                                            Button(role: .destructive) {
                                                withAnimation { localRegion = "" }
                                            } label: { Label("Delete Region Info", systemImage: "trash") }
                                        }
                                    }
                            }
                            if !localCountry.isEmpty {
                                pillView(text: localCountry)
                                    .onTapGesture { openMap(for: localCountry) }
                                    .contextMenu {
                                        if isOwner {
                                            Button(role: .destructive) {
                                                withAnimation { localCountry = "" }
                                            } label: { Label("Delete Country Info", systemImage: "trash") }
                                        }
                                    }
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
                    .transition(.opacity.combined(with: .move(edge: .top))) // アニメーションで消えるように
                }
                
                // フッター
                HStack(alignment: .center) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(dateText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if showLikeButton {
                        LikeButton(
                            isLiked: Binding(
                                get: { likedStore.isLiked(id: photoId) },
                                set: { newValue in
                                    if newValue {
                                        let lp = LikedPhoto(id: photoId, imagePath: imagePath, country: country, region: region, city: city, subLocality: subLocality, dateText: dateText, latitude: latitude, longitude: longitude)
                                        likedStore.add(photo: lp, image: image)
                                        
                                        // ★修正: 国名と相手のID、そして国コードを渡す
                                        Task { 
                                            await PhotoService.shared.sendLike(
                                                photoId: photoId, 
                                                countryName: likerCountry, 
                                                countryCode: likerCountryCode, // ★引数追加
                                                targetUserId: userId ?? ""
                                            ) 
                                        }
                                    } else {
                                        likedStore.remove(id: photoId)
                                        Task { await PhotoService.shared.removeLike(photoId: photoId) }
                                    }
                                }
                            )
                        )
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "4347E6"))
                            Text("\(likeCount)")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .frame(height: 44)
                    }
                }
                .offset(y: -8)
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)
            .padding(.bottom, 0)
            // 幅を最大化し左寄せを強制
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // ★修正: 明示的に幅を指定して、コンテンツ量による幅のブレを防止
        .frame(width: UIScreen.main.bounds.width - 48)
        // ★修正点2: 背景をここに適用。これで背景サイズがコンテンツ（VStack）のサイズに完全に一致します。
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)
        )
        // 描画グループ化（ちらつき防止）
        .compositingGroup()
        .onAppear {
            if !isInitialized {
                localCountry = country
                localRegion = region
                localCity = city
                localSubLocality = subLocality ?? ""
                isInitialized = true
            }
            }

        // ★修正: 親ビューから動的にローカライズされた値が渡された場合、ローカルStateも更新して表示を同期する
        .onChange(of: country) { newValue in localCountry = newValue }
        .onChange(of: region) { newValue in localRegion = newValue }
        .onChange(of: city) { newValue in localCity = newValue }
        .onChange(of: subLocality) { newValue in localSubLocality = newValue ?? "" }
        
        .overlay {
            if showSuccessOverlay {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark")
                        // ... (省略: 前後のコードと一致させる)
                        .font(.system(size: 44, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().strokeBorder(Color.white, lineWidth: 3))
                        Text("Done")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(40)
                    .background(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .cornerRadius(20)
                    .transition(.scale.combined(with: .opacity))
                }
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                .zIndex(999)
            }
        }
        
        .sheet(item: $mapDestination) { destination in LocationMapView(searchQuery: destination.query) }
        
        // アラート群
        .alert("Report this photo?", isPresented: $showReportConfirmation) {
            Button("Inappropriate Content", role: .destructive) { submitReport(reason: "Inappropriate Content") }
            Button("Spam or Scam", role: .destructive) { submitReport(reason: "Spam or Scam") }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Block this user?", isPresented: $showBlockConfirmation, titleVisibility: .visible) {
            Button("Block", role: .destructive) { if let uid = userId { submitBlock(targetUserId: uid) } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("You will no longer see photos from this user.") }
        .alert("Blocked", isPresented: $showBlockCompleteMessage) { Button("OK", role: .cancel) {} } message: { Text("This user has been blocked.") }
        
        .alert(localized("Delete Post"), isPresented: $showDeleteConfirmation) {
            Button(localized("Delete"), role: .destructive) { onDeletePost?() }
            Button(localized("Cancel"), role: .cancel) {}
        } message: { Text(localized("DeletePost_Message")) }
        
        // 更新確認アラート (英語)
        .alert("Update with these edits?", isPresented: $showUpdateConfirmation) {
            Button("Update", role: .destructive) {
                onUpdateLocation?(localCountry, localRegion, localCity, localSubLocality.isEmpty ? nil : localSubLocality)
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    // MARK: - Helpers
    
    // ★追加: ローカライズヘルパー
    @AppStorage("selectedLanguage") private var language: String = "en"
    private func localized(_ key: String) -> String {
        if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
        }
        return key
    }
    
    private var hasChanges: Bool {
        // ロケーション情報が削除されている場合のみボタンを表示
        // (ローカライズによる文字列の差異ではボタンを出さない)
        if !country.isEmpty && localCountry.isEmpty { return true }
        if !region.isEmpty && localRegion.isEmpty { return true }
        if !city.isEmpty && localCity.isEmpty { return true }
        if let sub = subLocality, !sub.isEmpty, localSubLocality.isEmpty { return true }
        return false
    }
    
    private func remainingTimeText(expire: Date) -> String {
        let diff = expire.timeIntervalSince(Date())
        if diff <= 0 { return localized("Expired") }
        let days = Int(diff / 86400)
        if days > 0 { return String(format: localized("Expires in %dd"), days) }
        let hours = Int(diff / 3600)
        if hours > 0 { return String(format: localized("Expires in %dh"), hours) }
        return localized("Expires soon")
    }
    
    private func openMap(for query: String) { self.mapDestination = MapDestination(query: query) }
    
    private func pillView(text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
            .contentShape(Rectangle()) // タップ領域確保
    }
    
    private func submitReport(reason: String) {
        Task { try? await PhotoService.shared.reportPhoto(photoId: photoId, reason: reason); showSuccess() }
    }
    private func submitBlock(targetUserId: String) {
        Task { try? await PhotoService.shared.blockUser(blockedUserId: targetUserId); showBlockCompleteMessage = true }
    }
    private func showSuccess() {
        withAnimation { showSuccessOverlay = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation { showSuccessOverlay = false } }
    }
}
