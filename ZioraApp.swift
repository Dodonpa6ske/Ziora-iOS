import SwiftUI
import FirebaseCore
import GoogleMobileAds   // ★ 追加

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        // AdMob SDK を初期化
        MobileAds.shared.start(completionHandler: nil)

        return true
    }
}

@main
struct ZioraApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authManager = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
        }
    }
}
