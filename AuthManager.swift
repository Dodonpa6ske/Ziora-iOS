import Foundation
import Combine
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import AuthenticationServices // ★追加
import CryptoKit // ★追加
import UIKit

@MainActor
final class AuthManager: NSObject, ObservableObject { // ★NSObjectを継承しておくと便利

    static let shared = AuthManager()

    @Published var isSignedIn: Bool = (Auth.auth().currentUser != nil)
    
    // Apple Sign In用の一時データ（Nonce）
    fileprivate var currentNonce: String?

    private override init() {}

    // MARK: - Google Sign In
    func signInWithGoogle(presenting viewController: UIViewController) async throws {
        // (省略: 元のコードと同じ内容でOKです)
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.misconfigured("Firebase clientID が取得できませんでした")
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.google("idToken が取得できませんでした")
        }
        let accessToken = result.user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        try await linkOrSignIn(credential: credential)
    }

    // MARK: - Apple Sign In (★ここを追加)
    
    // 1. サインインリクエストの準備（ボタンタップ時に呼ぶ）
    func startAppleSignIn(request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }
    
    // 2. 完了時の処理（Appleから結果が返ってきたら呼ぶ）
    func handleAppleSignInCompletion(result: Result<ASAuthorization, Error>) async throws {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                guard let nonce = currentNonce else {
                    throw AuthError.unknown
                }
                guard let appleIDToken = appleIDCredential.identityToken else {
                    throw AuthError.unknown
                }
                guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                    throw AuthError.unknown
                }
                
                // Firebaseの認証情報を作成
                let credential = OAuthProvider.appleCredential(
                    withIDToken: idTokenString,
                    rawNonce: nonce,
                    fullName: appleIDCredential.fullName
                )
                try await linkOrSignIn(credential: credential)
            }
        case .failure(let error):
            throw error
        }
    }

    // MARK: - 共通処理 (ログインまたはリンク)
    private func linkOrSignIn(credential: AuthCredential) async throws {
        if let current = Auth.auth().currentUser, current.isAnonymous {
            // 匿名ユーザーからの引き継ぎ
            let linkResult = try await current.link(with: credential)
            print("✅ Anonymous user upgraded. uid = \(linkResult.user.uid)")
        } else {
            // 新規または既存ユーザーとしてサインイン
            let authResult = try await Auth.auth().signIn(with: credential)
            print("✅ Signed in. uid = \(authResult.user.uid)")
        }
        self.isSignedIn = true
    }

    // MARK: - Guest Sign In
    func signInAsGuest() async throws {
        if let current = Auth.auth().currentUser {
            self.isSignedIn = true
            return
        }
        let result = try await Auth.auth().signInAnonymously()
        print("✅ Anonymous user signed in. uid = \(result.user.uid)")
        self.isSignedIn = true
    }

    // MARK: - Sign Out & Delete
    func signOut() throws {
        try Auth.auth().signOut()
        self.isSignedIn = false
    }
    
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await user.delete()
        self.isSignedIn = false
    }

    // MARK: - 暗号化ヘルパー (Apple Sign In用) ★必須
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess { fatalError("Unable to generate nonce") }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { charset[Int($0) % charset.count] }
        return String(nonce)
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Error
    enum AuthError: LocalizedError {
        case misconfigured(String)
        case google(String)
        case unknown
        var errorDescription: String? {
            switch self {
            case .misconfigured(let m): return m
            case .google(let m): return "Google Sign In Failed: \(m)"
            case .unknown: return "Authentication Failed"
            }
        }
    }
}
