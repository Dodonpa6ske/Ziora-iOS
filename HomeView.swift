import SwiftUI
import CoreLocation
import UIKit
import UniformTypeIdentifiers
import FirebaseAuth
import FirebaseFirestore

// 開発中はテスト用 ID を使う
let testNativeAdUnitID = "ca-app-pub-3940256099942544/3986624511"
// 本番前にあなたのネイティブアドバンスの広告ユニットIDに差し替える

struct HomeView: View {
    // Navigation handlers（今は未使用でもOK）
    var onOpenMenu: () -> Void = {}
    var onOpenCamera: () -> Void = {}
    var onOpenSentList: () -> Void = {}
    var onOpenLikedList: () -> Void = {}
    
    // ===== State =====
    @State private var showMenu = false
    
    // Capture / upload state
    @State private var showCamera = false
    @State private var capturedImage: UIImage? = nil
    
    @State private var showPreviewCard = false
    @State private var isUploading = false
    @State private var uploadErrorMessage: String? = nil
    @State private var previewOffset: CGFloat = 0
    
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
    
    // ★ 広告管理用の新しいState
    @State private var gachaCount: Int = 0           // ガチャ実行回数
    @State private var lastAdShownAt: Int = -100     // 最後に広告を表示したガチャ回数
    @State private var showAdThisTime = false        // 今回広告を出すか
    
    // ガチャカード / 広告カードの共通高さ
    private let gachaCardHeight: CGFloat = 520
    
    var body: some View {
        ZStack {
            // 背景グラデーション
            ZioraBackgroundGradient()
                .ignoresSafeArea()
            
            // 中央の地球（スワイプでガチャ）
            GlobeSceneView { spinDuration in
                Task { await performGacha(expectedSpinDuration: spinDuration) }
            }
            .ignoresSafeArea(edges: .top)
            .padding(.top, 40)
            .padding(.bottom, 140)
            
            // 上ハンバーガー / 下部ボタン群
            VStack(spacing: 0) {
                // 上部ハンバーガー
                HStack {
                    Button {
                        // メニュー表示:左からスライドイン（easeOut）
                        withAnimation(.easeOut(duration: 0.28)) {
                            showMenu = true
                        }
                        onOpenMenu()
                    } label: {
                        HamburgerIcon()
                            .frame(width: 30, height: 30)
                    }
                    .padding(.leading, 30)
                    
                    Spacer()
                }
                .padding(.top, 50)
                
                Spacer()
                
                // 下部3ボタン
                HStack {
                    // 送信した写真リスト
                    CircleIconButton(
                        systemName: "paperplane.fill",
                        size: 60,
                        foreground: Color(hex: "908FF7"),
                        background: .white,
                        showShadow: false
                    ) {
                        showSentList = true
                        onOpenSentList()
                    }
                    
                    Spacer()
                    
                    // カメラ
                    CameraMainButton {
                        showCamera = true
                        onOpenCamera()
                    }
                    
                    Spacer()
                    
                    // いいねリスト
                    CircleIconButton(
                        systemName: "heart.fill",
                        size: 60,
                        foreground: Color(hex: "908FF7"),
                        background: .white,
                        showShadow: false
                    ) {
                        showLikedList = true
                        onOpenLikedList()
                    }
                }
                .padding(.horizontal, 33)
                .padding(.bottom, 40)
            }
            
            // ===== ガチャ結果オーバーレイ =====
            if showGachaCard {
                // 背景を暗くするレイヤー（ホーム画面の上にかぶせる）
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // タップでポップアップを閉じる
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showGachaCard = false
                        }
                        // ★ 少し遅延させてから画像をクリア（アニメーション完了後）
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            gachaImage = nil
                        }
                    }

                VStack {
                    Spacer()

                    Group {
                        if showAdThisTime {
                            // ★ 広告カードを GachaCardShell でラップ
                            GachaCardShell {
                                NativeAdCardView(adUnitID: testNativeAdUnitID)
                            }
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
                                imagePath: gachaImagePath
                            )
                        }
                    }
                    .frame(height: gachaCardHeight)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 80)
                    // ★ よりメリハリのあるポップアップアニメーション
                    .scaleEffect(showGachaCard ? 1.0 : 0.7)
                    .opacity(showGachaCard ? 1.0 : 0.0)
                }
                // ★ より弾むポップアップのトランジション
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.7).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    )
                )
            }
            
            // ===== 撮影プレビューオーバーレイ =====
            if showPreviewCard, let image = capturedImage {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            showPreviewCard = false
                            capturedImage = nil
                            previewOffset = 0
                        }
                    }
                
                VStack {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        SwipeUpHint()
                        
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
                                case "region":  capturedRegion  = ""
                                case "city":    capturedCity    = ""
                                default: break
                                }
                            }
                        )
                    }
                    .offset(y: previewOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.height < 0 {
                                    previewOffset = value.translation.height
                                }
                            }
                            .onEnded { value in
                                if value.translation.height < -100 {
                                    Task { await uploadCurrentPhoto() }
                                } else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        previewOffset = 0
                                    }
                                }
                            }
                    )
                }
            }
            
            // ===== ハンバーガーメニュー =====
            if showMenu {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // メニュー外をタップでも閉じる（easeIn）
                        withAnimation(.easeIn(duration: 0.22)) {
                            showMenu = false
                        }
                    }
                
                HStack {
                    HamburgerMenuView(
                        isPresented: $showMenu,
                        onOpenSentList: {
                            showSentList = true
                        },
                        onOpenLikedList: {
                            showLikedList = true
                        },
                        onOpenAdFreePlan: {
                            // TODO: Ad-free 画面
                        },
                        onOpenNotificationSettings: {
                            // TODO: 通知設定画面
                        },
                        onOpenLegal: {
                            // TODO: 利用規約 / プライバシー画面
                        }
                    )
                    .frame(width: 320)
                    .offset(x: showMenu ? 0 : -340)
                    
                    Spacer()
                }
                .ignoresSafeArea()
            }
        }
        // ===== 位置情報の更新 =====
        .onReceive(locationManager.$lastPlacemark) { placemark in
            guard let p = placemark else { return }
            
            let isoCode = p.isoCountryCode ?? ""
            
            capturedCountry = p.country ?? (isoCode.isEmpty ? "Country" : isoCode)
            
            var region = p.administrativeArea ?? ""
            var city   = p.locality ?? p.subLocality ?? ""
            
            if !region.isEmpty, region == city {
                city = p.subLocality ?? ""
            }
            
            capturedRegion = region.isEmpty ? "State" : region
            capturedCity   = city.isEmpty   ? "City"  : city
        }
        
        // ===== カメラシート =====
        .fullScreenCover(isPresented: $showCamera) {
            ZStack {
                Color.black.ignoresSafeArea()
                
                PhotoCaptureView(image: $capturedImage)
                    .ignoresSafeArea()
                    .onDisappear {
                        if capturedImage != nil {
                            capturedDateText = DateFormatter.zioraDisplay.string(from: Date())
                            locationManager.requestLocation()
                            
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            
                            previewOffset = 0
                            withAnimation {
                                showPreviewCard = true
                            }
                        }
                    }
            }
        }
        
        // いいねリスト
        .sheet(isPresented: $showLikedList) {
            NavigationStack {
                LikedListView()
            }
        }
        
        // 送信リスト
        .sheet(isPresented: $showSentList) {
            NavigationStack {
                SentListView()
            }
        }
        
        // ===== エラーアラート =====
        .alert("Error", isPresented: Binding(
            get: { uploadErrorMessage != nil || gachaErrorMessage != nil },
            set: { _ in
                uploadErrorMessage = nil
                gachaErrorMessage = nil
            }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(uploadErrorMessage ?? gachaErrorMessage ?? "")
        }
        .preferredColorScheme(.light)
    }
    
    // MARK: - Upload helper
    
    private func uploadCurrentPhoto() async {
        guard !isUploading, let image = capturedImage else { return }
        isUploading = true
        
        let loc = locationManager.lastLocation
        let placemark = locationManager.lastPlacemark
        
        let meta = PhotoMeta(
            country: capturedCountry,
            region: capturedRegion,
            city: capturedCity,
            countryCode: placemark?.isoCountryCode ?? "",
            latitude: loc?.coordinate.latitude,
            longitude: loc?.coordinate.longitude,
            dateText: capturedDateText
        )
        
        do {
            _ = try await PhotoService.shared.uploadPhoto(image: image, meta: meta)
            
            withAnimation {
                showPreviewCard = false
                capturedImage = nil
                previewOffset = 0
            }
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            uploadErrorMessage = error.localizedDescription
        }
        
        isUploading = false
    }
    
    // MARK: - Gacha helper
    
    private func performGacha(expectedSpinDuration: TimeInterval) async {
        // 連打防止 & プレビュー中は無効
        guard !isGachaLoading, !showPreviewCard else { return }
        isGachaLoading = true

        // ★ ガチャ回数をインクリメント
        gachaCount += 1

        // ★ 広告表示ロジック
        // 1. 初回（gachaCount == 1）は広告を出さない
        // 2. 前回広告を出していたら（gachaCount - lastAdShownAt == 1）今回は出さない
        // 3. 5回に1回は必ず広告を出す（gachaCount % 5 == 0）
        // 4. それ以外はランダム（1/5の確率）
        
        let shouldShowAd: Bool = {
            // 初回は広告を出さない
            if gachaCount == 1 {
                return false
            }
            
            // 前回広告を出していたら今回は出さない（連続表示防止）
            if gachaCount - lastAdShownAt == 1 {
                return false
            }
            
            // 5回に1回は必ず広告
            if gachaCount % 5 == 0 {
                return true
            }
            
            // それ以外はランダム（1/5の確率）
            return Int.random(in: 1...5) == 1
        }()
        
        showAdThisTime = shouldShowAd
        
        // 広告を出す場合は記録
        if shouldShowAd {
            lastAdShownAt = gachaCount
        }

        if shouldShowAd {
            // ② 広告だけ出す場合:スピン時間に合わせて少し待ってから広告カードを表示
            let delay = max(0, expectedSpinDuration - 0.15)
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            DispatchQueue.main.async {
                // ★ よりメリハリのあるポップアップアニメーション
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    showGachaCard = true
                }

                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }

            isGachaLoading = false
            return
        }

        // ③ ここから下は「普通のガチャ（写真表示）」の処理
        let startTime = Date()

        do {
            // ランダムな写真ドキュメント取得
            guard let doc = try await PhotoService.shared.fetchRandomPhoto(scope: .global) else {
                DispatchQueue.main.async {
                    gachaErrorMessage = "No photos yet."
                }
                isGachaLoading = false
                return
            }

            gachaLatitude  = doc.latitude
            gachaLongitude = doc.longitude
            gachaPhotoId   = doc.id
            gachaImagePath = doc.imagePath

            // 画像本体のダウンロード
            let image = try await PhotoService.shared.downloadImage(imagePath: doc.imagePath)

            // スピン時間に合わせて残りを待つ
            let elapsed = Date().timeIntervalSince(startTime)
            let remaining = max(0, expectedSpinDuration - elapsed - 0.15)
            if remaining > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }

            let dateString: String = {
                if let ts = doc.createdAt {
                    return DateFormatter.zioraDisplay.string(from: ts.dateValue())
                } else {
                    return ""
                }
            }()

            // UI 反映はメインスレッドで
            DispatchQueue.main.async {
                gachaCountry   = doc.country
                gachaRegion    = doc.region
                gachaCity      = doc.city
                gachaDateText  = dateString
                gachaLatitude  = doc.latitude
                gachaLongitude = doc.longitude
                gachaImage     = image

                // ★ よりメリハリのあるポップアップアニメーション
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    showGachaCard = true
                }

                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }
        } catch {
            DispatchQueue.main.async {
                gachaErrorMessage = error.localizedDescription
            }
        }

        isGachaLoading = false
    }
}
