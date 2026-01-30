import Foundation
import FirebaseRemoteConfig

// ★修正: ObservableObject への準拠を削除しました
final class RemoteConfigManager {
    static let shared = RemoteConfigManager()
    
    private let remoteConfig = RemoteConfig.remoteConfig()
    
    // デフォルトのブロックリスト (万が一フェッチに失敗した時のため)
    private let defaultBlockedCodes = ["CN", "KP", "RU", "SY", "IR", "CU"]
    
    private init() {
        let settings = RemoteConfigSettings()
        // 開発中はフェッチ間隔を短く（0秒）、本番は推奨値（12時間など）にする
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 43200 // 12時間
        #endif
        remoteConfig.configSettings = settings
        
        // デフォルト値をセット
        let defaults: [String: NSObject] = [
            "blocked_country_codes": try! JSONEncoder().encode(defaultBlockedCodes) as NSObject
        ]
        remoteConfig.setDefaults(defaults)
    }
    
    /// アプリ起動時にクラウドから最新設定を取得
    func fetchRemoteConfig() {
        remoteConfig.fetchAndActivate { status, error in
            if let error = error {
                print("⚠️ Remote Config fetch error: \(error.localizedDescription)")
            } else {
                print("✅ Remote Config fetched successfully. Status: \(status)")
            }
        }
    }
    
    /// ブロック対象の国コードリストを取得
    var blockedCountryCodes: [String] {
        // JSON形式で保存されていることを想定
        let jsonString = remoteConfig.configValue(forKey: "blocked_country_codes").stringValue
        guard let data = jsonString.data(using: .utf8) else {
            return defaultBlockedCodes
        }
        
        do {
            let codes = try JSONDecoder().decode([String].self, from: data)
            // 大文字に統一して返す
            return codes.map { $0.uppercased() }
        } catch {
            print("⚠️ Failed to parse blocked_country_codes: \(error)")
            return defaultBlockedCodes
        }
    }
}
