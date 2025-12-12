import SwiftUI
import CoreLocation
import UIKit
import UniformTypeIdentifiers
import FirebaseAuth
import FirebaseFirestore

let testNativeAdUnitID = "ca-app-pub-9291029167690966/8530992058"

struct HomeView: View {
    // Navigation handlers
    var onOpenMenu: () -> Void = {}
    var onOpenCamera: () -> Void = {}
    var onOpenSentList: () -> Void = {}
    var onOpenLikedList: () -> Void = {}
    
    // ===== State =====
    @State private var showMenu = false
    @EnvironmentObject var storeManager: StoreManager
    
    // アラート用
    @State private var showSignOutAlert = false
    @State private var showDeleteAccountAlert = false
    
    // Capture / upload state
    @State private var showCamera = false
    @State private var capturedImage: UIImage? = nil
    
    @State private var showPreviewCard = false
    @State private var isUploading = false
    @State private var uploadErrorMessage: String? = nil
    
    // ★アニメーション制御用
    @State private var previewOffset: CGFloat = 0 // ドラッグ中のオフセット
    @State private var isFlyingAway = false       // 上空へ飛んでいくフラグ
    @State private var showSuccessCheckmark = false // 完了マーク表示
    
    // ★追加: 新しい画面（シート）の表示フラグ
    @State private var showLanguageSheet = false
    @State private var showContactSheet = false
    
    // Gacha (download) state
    @State private var isGachaLoading = false
    @State private var gachaImage: UIImage? = nil
    @State private var showGachaCard = false
    @State private var gachaCountry: String = ""
    @State private var gachaRegion: String  = ""
    @State private var gachaCity: String    = ""
    @State private var gachaDateText: String = ""
    @State private var gachaLatitude: Double? = nil
    @State private var gachaLongitude: Double? = nil
    @State private var gachaErrorMessage: String? = nil
    @State private var gachaPhotoId: String = ""
    @State private var gachaImagePath: String = ""
    
    // Location & date
    @StateObject private var locationManager = LocationManager.shared
    @State private var capturedCountry: String = "Country"
    @State private var capturedRegion: String  = "State"
    @State private var capturedCity: String    = "City"
    @State private var capturedDateText: String = ""
    
    // リスト用
    @State private var showLikedList = false
    @State private var showSentList = false
    
    // 課金画面シート用
    @State private var showAdFreeSheet = false
    
    // 広告管理用
    @State private var gachaCount: Int = 0
    @State private var lastAdShownAt: Int = -100
    @State private var showAdThisTime = false
    
    @StateObject private var interactionState = InteractionState()
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    private let gachaCardHeight: CGFloat = 520
    
    var body: some View {
        ZStack {
            
            ParticleBackgroundView()
            
            // 地球
            GlobeSceneView(
                onSpin: { spinDuration in
                    Task { await performGacha(expectedSpinDuration: spinDuration) }
                },
                interactionState: interactionState
            )
            .ignoresSafeArea(edges: .top)
            .padding(.top, 40)
            .padding(.bottom, 140)
            
            // UIレイヤー (ボタン類)
            VStack(spacing: 0) {
                // 上部ハンバーガー
                HStack {
                    Button {
                        // ★修正: メニューを開くときは easeOut でスライドインさせる
                        withAnimation(.easeOut(duration: 0.25)) {
                            showMenu = true
                        }
                        onOpenMenu()
                    } label: {
                        HamburgerIcon().frame(width: 30, height: 30)
                    }
                    .padding(.leading, 30)
                    Spacer()
                }
                .padding(.top, 50)
                .opacity(showPreviewCard ? 0 : 1) // プレビュー中は隠す
                
                Spacer()
                
                // 下部3ボタン
                HStack {
                    CircleIconButton(
                        systemName: "photo.fill",
                        size: 60,
                        foreground: Color(hex: "908FF7"), background: .white, showShadow: false
                    ) {
                        showSentList = true
                        onOpenSentList()
                    }
                    Spacer()
                    CameraMainButton {
                        showCamera = true
                        onOpenCamera()
                    }
                    Spacer()
                    CircleIconButton(
                        systemName: "heart.fill", size: 60,
                        foreground: Color(hex: "908FF7"), background: .white, showShadow: false
                    ) {
                        showLikedList = true
                        onOpenLikedList()
                    }
                }
                .padding(.horizontal, 33)
                .padding(.bottom, 40)
                .opacity(showPreviewCard ? 0 : 1) // プレビュー中は隠す
            }
            
            // ガチャカード
            if showGachaCard {
                Color.black.opacity(0.35).ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showGachaCard = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { gachaImage = nil }
                    }
                
                VStack {
                    Spacer()
                    Group {
                        if showAdThisTime {
                            GachaCardShell { NativeAdCardView(adUnitID: testNativeAdUnitID) }
                        } else if let image = gachaImage {
                            GachaResultCard(
                                image: image,
                                country: gachaCountry,
                                region: gachaRegion,
                                city: gachaCity,
                                dateText: gachaDateText,
                                latitude: gachaLatitude,
                                longitude: gachaLongitude,
                                photoId: gachaPhotoId,
                                imagePath: gachaImagePath,
                                likeCount: 0,
                                showLikeButton: true
                            )
                        }
                    }
                    .frame(height: gachaCardHeight)
                    .padding(.horizontal, 24)
                    Spacer()
                }
                .offset(y: -40)
                .transition(.asymmetric(
                    insertion: .modifier(
                        active: PopUpModifier(scale: 0.0, opacity: 0),
                        identity: PopUpModifier(scale: 1.0, opacity: 1)
                    ),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showGachaCard)
            }
            
            // 撮影プレビューカード (送信UI)
            if showPreviewCard, let image = capturedImage {
                Color.black.opacity(0.3).ignoresSafeArea()
                    .onTapGesture {
                        // キャンセル時
                        withAnimation { showPreviewCard = false; capturedImage = nil; previewOffset = 0; isFlyingAway = false }
                    }
                    .opacity(isFlyingAway ? 0 : 1) // 飛んでいくときは背景を明るく戻す

                VStack {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        SwipeUpHint()
                            .opacity(isFlyingAway ? 0 : 1)
                        
                        PreviewPhotoCard(
                            image: image,
                            country: capturedCountry,
                            region: capturedRegion,
                            city: capturedCity,
                            dateText: capturedDateText,
                            isUploading: isUploading,
                            onDeleteLayer: { key in
                                switch key {
                                case "country": capturedCountry = ""
                                case "region": capturedRegion = ""
                                case "city": capturedCity = ""
                                default: break
                                }
                            }
                        )
                        // サイズをガチャ画面と統一
                        .frame(height: gachaCardHeight)
                        .padding(.horizontal, 24)
                        
                        // アニメーション (まっすぐ上へ)
                        .offset(y: isFlyingAway ? -UIScreen.main.bounds.height * 1.5 : previewOffset)
                        .scaleEffect(isFlyingAway ? 0.9 : 1.0)
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.height < 0 {
                                    previewOffset = value.translation.height
                                }
                            }
                            .onEnded { value in
                                // 上にスワイプしたら飛んでいく
                                if value.translation.height < -100 {
                                    startFlyAwayAnimation()
                                } else {
                                    // 戻る
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        previewOffset = 0
                                    }
                                }
                            }
                    )
                    
                    Spacer()
                }
                // 3Dスライドイン
                .transition(.modifier(
                    active: ThreeDSlideModifier(angle: 45, yOffset: 600, opacity: 0),
                    identity: ThreeDSlideModifier(angle: 0, yOffset: 0, opacity: 1)
                ))
            }
            
            // 完了チェックマーク
            if showSuccessCheckmark {
                SuccessCheckmarkView()
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(100)
            }
            
            // ===== ハンバーガーメニュー =====
            if showMenu {
                // 背景の黒透過
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeIn(duration: 0.22)) { showMenu = false } }
                    .transition(.opacity) // 背景はフェード
                
                // メニュー本体
                HStack(spacing: 0) {
                    HamburgerMenuView(
                        isPresented: $showMenu,
                        onOpenAdFreePlan: { showAdFreeSheet = true },
                        onOpenNotificationSettings: { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } },
                        
                        // ★追加: 言語設定を開く
                        onOpenLanguage: { showLanguageSheet = true },
                        
                        onOpenLegal: { if let url = URL(string: "https://www.notion.so/Ziora-Terms-of-Service-2c0aacfc1c6f801f934cdafe1e0bf063?source=copy_link") { UIApplication.shared.open(url) } },
                        
                        // ★修正: アプリ内お問い合わせ画面を開く
                        onOpenContact: { showContactSheet = true },
                        
                        onSignOut: { showSignOutAlert = true },
                        onDeleteAccount: { showDeleteAccountAlert = true }
                    )
                    .frame(width: 320)
                    
                    Spacer() // 右側を空けて左に寄せる
                }
                .ignoresSafeArea()
                // ★修正: HStack全体にスライドインを適用（これで左外から入ってくる）
                .transition(.move(edge: .leading))
                .zIndex(2)
            }
        }
        .onReceive(locationManager.$lastPlacemark) { placemark in
            guard let p = placemark else { return }
            let isoCode = p.isoCountryCode ?? ""
            capturedCountry = p.country ?? (isoCode.isEmpty ? "Country" : isoCode)
            let adminArea = p.administrativeArea ?? ""
            capturedRegion = adminArea.isEmpty ? "State" : adminArea
            let locality = p.locality ?? ""
            let subLocality = p.subLocality ?? ""
            if !subLocality.isEmpty {
                if locality.isEmpty || locality == subLocality { capturedCity = subLocality }
                else { capturedCity = subLocality }
            } else { capturedCity = locality.isEmpty ? "City" : locality }
        }
        .fullScreenCover(isPresented: $showCamera) {
            ZStack {
                Color.black.ignoresSafeArea()
                PhotoCaptureView(image: $capturedImage)
                    .ignoresSafeArea()
                    .onDisappear {
                        if capturedImage != nil {
                            capturedDateText = DateFormatter.zioraDisplay.string(from: Date())
                            locationManager.requestLocation()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                let impact = UIImpactFeedbackGenerator(style: .medium); impact.impactOccurred()
                                previewOffset = 0
                                isFlyingAway = false
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                    showPreviewCard = true
                                }
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showLikedList) { NavigationStack { LikedListView() } }
        .sheet(isPresented: $showSentList) { NavigationStack { SentListView() } }
        .sheet(isPresented: $showAdFreeSheet) { AdFreePlanView() }
        
        // ★追加: 言語設定シート
        .sheet(isPresented: $showLanguageSheet) { LanguageSettingsView() }
        
        // ★追加: お問い合わせシート
        .sheet(isPresented: $showContactSheet) { ContactView() }
        
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Sign Out", role: .destructive) { try? AuthManager.shared.signOut() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Are you sure you want to sign out?") }
        .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
            Button("Delete", role: .destructive) { Task { try? await AuthManager.shared.deleteAccount() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This action cannot be undone. All your data will be permanently deleted.") }
        .alert("Error", isPresented: Binding(get: { uploadErrorMessage != nil || gachaErrorMessage != nil }, set: { _ in uploadErrorMessage = nil; gachaErrorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: { Text(uploadErrorMessage ?? gachaErrorMessage ?? "") }
        .preferredColorScheme(.light)
    }
    
    // (旧メール起動ヘルパー：不要なら削除可)
    private func openContactSupport() {
        let email = "ziora.app.contact@gmail.com"
        let subject = "Ziora Support"
        let body = "Please describe your issue or feedback here."
        let urlString = "mailto:\(email)?subject=\(subject)&body=\(body)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    // 飛んでいくアニメーション (easeOutでなめらかに)
    private func startFlyAwayAnimation() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        withAnimation(.easeOut(duration: 0.4)) {
            isFlyingAway = true
        }
        
        Task {
            await uploadCurrentPhoto()
        }
    }
    
    private func uploadCurrentPhoto() async {
        guard networkMonitor.isConnected else {
            withAnimation { isFlyingAway = false; previewOffset = 0 }
            uploadErrorMessage = "No internet connection."
            return
        }

        guard !isUploading, let image = capturedImage else { return }
        isUploading = true
        
        let loc = locationManager.lastLocation
        let placemark = locationManager.lastPlacemark
        let meta = PhotoMeta(country: capturedCountry, region: capturedRegion, city: capturedCity, countryCode: placemark?.isoCountryCode ?? "", latitude: loc?.coordinate.latitude, longitude: loc?.coordinate.longitude, dateText: capturedDateText)
        
        do {
            _ = try await PhotoService.shared.uploadPhoto(image: image, meta: meta)
            
            withAnimation { showPreviewCard = false }
            
            try? await Task.sleep(nanoseconds: 200_000_000)
            
            await MainActor.run {
                withAnimation(.spring()) { showSuccessCheckmark = true }
                let notification = UINotificationFeedbackGenerator()
                notification.notificationOccurred(.success)
            }
            
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run {
                withAnimation { showSuccessCheckmark = false }
                capturedImage = nil
                previewOffset = 0
                isFlyingAway = false
                isUploading = false
            }
            
        } catch {
            await MainActor.run {
                withAnimation(.spring()) {
                    isFlyingAway = false
                    previewOffset = 0
                }
                uploadErrorMessage = error.localizedDescription
                isUploading = false
            }
        }
    }
    
    private func performGacha(expectedSpinDuration: TimeInterval, retryCount: Int = 0) async {
        guard networkMonitor.isConnected else {
            gachaErrorMessage = "No internet connection."
            return
        }

        guard retryCount < 3 else { isGachaLoading = false; return }
        guard !isGachaLoading, !showPreviewCard else { return }
        isGachaLoading = true
        gachaCount += 1
        
        let shouldShowAd: Bool = {
            if storeManager.hasPurchasedAdFree { return false }
            if gachaCount == 1 { return false }
            if gachaCount - lastAdShownAt == 1 { return false }
            if gachaCount % 5 == 0 { return true }
            return Int.random(in: 1...5) == 1
        }()
        showAdThisTime = shouldShowAd
        if shouldShowAd { lastAdShownAt = gachaCount }
        
        if shouldShowAd {
            let delay = max(0, expectedSpinDuration - 0.15)
            if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showGachaCard = true }
                let generator = UIImpactFeedbackGenerator(style: .medium); generator.impactOccurred()
            }
            isGachaLoading = false
            return
        }
        
        let startTime = Date()
        do {
            guard let doc = try await PhotoService.shared.fetchRandomPhoto(scope: .global) else {
                DispatchQueue.main.async { gachaErrorMessage = "No photos yet." }
                isGachaLoading = false; return
            }
            
            gachaLatitude = doc.latitude; gachaLongitude = doc.longitude; gachaPhotoId = doc.id; gachaImagePath = doc.imagePath
            let image = try await PhotoService.shared.downloadImage(imagePath: doc.imagePath)
            
            let elapsed = Date().timeIntervalSince(startTime)
            let remaining = max(0, expectedSpinDuration - elapsed - 0.15)
            if remaining > 0 { try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000)) }
            
            let dateString = doc.createdAt.map { DateFormatter.zioraDisplay.string(from: $0.dateValue()) } ?? ""
            
            DispatchQueue.main.async {
                gachaCountry = doc.country; gachaRegion = doc.region; gachaCity = doc.city; gachaDateText = dateString; gachaImage = image
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showGachaCard = true }
                let generator = UIImpactFeedbackGenerator(style: .medium); generator.impactOccurred()
            }
            isGachaLoading = false
            
        } catch {
            print("Gacha Error: \(error)")
            let nsError = error as NSError
            let isNotFound = nsError.domain == "FIRStorageErrorDomain" && nsError.code == -13010
            let isNotExistMsg = error.localizedDescription.contains("does not exist")
            
            if isNotFound || isNotExistMsg {
                try? await PhotoService.shared.deletePhoto(documentId: gachaPhotoId, imagePath: gachaImagePath)
                isGachaLoading = false
                await performGacha(expectedSpinDuration: 0.5, retryCount: retryCount + 1)
                return
            }
            DispatchQueue.main.async { gachaErrorMessage = error.localizedDescription }
            isGachaLoading = false
        }
    }
}

// 0% -> 100% (spring効果で少しだけ大きく弾んで戻る)
struct PopUpModifier: ViewModifier {
    let scale: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
    }
}

struct ThreeDSlideModifier: ViewModifier {
    let angle: Double
    let yOffset: CGFloat
    let opacity: Double
    
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0))
            .offset(y: yOffset)
            .opacity(opacity)
    }
}

struct SuccessCheckmarkView: View {
    @State private var trimEnd: CGFloat = 0.0
    @State private var textOpacity: Double = 0.0
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 100, height: 100)
                    .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                
                CheckmarkShape()
                    .trim(from: 0, to: trimEnd)
                    .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                    .foregroundColor(Color(hex: "6C6BFF"))
                    .frame(width: 44, height: 44)
            }
            
            Text("Sent!")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                .opacity(textOpacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                trimEnd = 1.0
            }
            withAnimation(.easeOut(duration: 0.3).delay(0.1)) {
                textOpacity = 1.0
            }
        }
    }
}

struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.1, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.4, y: rect.maxY - rect.height * 0.1))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.1, y: rect.minY + rect.height * 0.1))
        return path
    }
}
