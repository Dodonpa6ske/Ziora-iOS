import SwiftUI
import Combine
import CoreLocation
import FirebaseAuth
import FirebaseFirestore
import GoogleMobileAds
import UIKit

@MainActor
class HomeViewModel: ObservableObject {
    
    // Helper to get string from specific language bundle
    private func localized(_ key: String) -> String {
        let lang = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en"
        if let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(key, tableName: nil, bundle: bundle, value: "", comment: "")
        }
        return key
    }

    // MARK: - UI State Flags
    @Published var showMenu = false
    @Published var showSignOutAlert = false
    @Published var showDeleteAccountAlert = false
    
    @Published var showCamera = false
    @Published var showPreviewCard = false
    @Published var isUploading = false
    @Published var uploadErrorMessage: String? = nil
    @Published var previewOffset: CGFloat = 0
    @Published var isFlyingAway = false
    @Published var showSuccessCheckmark = false
    
    @Published var showLanguageSheet = false
    @Published var showContactSheet = false
    @Published var showAdFreeSheet = false
    @Published var showLinkAccountSheet = false
    @Published var showLikedList = false
    @Published var showSentList = false
    
    // ★追加: 通知経由で特定の写真を開く用
    @Published var highlightPhotoId: String? = nil
    
    // MARK: - Ad Support
    // MARK: - Ad Support
    @Published var adViewModel: NativeAdViewModel? = nil
    private var nextAdViewModel: NativeAdViewModel? = nil // Preloaded ad

    // MARK: - Persistent State (Seen Photos)

    // 既読管理: UserDefaultsに保存する単純なリスト
    private let seenPhotosKey = "seenPhotoIds"
    private var seenPhotoIds: Set<String> {
        get {
            let list = UserDefaults.standard.stringArray(forKey: seenPhotosKey) ?? []
            return Set(list)
        }
        set {
            let list = Array(newValue)
            UserDefaults.standard.set(list, forKey: seenPhotosKey)
        }
    }
    
    // MARK: - Photo Capture State
    @Published var capturedImage: UIImage? = nil
    @Published var capturedCountry: String = "Country" // Default placeholder
    @Published var capturedCountryCode: String? = nil // ★追加: 国コード (通知ローカライズ用)
    @Published var capturedRegion: String  = ""
    @Published var capturedCity: String    = "City"    // Default placeholder
    @Published var capturedSubLocality: String = ""
    @Published var capturedDateText: String = ""
    
    // MARK: - Gacha State
    @Published var isGachaLoading = false
    @Published var gachaImage: UIImage? = nil
    @Published var showGachaCard = false
    @Published var gachaCountry: String = ""
    @Published var gachaRegion: String  = ""
    @Published var gachaCity: String    = ""
    @Published var gachaSubLocality: String = ""
    @Published var gachaDateText: String = ""
    @Published var gachaLatitude: Double? = nil
    @Published var gachaLongitude: Double? = nil
    @Published var gachaErrorMessage: String? = nil
    @Published var gachaPhotoId: String = ""
    @Published var gachaOwnerId: String = "" // ★追加: 写真の持ち主ID (いいね通知用)
    @Published var gachaImagePath: String = ""
    @Published var showAdThisTime = false
    @Published var showCompletionCard = false // ★追加: コンプリート画面用

    // MARK: - Private / Logic State
    private var gachaCount: Int = 0
    private var lastAdShownAt: Int = -100
    
    // MARK: - Dependencies
    private var cancellables = Set<AnyCancellable>()
    let locationManager = LocationManager.shared
    let networkMonitor = NetworkMonitor.shared
    
    init() {
        // locationManager.requestLocation() // Removed to delay permission request until after photo capture
        setupLocationBinding()
        // 初回用の写真をプリロード開始
        self.preloadNextPhoto()
        // Ad preload will be triggered in onAppear or first gacha to avoid checking storeManager too early
        
        // ★追加: GPS取得前でも、端末のロケールから国名を入れておく（通知の "Countryの人が..." 回避）
        // アプリ内言語設定(selectedLanguage)を優先し、なければ端末設定を使う
        let langCode = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en"
        let locale = Locale(identifier: langCode) // or Locale.current
        if let regionCode = Locale.current.regionCode { // 端末の物理的な国設定を取得
             self.capturedCountry = locale.localizedString(forRegionCode: regionCode) ?? "Country"
             self.capturedCountryCode = regionCode // ★追加: 初期値
        }
        
        // ★追加: 起動時に言語設定を同期
        syncLanguage()
        
        // ★追加: 送信リストのプレハブ (キャッシュに乗せる)
        self.prefetchSentList()
    }
    
    // ... existing syncLanguage ...

    // ★追加: SentListの事前読み込み
    private func prefetchSentList() {
        Task {
            do {
                // SentListViewと同じ条件(limit: 6)で取得してキャッシュに載せる
                // こうすることで、リストを開いた瞬間に同期的に画像が表示される（キャッシュヒットするため）
                let result = try await PhotoService.shared.fetchMyPhotos(limit: 6)
                
                // 順次ダウンロード (並列でも良いが、帯域圧迫を避けるため順次またはTaskGroup)
                await withTaskGroup(of: Void.self) { group in
                    for doc in result.photos {
                        group.addTask {
                            _ = try? await PhotoService.shared.downloadThumbnail(originalPath: doc.imagePath)
                        }
                    }
                }
                print("📦 SentList pre-fetched (\(result.photos.count) items)")
            } catch {
                print("Pre-fetch SentList failed: \(error)")
            }
        }
    }
    
    private func syncLanguage() {
        let lang = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en"
        PhotoService.shared.saveUserLanguage(lang)
    }
    
    private func setupLocationBinding() {
        // 現在地情報の更新を監視
        locationManager.$lastPlacemark
            .receive(on: RunLoop.main)
            .sink { [weak self] placemark in
                self?.updateCapturedLocation(with: placemark)
            }
            .store(in: &cancellables)
            
        // ★追加: 権限ステータスを監視（拒否されたら表示をクリア→画像が広がるように）
        locationManager.$authorizationStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                if status == .denied || status == .restricted {
                    self?.capturedCountry = ""
                    self?.capturedRegion = ""
                    self?.capturedCity = ""
                    self?.capturedSubLocality = ""
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateCapturedLocation(with placemark: CLPlacemark?) {
        guard let p = placemark else { return }
        
        // 許可されていない場合は更新しない（念のため）
        let status = locationManager.authorizationStatus
        if status == .denied || status == .restricted { return }

        let isoCode = p.isoCountryCode ?? ""
        capturedCountry = p.country ?? (isoCode.isEmpty ? "" : isoCode)
        capturedCountryCode = isoCode.isEmpty ? nil : isoCode // ★追加: コード保存
        let adminArea = p.administrativeArea ?? ""
        capturedRegion = adminArea.isEmpty ? "" : adminArea
         
        // City (市) と Ward (区/町) を別々に保存
        capturedCity = p.locality ?? ""
        // if capturedCity.isEmpty { capturedCity = "City" } // Auto-fill 削除
        
        capturedSubLocality = p.subLocality ?? ""
    }
    
    // MARK: - Actions
    
    func onCameraDismissed() {
        if capturedImage != nil {
            capturedDateText = DateFormatter.zioraDisplay.string(from: Date())
            locationManager.requestLocation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                self.previewOffset = 0
                self.isFlyingAway = false
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    self.showPreviewCard = true
                }
            }
        }
    }
    
    func resetPreview() {
        withAnimation {
            showPreviewCard = false
            capturedImage = nil
            previewOffset = 0
            isFlyingAway = false
        }
    }
    
    func startFlyAwayAnimation() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        withAnimation(.easeOut(duration: 0.4)) {
            isFlyingAway = true
        }
        Task {
            await uploadCurrentPhoto()
        }
    }
    
    @Published var showCancelUploadButton = false // ★追加

    func cancelUpload() {
        // アップロード状態を強制リセット
        withAnimation {
            isUploading = false
            isFlyingAway = false
            previewOffset = 0
            showCancelUploadButton = false
            // プレビューを戻す
            showPreviewCard = true
        }
        uploadErrorMessage = "Upload cancelled."
    }

    private func uploadCurrentPhoto() async {
        guard networkMonitor.isConnected else {
            withAnimation {
                isFlyingAway = false
                previewOffset = 0
            }
            uploadErrorMessage = "No internet connection."
            return
        }
        
        guard !isUploading, let image = capturedImage else { return }
        isUploading = true
        showCancelUploadButton = false // リセット
        
        // 15秒後にキャンセルボタンを表示するタイマー
        Task {
            try? await Task.sleep(nanoseconds: 15 * 1_000_000_000)
            if isUploading {
                await MainActor.run {
                    withAnimation { self.showCancelUploadButton = true }
                }
            }
        }
        
        let loc = locationManager.lastLocation
        let placemark = locationManager.lastPlacemark
        
        // ★修正: アップロード時は強制的に日本語ロケールで住所を取得して保存する（検索の一貫性のため）
        // UI表示用(capturedCountry等)はそのまま維持し、DB保存用だけ上書きする
        var dbCountry = capturedCountry
        var dbRegion = capturedRegion
        var dbCity = capturedCity
        var dbSubLocality = capturedSubLocality
        
        if let lat = loc?.coordinate.latitude, let lon = loc?.coordinate.longitude {
            // 日本語ロケールで再取得
            let (stdCountry, stdRegion, stdCity, stdSub) = await localizeLocation(latitude: lat, longitude: lon, locale: Locale(identifier: "ja_JP"))
            if let c = stdCountry { dbCountry = c }
            if let r = stdRegion { dbRegion = r }
            if let city = stdCity { dbCity = city }
            // サブはnilの可能性があるので注意（空文字ならnilにはしないが、ここではnilなら前の値をキープするか空にするか）
            // optimize: stdSubがnilなら空文字扱いにする？ localizeLocationの実装は return (..., sub) で subは nil or string
            if let s = stdSub { dbSubLocality = s } else { dbSubLocality = "" } // nil means no sublocality found in JA
        }

        let meta = PhotoMeta(
            country: dbCountry,
            region: dbRegion,
            city: dbCity,
            subLocality: dbSubLocality.isEmpty ? nil : dbSubLocality,
            countryCode: placemark?.isoCountryCode ?? "",
            latitude: loc?.coordinate.latitude,
            longitude: loc?.coordinate.longitude,
            dateText: capturedDateText
        )
        
        do {
            _ = try await PhotoService.shared.uploadPhoto(image: image, meta: meta)
            
            // キャンセルされていたらここで終了
            if !isUploading { return }
            
            withAnimation { showPreviewCard = false }
            
            try? await Task.sleep(nanoseconds: 200_000_000)
            
            await MainActor.run {
                // キャンセルチェック
                if !isUploading { return }
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
                showCancelUploadButton = false
            }
        } catch {
            await MainActor.run {
                // キャンセルされていたらエラー表示もしない
                if !isUploading { return }
                
                withAnimation(.spring()) {
                    isFlyingAway = false
                    previewOffset = 0
                }
                uploadErrorMessage = error.localizedDescription
                isUploading = false
                showCancelUploadButton = false
            }
        }
    }
    
    // MARK: - Preloading
    private var preloadedGachaData: (doc: PhotoDocument, image: UIImage)? = nil
    private var isPreloading = false
    
    private func preloadNextPhoto() {
        guard !isPreloading, preloadedGachaData == nil else { return }
        isPreloading = true
        
        Task {
            do {
                let currentUserId = Auth.auth().currentUser?.uid
                let excludedIds = self.seenPhotoIds // Current seen list
                
                if let doc = try await PhotoService.shared.fetchRandomPhoto(
                    scope: .global,
                    excludedUserId: currentUserId,
                    excludedPhotoIds: excludedIds
                ) {
                    let image = try await PhotoService.shared.downloadThumbnail(originalPath: doc.imagePath)
                    
                    await MainActor.run {
                        self.preloadedGachaData = (doc, image)
                        self.isPreloading = false
                        print("✨ Gacha Preloaded: \(doc.id)")
                    }
                } else {
                    await MainActor.run { self.isPreloading = false }
                }
            } catch {
                print("⚠️ Preload failed: \(error)")
                await MainActor.run { self.isPreloading = false }
            }
        }
    }

    // MARK: - Synchronization State
    private var cardSignalContinuation: CheckedContinuation<Void, Never>?
    private var isCardSignalReceived = false

    func triggerCardDisplay() {
        if let cont = cardSignalContinuation {
            cont.resume()
            cardSignalContinuation = nil
        } else {
            isCardSignalReceived = true
        }
    }

    private func waitForCardSignal() async {
        if isCardSignalReceived {
            return
        }
        await withCheckedContinuation { cont in
            self.cardSignalContinuation = cont
        }
    }

    func performGacha(expectedSpinDuration: TimeInterval, storeManager: StoreManager) async {
        await performGachaRecursive(expectedSpinDuration: expectedSpinDuration, storeManager: storeManager, retryCount: 0)
    }

    private func performGachaRecursive(expectedSpinDuration: TimeInterval, storeManager: StoreManager, retryCount: Int) async {
        guard networkMonitor.isConnected else {
            print("No internet connection. Showing fallback ad.")
            await displayFallbackAd()
            return
        }
        guard retryCount < 3 else {
            print("Max retries reached. Showing fallback ad.")
            await displayFallbackAd()
            return
        }
        guard !isGachaLoading, !showPreviewCard else { return }
        
        isGachaLoading = true
        if retryCount == 0 {
            gachaCount += 1
            // リセット
            isCardSignalReceived = false
            cardSignalContinuation = nil
        }

        // ★チュートリアルロジック: 初回スピンは必ず東京タワー
        let hasCompletedSpinTutorial = UserDefaults.standard.bool(forKey: "hasCompletedSpinTutorial")
        if !hasCompletedSpinTutorial && retryCount == 0 {
            print("🗼 Tutorial Spin: Force Tokyo Tower")
            
            // チュートリアル用のダミーデータ作成
            let tutorialDoc = PhotoDocument(
                id: "tutorial_tokyo_tower",
                userId: "admin",
                imagePath: "assets/tutorial_tokyo.jpg", // ダミーパス
                country: localized("Tutorial_Country"),
                region: localized("Tutorial_Region"),
                city: localized("Tutorial_City"),
                subLocality: localized("Tutorial_SubLocality"),
                countryCode: "JP",
                latitude: 35.6586,
                longitude: 139.7454,
                createdAt: Timestamp(date: Date()),
                expireAt: Timestamp(date: Date().addingTimeInterval(3600)),
                randomSeed: 0,
                status: "active",
                likeCount: 9999,
                impressionCount: 0, // ★Fix: Missing argument
                dateText: DateFormatter.zioraDisplay.string(from: Date())
            )
            
            guard let tutorialImage = UIImage(named: "tutorial_tokyo") else {
                print("⚠️ Tutorial image not found in assets!")
                // 画像がない場合は通常フローへフォールバック
                await performGachaRecursive(expectedSpinDuration: expectedSpinDuration, storeManager: storeManager, retryCount: retryCount + 1)
                return
            }
            
            await waitForCardSignal()
            
            gachaLatitude = tutorialDoc.latitude
            gachaLongitude = tutorialDoc.longitude
            gachaPhotoId = tutorialDoc.id
            gachaOwnerId = tutorialDoc.userId
            gachaImagePath = tutorialDoc.imagePath
            
            gachaCountry = tutorialDoc.country
            gachaRegion = tutorialDoc.region
            gachaCity = tutorialDoc.city
            gachaSubLocality = tutorialDoc.subLocality ?? ""
            gachaDateText = tutorialDoc.dateText ?? ""
            gachaImage = tutorialImage
            
            // チュートリアル完了フラグは、カードが表示された後（あるいは閉じた後）に立てるのがベストだが、
            // ここで立てておかないとリトライや連打で狂う可能性もあるので、表示確定としてここで保存
            UserDefaults.standard.set(true, forKey: "hasCompletedSpinTutorial")
            
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    self.showGachaCard = true
                }
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }
            isGachaLoading = false
            return
        }
        
        // Ad Logic
        let shouldShowAd: Bool = {
            // リトライ時は広告判定を行わない
            if retryCount > 0 { return false }
            
            if storeManager.hasPurchasedAdFree { return false }
            
            // 前回広告だった場合は今回は出さない
            let lastWasAd = UserDefaults.standard.bool(forKey: "lastSpinWasAd")
            if lastWasAd { return false }
            
            // 以下、通常の確率ロジック
            if gachaCount == 1 { return false }
            // チュートリアル直後は広告を出さない（gachaCount=1は上で弾かれるが念のため）
            
            if gachaCount - lastAdShownAt == 1 { return false } 
            if gachaCount % 5 == 0 { return true }
            return Int.random(in: 1...5) == 1
        }()
        
        // 結果を保存
        if retryCount == 0 {
            UserDefaults.standard.set(shouldShowAd, forKey: "lastSpinWasAd")
            showAdThisTime = shouldShowAd
            if shouldShowAd { lastAdShownAt = gachaCount }
        } else {
             showAdThisTime = false // リトライ中は広告フラグを立てない
        }
        
        if shouldShowAd {
            // Use preloaded ad if available and ready
            if let preloaded = nextAdViewModel, !preloaded.loadFailed, !preloaded.isLoading { // using isReady logic manually or check state
                 print("🚀 Showing Preloaded Ad!")
                 self.adViewModel = preloaded
            } else {
                 print("⚠️ Preload not ready or failed. Loading fresh ad.")
                 self.adViewModel = NativeAdViewModel(adUnitID: AdConfig.nativeAdUnitID)
            }
            
            // Clear used preload and prepare next
            self.nextAdViewModel = nil
            self.preloadAd(storeManager: storeManager)
            
            // シグナル待ち
            await waitForCardSignal()
            
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    self.showGachaCard = true
                }
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }
            isGachaLoading = false
            return
        }
        
        do {
            let doc: PhotoDocument
            let image: UIImage
            
            // ★プリロードデータの確認
            // リトライ時は再取得、かつ既読済み（Collision/Ignore）でないことを確認
            let usablePreload = preloadedGachaData.flatMap { p in
                return (!self.seenPhotoIds.contains(p.doc.id)) ? p : nil
            }
            
            if retryCount == 0, let preloaded = usablePreload {
                print("🚀 Using Preloaded Data!")
                doc = preloaded.doc
                image = preloaded.image
                self.preloadedGachaData = nil // 消費
            } else {
                if preloadedGachaData != nil { print("⚠️ Preload collision or retry. Fetching fresh.") }
                print("🔄 Fetching fresh data...")
                let currentUserId = Auth.auth().currentUser?.uid
                let excludedIds = self.seenPhotoIds
                
                // ★追加: 新着優先ロジック
                var fetchedDoc: PhotoDocument? = nil
                
                // 1. リセット日があれば、それ以降の新着を優先検索
                if let lastResetDate = UserDefaults.standard.object(forKey: "lastResetDate") as? Date {
                    // ここで例えば「50件」取得して、その中からランダム or 新しい順に1つ選ぶ
                    // ランダムに選ばないと、毎回同じ順番で出てきてしまうので、候補を複数とってランダム推奨
                    let candidates = try? await PhotoService.shared.fetchPriorityPhotos(
                        after: lastResetDate,
                        excludedUserId: currentUserId,
                        excludedPhotoIds: excludedIds,
                        limit: 50
                    )
                    
                    if let c = candidates, !c.isEmpty {
                        // 候補の中からランダムに1つ選ぶ（新着の中でもランダム性を出すため）
                        fetchedDoc = c.randomElement()
                        print("🔥 Priority Fetch Hit! (Candidates: \(c.count))")
                    }
                }
                
                // 2. 優先枠で見つからなければ、通常ランダム
                if fetchedDoc == nil {
                    fetchedDoc = try await PhotoService.shared.fetchRandomPhoto(
                        scope: .global,
                        excludedUserId: currentUserId,
                        excludedPhotoIds: excludedIds
                    )
                }
                
                guard let validDoc = fetchedDoc else {
                    // errorではなくコンプリート扱いにする
                    if !excludedIds.isEmpty {
                        await waitForCardSignal()
                        await MainActor.run {
                            self.showCompletionCard = true
                            self.isGachaLoading = false
                        }
                    } else {
                        await MainActor.run {
                            // ERROR SUPPRESSION
                            print("No photos found (Suppressed). Showing fallback ad.")
                        }
                        await displayFallbackAd()
                    }
                    return
                }
                doc = validDoc
                // ★修正: ダウンロード前にIDを確保！これでcatchブロックでもこのIDを参照できる
                gachaPhotoId = doc.id
                image = try await PhotoService.shared.downloadThumbnail(originalPath: doc.imagePath)
            }
            
            // gachaPhotoId = doc.id // ここだと遅いので削除
            
            gachaLatitude = doc.latitude
            gachaLongitude = doc.longitude
            gachaPhotoId = doc.id // 念のため再代入(変ではない)
            gachaOwnerId = doc.userId
            gachaImagePath = doc.imagePath
            
            // 既読に追加
            var currentSeen = self.seenPhotoIds
            currentSeen.insert(doc.id)
            self.seenPhotoIds = currentSeen
            
            // シグナル待ち
            await waitForCardSignal()
            
            let dateString = doc.createdAt.map { DateFormatter.zioraDisplay.string(from: $0.dateValue()) } ?? ""
            
            // リバースジオコーディング
            if let lat = doc.latitude, let lon = doc.longitude {
                let (locCountry, locRegion, locCity, locSub) = await self.localizeLocation(latitude: lat, longitude: lon, locale: nil)
                self.gachaCountry = locCountry ?? doc.country
                self.gachaRegion = locRegion ?? doc.region
                self.gachaCity = locCity ?? doc.city
                self.gachaSubLocality = locSub ?? doc.subLocality ?? ""
            } else {
                self.gachaCountry = doc.country
                self.gachaRegion = doc.region
                self.gachaCity = doc.city
                self.gachaSubLocality = doc.subLocality ?? ""
            }
            
            self.gachaDateText = dateString
            self.gachaImage = image
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                self.showGachaCard = true
            }
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            isGachaLoading = false
            
            // 次の写真をプリロードしておく(バックグラウンド)
            self.preloadNextPhoto()
            
        } catch {
            let nsError = error as NSError
            print("❌ Gacha Error: \(error)")
            print("   Domain: \(nsError.domain), Code: \(nsError.code)")
            print("   Captured ID: \(gachaPhotoId)")

            let isStorageCode = (nsError.code == -13010) // StorageErrorCode.objectNotFound
            let isHttpNotFound = (nsError.code == 404)
            let desc = error.localizedDescription
            let isNotExistMsg = desc.contains("does not exist") || desc.contains("存在しません") || desc.contains("Not Found")
            
            if isStorageCode || isHttpNotFound || isNotExistMsg {
                if !gachaPhotoId.isEmpty {
                    var currentSeen = self.seenPhotoIds
                    currentSeen.insert(gachaPhotoId)
                    self.seenPhotoIds = currentSeen
                    print("🚫 Locally ignoring broken photo: \(gachaPhotoId)")
                    
                    // 即座に保存して同期を確実にする
                    UserDefaults.standard.synchronize()
                } else {
                    print("⚠️ GachaPhotoId was empty, cannot ignore.")
                }
                
                isGachaLoading = false
                // Retry
                await performGachaRecursive(expectedSpinDuration: 0.5, storeManager: storeManager, retryCount: retryCount + 1)
                return
            }
            
            // ERROR SUPPRESSION: Do not show alert, show fallback Ad
            print("Gacha Error (Suppressed): \(error.localizedDescription). Showing fallback ad.")
            await displayFallbackAd()
            isGachaLoading = false
        }
    }
    
    // MARK: - Helper Methods
    
    private func displayFallbackAd() async {
        print("⚠️ Displaying Fallback Ad due to error")
        // Force show ad state
        await MainActor.run {
            self.showAdThisTime = true
            self.adViewModel = NativeAdViewModel(adUnitID: AdConfig.nativeAdUnitID)
        }
        
        await waitForCardSignal()
        
        await MainActor.run {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                self.showGachaCard = true
            }
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            self.isGachaLoading = false
        }
    }

    private func localizeLocation(latitude: Double, longitude: Double, locale: Locale? = nil) async -> (country: String?, region: String?, city: String?, subLocality: String?) {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let geocoder = CLGeocoder()
        
        let targetLocale: Locale
        if let locale = locale {
            targetLocale = locale
        } else {
            let languageCode = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en"
            targetLocale = Locale(identifier: languageCode)
        }
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location, preferredLocale: targetLocale)
            guard let p = placemarks.first else { return (nil, nil, nil, nil) }
            
            let isoCode = p.isoCountryCode ?? ""
            let country = p.country ?? (isoCode.isEmpty ? "Country" : isoCode)
            
            let adminArea = p.administrativeArea ?? ""
            let region = adminArea.isEmpty ? "State" : adminArea
            
            let locality = p.locality ?? ""
            let subLocality = p.subLocality ?? ""
            
            let city = locality.isEmpty ? "City" : locality
            let sub = subLocality.isEmpty ? nil : subLocality
            
            return (country, region, city, sub)
        } catch {
            print("Localization Error: \(error)")
            return (nil, nil, nil, nil)
        }
    }
    
    // MARK: - Auth Actions
    func signOut() {
        try? AuthManager.shared.signOut()
    }
    
    func deleteAccount() {
        Task {
            try? await AuthManager.shared.deleteAccount()
        }
    }
    
    // ★追加: 履歴リセット
    func resetSeenHistory() {
        seenPhotoIds = []
        // ★追加: リセット日時を保存
        UserDefaults.standard.set(Date(), forKey: "lastResetDate")
        withAnimation { showCompletionCard = false }
    }
    

    
    // MARK: - Ad Preloading Logic
    func preloadAd(storeManager: StoreManager) {
        if storeManager.hasPurchasedAdFree {
            nextAdViewModel = nil
            return
        }
        
        // If we already have a valid one, check if it failed
        if let existing = nextAdViewModel {
            if existing.loadFailed {
                print("♻️ Preload failed previously. Retrying...")
            } else {
                // Already loading or ready
                return
            }
        }
        
        print("📥 Preloading next ad...")
        let vm = NativeAdViewModel(adUnitID: AdConfig.nativeAdUnitID)
        self.nextAdViewModel = vm
    }
}
