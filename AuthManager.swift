import Foundation
import Combine
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit

@MainActor
final class AuthManager: ObservableObject {

    static let shared = AuthManager()

    @Published var isSignedIn: Bool = (Auth.auth().currentUser != nil)

    private init() {}

    // MARK: - Google Sign In（ゲストからのアップグレード対応）

    func signInWithGoogle(presenting viewController: UIViewController) async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.misconfigured("Firebase clientID が取得できませんでした")
        }

        // Google Sign-In の設定
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        // Google のサインイン画面を表示
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)

        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.google("idToken が取得できませんでした")
        }

        let accessToken = result.user.accessToken.tokenString

        // Firebase Auth 用の Credential に変換
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: accessToken
        )

        // 👇 ここがポイント：
        // すでに「匿名ユーザー」としてログイン中なら link() でアップグレード
        if let current = Auth.auth().currentUser, current.isAnonymous {
            let linkResult = try await current.link(with: credential)
            print("✅ Anonymous user upgraded to Google user. uid = \(linkResult.user.uid)")
        } else {
            // それ以外は通常の Google サインイン
            let authResult = try await Auth.auth().signIn(with: credential)
            print("✅ Signed in with Google. uid = \(authResult.user.uid)")
        }

        self.isSignedIn = true
    }

    // MARK: - Guest Sign In (匿名ログイン)

    func signInAsGuest() async throws {
        // すでにログインしている場合は、そのまま使い回す
        if let current = Auth.auth().currentUser {
            print("ℹ️ Already signed in as \(current.isAnonymous ? "anonymous" : "normal") user. uid = \(current.uid)")
            self.isSignedIn = true
            return
        }

        // 初めてのゲストログイン
        let result = try await Auth.auth().signInAnonymously()
        print("✅ Anonymous user signed in. uid = \(result.user.uid)")
        self.isSignedIn = true
    }

    // MARK: - Sign Out

    func signOut() throws {
        try Auth.auth().signOut()
        self.isSignedIn = false
    }

    // MARK: - Error

    enum AuthError: LocalizedError {
        case misconfigured(String)
        case google(String)
        case unknown

        var errorDescription: String? {
            switch self {
            case .misconfigured(let message):
                return message
            case .google(let message):
                return "Google サインインに失敗しました: \(message)"
            case .unknown:
                return "サインインに失敗しました"
            }
        }
    }
}
