import SwiftUI
import FirebaseCore
import FirebaseMessaging
import GoogleMobileAds
import UserNotifications
import FirebaseAppCheck
import BackgroundTasks

// RemoteConfigManagerを使うため、ここでFirebaseRemoteConfigのインポートは必須ではありませんが、
// 明示的に依存関係を示すために記述しても問題ありません。今回はRemoteConfigManager内に隠蔽しています。

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // App Check のプロバイダーを設定
        let providerFactory = ZioraAppCheckProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        
        FirebaseApp.configure()
        
        // ★追加: Remote Config の初期フェッチを開始 (メインスレッドのI/O警告回避のため非同期で実行)
        DispatchQueue.global(qos: .userInitiated).async {
            RemoteConfigManager.shared.fetchRemoteConfig()
        }
        
        // MobileAds initialization - main thread async to reduce launch blocking
        // ★修正: 1秒遅延させてScreenTime関連のクラッシュ(STScreenTimeConfigurationObserver)を回避
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            MobileAds.shared.start(completionHandler: nil)

            #if DEBUG
            // テストデバイスIDは広告リクエスト時にコンソールに自動表示されます
            print("🔵 ============================================")
            print("🔵 [AdMob] Load an ad to see your Device ID")
            print("🔵 [AdMob] It will appear in the console log")
            print("🔵 ============================================")
            #endif
        }
        
        // --- 通知設定 ---
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { _, _ in }
        
        application.registerForRemoteNotifications()
        // ---------------
        
        return true
    }


    
    // MARK: - APNs & FCM
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    // FCMトークンが更新されたら Firestore に保存する
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔥 FCM Token: \(String(describing: fcmToken))")
        if let token = fcmToken {
            PhotoService.shared.saveFCMToken(token)
        }
    }
    
    // MARK: - Local Notification Handler
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([[.banner, .sound]])
    }
    
    // ★追加: 通知タップ時の処理
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // "photoId" が含まれていれば、送信済みリストへ飛ぶ通知
        if let photoId = userInfo["photoId"] as? String {
            // SwiftUI側へ通知を送る
            NotificationCenter.default.post(name: Notification.Name("OpenSentList"), object: nil, userInfo: ["photoId": photoId])
        }
        
        completionHandler()
    }
}

// App Check のプロバイダーファクトリークラス
class ZioraAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if DEBUG
            return AppCheckDebugProvider(app: app)
        #else
            return AppAttestProvider(app: app)
        #endif
    }
}

@main
struct ZioraApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var storeManager = StoreManager.shared
    
    // アプリの状態監視用
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(storeManager)
        }
        // アプリの状態が変化した時の処理（24時間通知用）
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyReminder"])
                UIApplication.shared.applicationIconBadgeNumber = 0
                
            } else if newPhase == .background {
                scheduleDailyNotification()
                scheduleReliableRetentionNotification()
            }
        }
    }
    
    // 24時間後の通知を予約するメソッド
    private func scheduleDailyNotification() {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("NotificationTitle", comment: "Ziora")
        content.body = NSLocalizedString("NotificationBody", comment: "Let's spin...")
        content.sound = .default

        // 24時間後
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 24 * 60 * 60, repeats: false)

        let request = UNNotificationRequest(identifier: "dailyReminder", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    // ★修正: 4時間後の通知を「今」予約する（確実に届くように）
    // アプリを閉じた瞬間に少しだけ時間を貰って(BackgroundTask)、最新情報を取得→予約を行う
    private func scheduleReliableRetentionNotification() {
        // IDは固定して上書き（重複防止）
        let identifier = "retentionReminder"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        
        // バックグラウンドタスク開始
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskID = UIApplication.shared.beginBackgroundTask {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
        
        Task {
            // タイムアウト対策のdefer
            defer {
                if backgroundTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                    backgroundTaskID = .invalid
                }
            }
            
            do {
                if let photo = try await PhotoService.shared.fetchLatestPhoto() {
                    // 通知作成
                    let content = UNMutableNotificationContent()
                    
                    // 位置情報ローカライズ
                    // 1. デフォルトは生のCity情報（アップロード者の言語の可能性が高い）
                    var placeName = photo.city.isEmpty ? "somewhere" : photo.city

                    // 2. ユーザー設定言語のLocaleを作成
                    let langCode = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en"

                    // 3. 国コードから「ユーザーの言語での国名」を取得して、まずはこれを採用する (Japan, Tokyo ではなく Japan を確実に出す)
                    if let countryCode = photo.countryCode {
                        let tempIdentifier: String
                        switch langCode {
                        case "ja": tempIdentifier = "ja_JP"
                        case "ko": tempIdentifier = "ko_KR"
                        case "zh": tempIdentifier = "zh_CN"
                        case "fr": tempIdentifier = "fr_FR"
                        case "es": tempIdentifier = "es_ES"
                        default: tempIdentifier = langCode
                        }
                        let tempLocale = Locale(identifier: tempIdentifier)
                        if let localizedCountry = tempLocale.localizedString(forRegionCode: countryCode) {
                            placeName = localizedCountry
                        }
                    }

                    // 4. 可能であれば、座標から詳細な都市名を取得して上書き（localizeLocation内で言語設定を使用）
                    if let lat = photo.latitude, let lon = photo.longitude {
                        // localizeLocationは内部でUserDefaultsを参照してLocaleを作る
                        let (_, _, city, _) = await PhotoService.shared.localizeLocation(latitude: lat, longitude: lon)
                        if let c = city, !c.isEmpty, c != "City" { 
                            placeName = c 
                        }
                    }
                    
                    // 言語設定反映 (Bundle取得)
                    let path = Bundle.main.path(forResource: langCode, ofType: "lproj")
                    let bundle = (path != nil) ? Bundle(path: path!) : Bundle.main

                    
                    let title = bundle?.localizedString(forKey: "RetentionTitle", value: nil, table: nil) ?? "New Photo Posted"
                    let bodyFormat = bundle?.localizedString(forKey: "RetentionBody", value: nil, table: nil) ?? "A new photo has been posted in %@!"
                    
                    content.title = title
                    content.body = String(format: bodyFormat, placeName)
                    content.sound = .default
                    content.userInfo = ["photoId": photo.id]
                    
                    // 4時間後にセット (4 * 60 * 60)
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 4 * 60 * 60, repeats: false)
                    // let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false) // DEBUG: 10秒後
                    
                    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                    try await UNUserNotificationCenter.current().add(request)
                    
                    print("✅ Reliable Retention Notification Scheduled for 4 hours later (City: \(placeName))")
                }
            } catch {
                print("❌ Failed to fetch latest photo for notification: \(error)")
            }
        }
    }
}
