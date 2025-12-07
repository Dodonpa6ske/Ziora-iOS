import SwiftUI
import CoreLocation
import UIKit
import UniformTypeIdentifiers
import FirebaseAuth
import FirebaseFirestore

// 開発中はテスト用 ID を使う
let testNativeAdUnitID = "ca-app-pub-3940256099942544/3986624511"

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
    
    // 課金画面シート用
    @State private var showAdFreeSheet = false
    
    // 広告管理用
    @State private var gachaCount: Int = 0
    @State private var lastAdShownAt: Int = -100
    @State private var showAdThisTime = false
    
    private let gachaCardHeight: CGFloat = 520
    
    var body: some View {
        ZStack {
            ZioraBackgroundGradient()
                            .ignoresSafeArea()
            
            // 地球
            GlobeSceneView { spinDuration in
                Task { await performGacha(expectedSpinDuration: spinDuration) }
            }
            .ignoresSafeArea(edges: .top)
            .padding(.top, 40)
            .padding(.bottom, 140)
            
            // UIレイヤー
            VStack(spacing: 0) {
                // 上部ハンバーガー
                HStack {
                    Button {
                        // メニュー表示アニメーション（スプリング等はお好みで）
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
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
                
                Spacer()
                
                // 下部3ボタン
                HStack {
                    CircleIconButton(
                        systemName: "paperplane.fill", size: 60,
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
                                image: image, country: gachaCountry, region: gachaRegion, city: gachaCity,
                                dateText: gachaDateText, latitude: gachaLatitude, longitude: gachaLongitude,
                                photoId: gachaPhotoId, imagePath: gachaImagePath
                            )
                        }
                    }
                    .frame(height: gachaCardHeight)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 80)
                    .scaleEffect(showGachaCard ? 1.0 : 0.7)
                    .opacity(showGachaCard ? 1.0 : 0.0)
                }
                .transition(.asymmetric(insertion: .scale(scale: 0.7).combined(with: .opacity), removal: .scale(scale: 0.95).combined(with: .opacity)))
            }
            
            // 撮影プレビュー
            if showPreviewCard, let image = capturedImage {
                Color.black.opacity(0.3).ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { showPreviewCard = false; capturedImage = nil; previewOffset = 0 }
                    }
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        SwipeUpHint()
                        PreviewPhotoCard(
                            image: image, country: capturedCountry, region: capturedRegion, city: capturedCity,
                            dateText: capturedDateText, isUploading: isUploading,
                            onDeleteLayer: { key in
                                switch key {
                                case "country": capturedCountry = ""
                                case "region": capturedRegion = ""
                                case "city": capturedCity = ""
                                default: break
                                }
                            }
                        )
                    }
                    .offset(y: previewOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in if value.translation.height < 0 { previewOffset = value.translation.height } }
                            .onEnded { value in
                                if value.translation.height < -100 { Task { await uploadCurrentPhoto() } }
                                else { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { previewOffset = 0 } }
                            }
                    )
                }
            }
            
            // ===== ハンバーガーメニュー =====
            if showMenu {
                // 背景の暗転（タップで閉じる）
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeIn(duration: 0.22)) { showMenu = false }
                    }
                    .transition(.opacity) // 背景はフワッと消える
                
                HStack {
                    HamburgerMenuView(
                        isPresented: $showMenu,
                        onOpenAdFreePlan: { showAdFreeSheet = true },
                        onOpenNotificationSettings: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        },
                        onOpenLegal: {
                            if let url = URL(string: "https://www.notion.so/Ziora-Terms-of-Service-2c0aacfc1c6f801f934cdafe1e0bf063?source=copy_link") {
                                UIApplication.shared.open(url)
                            }
                        },
                        onOpenContact: {
                            openContactSupport()
                        },
                        onSignOut: {
                            showSignOutAlert = true
                        },
                        onDeleteAccount: {
                            showDeleteAccountAlert = true
                        }
                    )
                    .frame(width: 320)
                    // ★ 変更: .offset を削除し、transition で左からのスライドインを指定
                    .transition(.move(edge: .leading))
                    
                    Spacer()
                }
                .ignoresSafeArea()
                .zIndex(2) // 最前面に表示
            }
        }
        .onReceive(locationManager.$lastPlacemark) { placemark in
            guard let p = placemark else { return }
            let isoCode = p.isoCountryCode ?? ""
            capturedCountry = p.country ?? (isoCode.isEmpty ? "Country" : isoCode)
            var region = p.administrativeArea ?? ""
            var city = p.locality ?? p.subLocality ?? ""
            if !region.isEmpty, region == city { city = p.subLocality ?? "" }
            capturedRegion = region.isEmpty ? "State" : region
            capturedCity = city.isEmpty ? "City" : city
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
                            let impact = UIImpactFeedbackGenerator(style: .medium); impact.impactOccurred()
                            previewOffset = 0; withAnimation { showPreviewCard = true }
                        }
                    }
            }
        }
        .sheet(isPresented: $showLikedList) { NavigationStack { LikedListView() } }
        .sheet(isPresented: $showSentList) { NavigationStack { SentListView() } }
        .sheet(isPresented: $showAdFreeSheet) { AdFreePlanView() }
        
        // ===== アラート群 =====
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Sign Out", role: .destructive) {
                try? AuthManager.shared.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    try? await AuthManager.shared.deleteAccount()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
        .alert("Error", isPresented: Binding(get: { uploadErrorMessage != nil || gachaErrorMessage != nil }, set: { _ in uploadErrorMessage = nil; gachaErrorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(uploadErrorMessage ?? gachaErrorMessage ?? "")
        }
        .preferredColorScheme(.light)
    }
    
    // メール起動ヘルパー
    private func openContactSupport() {
        let email = "ziora.app.contact@gmail.com"
        let subject = "Ziora Support"
        let body = "Please describe your issue or feedback here."
        
        let urlString = "mailto:\(email)?subject=\(subject)&body=\(body)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: urlString) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                print("Cannot open mail client")
            }
        }
    }
    
    private func uploadCurrentPhoto() async {
        guard !isUploading, let image = capturedImage else { return }
        isUploading = true
        let loc = locationManager.lastLocation
        let placemark = locationManager.lastPlacemark
        let meta = PhotoMeta(country: capturedCountry, region: capturedRegion, city: capturedCity, countryCode: placemark?.isoCountryCode ?? "", latitude: loc?.coordinate.latitude, longitude: loc?.coordinate.longitude, dateText: capturedDateText)
        do {
            _ = try await PhotoService.shared.uploadPhoto(image: image, meta: meta)
            withAnimation { showPreviewCard = false; capturedImage = nil; previewOffset = 0 }
            let generator = UINotificationFeedbackGenerator(); generator.notificationOccurred(.success)
        } catch { uploadErrorMessage = error.localizedDescription }
        isUploading = false
    }
    
    private func performGacha(expectedSpinDuration: TimeInterval) async {
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
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { showGachaCard = true }
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
                gachaCountry = doc.country; gachaRegion = doc.region; gachaCity = doc.city; gachaDateText = dateString; gachaLatitude = doc.latitude; gachaLongitude = doc.longitude; gachaImage = image
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { showGachaCard = true }
                let generator = UIImpactFeedbackGenerator(style: .medium); generator.impactOccurred()
            }
        } catch {
            DispatchQueue.main.async { gachaErrorMessage = error.localizedDescription }
        }
        isGachaLoading = false
    }
}
