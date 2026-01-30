import SwiftUI
import CoreLocation
import UIKit
import UniformTypeIdentifiers
import FirebaseAuth
import FirebaseFirestore
import StoreKit
import AppTrackingTransparency

struct AdConfig {
    static var nativeAdUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/3986624511"
        #else
        return "ca-app-pub-9291029167690966/8530992058"
        #endif
    }
}

struct HomeView: View {
    var animateEntry: Bool = false // アニメーションを実行するかどうか
    @State private var isVisible: Bool = false // 表示状態管理
    @State private var showTutorial: Bool = false // チュートリアル表示フラグ
    @State private var showCameraTutorial: Bool = false // ★追加: カメラ誘導チュートリアル

    var onOpenMenu: () -> Void = {}
    var onOpenCamera: () -> Void = {}
    var onOpenSentList: () -> Void = {}
    var onOpenLikedList: () -> Void = {}

    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject var storeManager: StoreManager
    @StateObject private var interactionState = InteractionState()
    @State private var localDragOffset: CGFloat = 0

    // UI Layout Constants
    private let gachaCardHeight: CGFloat = 520

    // ★追加: ローカライズ
    @AppStorage("selectedLanguage") private var language: String = "en"
    private func localized(_ key: String) -> String {
        if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
        }
        return key
    }

    var body: some View {
        ZStack {
            ParticleBackgroundView()
            

            

            
            GlobeSceneView(
                onSpin: { spinDuration in
                    Task { await viewModel.performGacha(expectedSpinDuration: spinDuration, storeManager: storeManager) }
                },
                onCardTiming: {
                    viewModel.triggerCardDisplay()
                },
                interactionState: interactionState,
                isInteractionEnabled: !showCameraTutorial // ★追加: カメラチュートリアル中はスワイプ無効
            )
            .ignoresSafeArea(edges: .top)
            .padding(.top, 40)
            .padding(.bottom, 140)
            // Globe Animation: Scale 0 -> 1, Opacity 0 -> 1
            .scaleEffect((animateEntry && !isVisible) ? 0.3 : 1.0)
            .opacity((animateEntry && !isVisible) ? 0.0 : 1.0)
            

            
            // UI Layer
            VStack(spacing: 0) {
                // Header (Menu)
                HStack {
                    Button {
                        withAnimation(.easeOut(duration: 0.25)) { viewModel.showMenu = true }
                        onOpenMenu()
                    } label: {
                        VStack(alignment: .leading, spacing: 6) { // Spacing adjust slightly for thinner lines? Let's keep 5 or 6. 5 is fine.
                            Capsule()
                                .fill(Color.white)
                                .frame(width: 30, height: 2) // 3 -> 2
                            Capsule()
                                .fill(Color.white)
                                .frame(width: 15, height: 2) // 3 -> 2
                        }
                        .frame(width: 30, height: 30, alignment: .center)
                    }
                    .padding(.leading, 30)
                    Spacer()
                }
                .padding(.top, 50)
                .opacity(viewModel.showPreviewCard ? 0 : 1)
                // Header Animation: Slide down from top
                .offset(y: (animateEntry && !isVisible) ? -150 : 0)
                
                Spacer()
                
                // Footer (Buttons)
                HStack {
                    CircleIconButton(
                        systemName: "photo.fill", size: 60,
                        foreground: Color(hex: "908FF7"), background: .white, showShadow: false
                    ) { viewModel.showSentList = true; onOpenSentList() }
                    // Left Button: Slide from left
                    .offset(x: (animateEntry && !isVisible) ? -150 : 0)
                    
                    Spacer()
                    
                    CameraMainButton { viewModel.showCamera = true; onOpenCamera() }
                    // Center Button: Pop up from bottom
                    .offset(y: (animateEntry && !isVisible) ? 200 : 0)
                    
                    Spacer()
                    
                    CircleIconButton(
                        systemName: "heart.fill", size: 60,
                        foreground: Color(hex: "908FF7"), background: .white, showShadow: false
                    ) { viewModel.showLikedList = true; onOpenLikedList() }
                    // Right Button: Slide from right
                    .offset(x: (animateEntry && !isVisible) ? 150 : 0)
                }
                .padding(.horizontal, 33)
                .padding(.bottom, 40)
                .opacity(viewModel.showPreviewCard ? 0 : 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Fix: remove specific animation for nil value if needed, or keep to disable unwanted animations
            .animation(nil, value: viewModel.showGachaCard)
            .onAppear {
                if animateEntry {
                    // Start Journey! -> Globe Pop & Buttons Gather
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                        isVisible = true
                    }

                    // Show tutorial after animation if first time
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        let hasSeenTutorial = UserDefaults.standard.bool(forKey: "hasSeenTutorial")
                        if !hasSeenTutorial {
                            withAnimation(.easeIn(duration: 0.3)) {
                                showTutorial = true
                            }
                        }
                    }
                } else {
                    isVisible = true
                }

                // Request ATT (IDFA)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    ATTrackingManager.requestTrackingAuthorization { _ in }
                }

                // Preload Ad
                viewModel.preloadAd(storeManager: storeManager)
            }
            
            // --- Gacha Card ---
            if viewModel.showGachaCard {
                Color.black.opacity(0.35).ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { viewModel.showGachaCard = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { viewModel.gachaImage = nil }
                    }
                
                VStack {
                    Spacer()
                    Group {
                        if viewModel.showAdThisTime, let adVM = viewModel.adViewModel {
                            GachaCardShell(padding: 0) { NativeAdCardView(viewModel: adVM) }
                        } else if let image = viewModel.gachaImage {
                            GachaResultCard(
                                image: image,
                                country: viewModel.gachaCountry,
                                region: viewModel.gachaRegion,
                                city: viewModel.gachaCity,
                                subLocality: viewModel.gachaSubLocality, // ★追加
                                dateText: viewModel.gachaDateText,
                                latitude: viewModel.gachaLatitude,
                                longitude: viewModel.gachaLongitude,
                                photoId: viewModel.gachaPhotoId,
                                imagePath: viewModel.gachaImagePath,
                                userId: viewModel.gachaOwnerId, // ★追加
                                likeCount: 0,
                                showLikeButton: true,
                                likerCountry: viewModel.capturedCountry, // ★追加: 自分の現在地を渡す
                                likerCountryCode: viewModel.capturedCountryCode // ★追加: 国コード
                            )
                        }
                    }
                    .frame(height: gachaCardHeight)
                    // ★修正: Paddingではなく固定幅を指定
                    .frame(width: UIScreen.main.bounds.width - 48)
                    Spacer()
                }
                .offset(y: -40)
                .transition(.asymmetric(
                    insertion: .modifier(active: PopUpModifier(scale: 0.0, opacity: 0), identity: PopUpModifier(scale: 1.0, opacity: 1)),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.showGachaCard)
            }
            
            // --- Completion Card ---
            // --- Completion Card ---
            if viewModel.showCompletionCard {
                Color.black.opacity(0.35).ignoresSafeArea()
                    .onTapGesture {
                        viewModel.showCompletionCard = false
                    }
                
                VStack {
                    Spacer()
                    CompletionCardView(
                        onReset: {
                             viewModel.resetSeenHistory()
                        },
                        onReview: {
                            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                                SKStoreReviewController.requestReview(in: scene)
                            }
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                    .onAppear {
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                    Spacer()
                }
                .offset(y: -40) // ★追加: GachaCardと同じ位置補正
                .transition(.asymmetric(
                    insertion: .modifier(active: PopUpModifier(scale: 0.0, opacity: 0), identity: PopUpModifier(scale: 1.0, opacity: 1)),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
                .zIndex(50) // GachaCardより上に
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.showCompletionCard)
            }
            
            // --- Capture Preview ---
            if viewModel.showPreviewCard, let image = viewModel.capturedImage {
                Color.black.opacity(0.3).ignoresSafeArea()
                    .onTapGesture { viewModel.resetPreview() }
                    .opacity(viewModel.isFlyingAway ? 0 : 1)

                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        SwipeUpHint().opacity(viewModel.isFlyingAway ? 0 : 1)
                        PreviewPhotoCard(
                            image: image,
                            country: viewModel.capturedCountry,
                            region: viewModel.capturedRegion,
                            city: viewModel.capturedCity,
                            subLocality: viewModel.capturedSubLocality, // ★追加
                            dateText: viewModel.capturedDateText,
                            isUploading: viewModel.isUploading,
                            onDeleteLayer: { key in
                                switch key {
                                case "country": viewModel.capturedCountry = ""
                                case "region": viewModel.capturedRegion = ""
                                case "city": viewModel.capturedCity = ""
                                case "subLocality": viewModel.capturedSubLocality = ""
                                default: break
                                }
                            }
                        )
                        .frame(height: gachaCardHeight)
                        .frame(width: 320) // Fixed width to standard size
                        // ViewModelのアニメーション値(isFlyingAway等)か、ローカルのドラッグ値かを使用
                        .offset(y: viewModel.isFlyingAway 
                            ? -UIScreen.main.bounds.height * 1.5 
                            : (localDragOffset != 0 ? localDragOffset : viewModel.previewOffset))
                        .scaleEffect(viewModel.isFlyingAway ? 0.9 : 1.0)
                    }

                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.height < 0 {
                                    // ローカルStateで更新してハイパフォーマンスな追従を実現
                                    localDragOffset = value.translation.height
                                }
                            }
                            .onEnded { value in
                                if value.translation.height < -100 {
                                    // 閾値を超えたらViewModelへ通達してアニメーション開始
                                    // アニメーションの整合性を保つため一時的にViewModelのOffsetには今の値をセット
                                    viewModel.previewOffset = localDragOffset
                                    viewModel.startFlyAwayAnimation()
                                    // ローカルはリセットしておく（ViewはViewModelの値を見るようになる）
                                    localDragOffset = 0
                                } else {
                                    // キャンセル：バネで戻る
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        localDragOffset = 0
                                    }
                                }
                            }
                    )
                    Spacer()
                }
                .transition(.modifier(active: ThreeDSlideModifier(angle: 45, yOffset: 600, opacity: 0), identity: ThreeDSlideModifier(angle: 0, yOffset: 0, opacity: 1)))
            }
            
            // --- Uploading Loading Indicator ---
            // Sent!が出るまでの間、アップロード中であることを示す
            if (viewModel.isUploading || viewModel.isFlyingAway) && !viewModel.showSuccessCheckmark {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        Text("Uploading...")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if viewModel.showCancelUploadButton {
                            Button {
                                viewModel.cancelUpload()
                            } label: {
                                Text("Cancel")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.25))
                                    .cornerRadius(20)
                            }
                            .transition(.opacity)
                        }
                    }
                }
                .transition(.opacity)
                .zIndex(90)
            }

            
            // --- Overlays & Sheets ---
            if viewModel.showSuccessCheckmark { SuccessCheckmarkView().transition(.scale.combined(with: .opacity)).zIndex(100) }
            if viewModel.showAdFreeSheet { AdFreePlanView(isPresented: $viewModel.showAdFreeSheet).zIndex(200) }
            if viewModel.showLinkAccountSheet { LinkAccountView(isPresented: $viewModel.showLinkAccountSheet).zIndex(200) }
            if viewModel.showLanguageSheet { LanguageSettingsView(isPresented: $viewModel.showLanguageSheet).zIndex(200) }
            if viewModel.showContactSheet { ContactView(isPresented: $viewModel.showContactSheet).zIndex(200) }
            
            if viewModel.showMenu {
                Color.black.opacity(0.3).ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeIn(duration: 0.22)) { viewModel.showMenu = false } }
                    .transition(.opacity)
                
                HStack(spacing: 0) {
                    HamburgerMenuView(
                        isPresented: $viewModel.showMenu,
                        onOpenAdFreePlan: { withAnimation { viewModel.showAdFreeSheet = true } },
                        onOpenNotificationSettings: { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } },
                        onOpenLanguage: { viewModel.showLanguageSheet = true },
                        onOpenTerms: { if let url = URL(string: localized("TermsUrl")) { UIApplication.shared.open(url) } },
                        onOpenPrivacy: { if let url = URL(string: localized("PrivacyUrl")) { UIApplication.shared.open(url) } },
                        onOpenContact: { withAnimation { viewModel.showContactSheet = true } },
                        onOpenLinkAccount: { withAnimation { viewModel.showLinkAccountSheet = true } },
                        onSignOut: { viewModel.showSignOutAlert = true },
                        onDeleteAccount: { viewModel.showDeleteAccountAlert = true }
                    )
                    .frame(width: 320)
                    Spacer()
                }
                .ignoresSafeArea()
                .transition(.move(edge: .leading))
                .zIndex(2)
            }

            // Tutorial overlay
            if showTutorial {
                TutorialOverlayView(isShowing: $showTutorial)
                    .zIndex(100)
                    .onChange(of: interactionState.hasSpunGlobe) { hasSpun in
                        if hasSpun && showTutorial {
                            UserDefaults.standard.set(true, forKey: "hasSeenTutorial")
                            withAnimation(.easeOut(duration: 0.3)) {
                                showTutorial = false
                            }
                        }
                    }
            }
            
            // Camera Tutorial Overlay
            if showCameraTutorial {
                CameraTutorialOverlayView(
                    isShowing: $showCameraTutorial,
                    onOpenCamera: {
                        viewModel.showCamera = true
                        onOpenCamera()
                    }
                )
                .zIndex(150)
            }
        }
        .fullScreenCover(isPresented: $viewModel.showCamera) {
            ZStack {
                Color.black.ignoresSafeArea()
                PhotoCaptureView(image: $viewModel.capturedImage).ignoresSafeArea()
                    .onDisappear {
                        viewModel.onCameraDismissed()
                    }
            }
        }
        .sheet(isPresented: $viewModel.showLikedList) { LikedListView() } // NavStack削除 (全画面ぼかし対応)
        .sheet(isPresented: $viewModel.showSentList) { SentListView(highlightId: viewModel.highlightPhotoId) } // NavStack削除 (全画面表示優先)
        .alert(localized("Sign Out"), isPresented: $viewModel.showSignOutAlert) {
            Button(localized("Sign Out"), role: .destructive) { viewModel.signOut() }
            Button(localized("Cancel"), role: .cancel) {}
        } message: { Text(localized("Are you sure you want to sign out?")) }
        .alert(localized("Delete Account"), isPresented: $viewModel.showDeleteAccountAlert) {
            Button(localized("Delete"), role: .destructive) { viewModel.deleteAccount() }
            Button(localized("Cancel"), role: .cancel) {}
        } message: { Text(localized("This action cannot be undone. All your data will be permanently deleted.")) }
        .alert(localized("Error"), isPresented: Binding(get: { viewModel.uploadErrorMessage != nil || viewModel.gachaErrorMessage != nil }, set: { _ in viewModel.uploadErrorMessage = nil; viewModel.gachaErrorMessage = nil })) { Button("OK", role: .cancel) {} } message: { Text(viewModel.uploadErrorMessage ?? viewModel.gachaErrorMessage ?? "") }
        .onChange(of: viewModel.showGachaCard) { show in 
            interactionState.isIdlePaused = viewModel.showGachaCard || viewModel.showPreviewCard || viewModel.showCompletionCard
            
            // ★追加: チュートリアルスピンが終わってカードを閉じた時、カメラ誘導を開始
            if !show {
                let hasSpin = UserDefaults.standard.bool(forKey: "hasCompletedSpinTutorial")
                let hasCam = UserDefaults.standard.bool(forKey: "hasSeenCameraTutorial")
                
                // チュートリアルスピン完了済み ＆ カメラ誘導未実施 なら表示
                if hasSpin && !hasCam {
                    // 少し遅延させて余韻を持たせる
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation { showCameraTutorial = true }
                    }
                }
            }
        }        .onChange(of: viewModel.showPreviewCard) { _ in interactionState.isIdlePaused = viewModel.showGachaCard || viewModel.showPreviewCard || viewModel.showCompletionCard }
        .onChange(of: viewModel.showCompletionCard) { _ in interactionState.isIdlePaused = viewModel.showGachaCard || viewModel.showPreviewCard || viewModel.showCompletionCard }
        .onChange(of: viewModel.isGachaLoading) { val in interactionState.isGachaLoading = val }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenSentList"))) { notification in
            if let photoId = notification.userInfo?["photoId"] as? String {
                // シートが表示されていたら閉じるなどの整合性処理も必要ならここで行う
                viewModel.highlightPhotoId = photoId
                viewModel.showSentList = true
            }
        }
        .preferredColorScheme(.light)
    }
}

// MARK: - Modifiers & Helper Views
// (Previous code had these at the bottom, keeping them here)

struct PopUpModifier: ViewModifier {
    let scale: CGFloat; let opacity: Double
    func body(content: Content) -> some View { content.scaleEffect(scale).opacity(opacity) }
}
struct ThreeDSlideModifier: ViewModifier {
    let angle: Double; let yOffset: CGFloat; let opacity: Double
    func body(content: Content) -> some View { content.rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0)).offset(y: yOffset).opacity(opacity) }
}

struct SuccessCheckmarkView: View {
    @State private var trimEnd: CGFloat = 0.0; @State private var textOpacity: Double = 0.0
    // ★追加: ローカライズ
    @AppStorage("selectedLanguage") private var language: String = "en"
    private func localized(_ key: String) -> String {
        if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
        }
        return key
    }

    var body: some View {
        VStack(spacing: 20) {
            ZStack { Circle().fill(Color.white).frame(width: 100, height: 100).shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5); CheckmarkShape().trim(from: 0, to: trimEnd).stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)).foregroundColor(Color(hex: "6C6BFF")).frame(width: 44, height: 44) }
            Text(localized("Sent!")).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.white).shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2).opacity(textOpacity)
        }
        .onAppear { withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { trimEnd = 1.0 }; withAnimation(.easeOut(duration: 0.3).delay(0.1)) { textOpacity = 1.0 } }
    }
}
struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path { var path = Path(); path.move(to: CGPoint(x: rect.minX + rect.width * 0.1, y: rect.midY)); path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.4, y: rect.maxY - rect.height * 0.1)); path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.1, y: rect.minY + rect.height * 0.1)); return path }
}
