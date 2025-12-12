import SwiftUI
import FirebaseCore
import FirebaseMessaging
import GoogleMobileAds
import UserNotifications
// ★追加: App Checkをインポート
import FirebaseAppCheck

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // ★追加: App Check のプロバイダーを設定 (FirebaseApp.configure() の直前)
        let providerFactory = ZioraAppCheckProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        
        FirebaseApp.configure()
        MobileAds.shared.start(completionHandler: nil)
        
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
    
    // ★ FCMトークンが更新されたら Firestore に保存する
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔥 FCM Token: \(String(describing: fcmToken))")
        if let token = fcmToken {
            PhotoService.shared.saveFCMToken(token)
        }
    }
    
    // MARK: - Local Notification Handler
    // アプリ起動中に通知が来た場合
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([[.banner, .sound]])
    }
}

// ★追加: App Check のプロバイダーファクトリークラス
class ZioraAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if targetEnvironment(simulator)
            // シミュレーターの場合はデバッグプロバイダーを使用
            return AppCheckDebugProvider(app: app)
        #else
            // 実機の場合は本番用の App Attest を使用
            return AppAttestProvider(app: app)
        #endif
    }
}

@main
struct ZioraApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var storeManager = StoreManager.shared
    
    // ★ アプリの状態監視用
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(storeManager)
        }
        // ★ アプリの状態が変化した時の処理（24時間通知用）
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // アプリを開いたら、古い「24時間通知」の予約をキャンセル
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyReminder"])
                // バッジを消す
                UIApplication.shared.applicationIconBadgeNumber = 0
                
            } else if newPhase == .background {
                // アプリを閉じたら、24時間後の通知を予約
                scheduleDailyNotification()
            }
        }
    }
    
    // ★ 24時間後の通知を予約するメソッド
    private func scheduleDailyNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Ziora"
        content.body = "It's been 24 hours! Time to travel the world again. 🌍"
        content.sound = .default

        // 24時間後 (86400秒)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 24 * 60 * 60, repeats: false)
        // テスト用: 10秒後 (本番では上の行を使ってください)
        // let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)

        let request = UNNotificationRequest(identifier: "dailyReminder", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
}
