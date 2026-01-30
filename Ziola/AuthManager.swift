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

    @Published var isSignedIn: Bool = false
    @Published var currentUser: User? // ★追加: UIの更新検知用

    // Apple Sign In用の一時データ（Nonce）
    fileprivate var currentNonce: String?
    
    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?

    private override init() {
        super.init()
        // Auth状態の監視を開始
        // listenerは直ちに現在の状態とともに呼ばれるため、明示的な初期値セットは不要
        self.authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            self.currentUser = user
            self.isSignedIn = (user != nil)
        }
    }

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
            do {
                let linkResult = try await current.link(with: credential)
                print("✅ Anonymous user upgraded. uid = \(linkResult.user.uid)")
            } catch {
                let nsError = error as NSError
                let errorString = "\(nsError.code) \(nsError.domain) \(nsError.localizedDescription)".lowercased()
                print("⚠️ Link failed: \(errorString)")

                // Case 1: "Duplicate credential" (17026) = Already linked to THIS user
                // Google: 17026, Apple: "duplicate credential received"
                let isDuplicate = nsError.code == 17026 || errorString.contains("duplicate") || errorString.contains("credential received")
                
                if isDuplicate {
                    print("✅ Credential already linked (Duplicate). Treating as success.")
                    self.isSignedIn = true
                    return
                }
                
                // Case 2: "Credential Already In Use" (17025) = Linked to ANOTHER user
                // Stop here. Do not try fallback sign-in because token is already consumed/invalid for retry.
                if nsError.code == 17025 || nsError.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                    print("⛔️ Credential already in use by another account.")
                    throw NSError(
                        domain: "AuthManager",
                        code: 17025,
                        userInfo: [NSLocalizedDescriptionKey: "This account is already linked to another user.\nPlease sign out and sign in with that account to switch."]
                    )
                }

                print("🔥🔥🔥 FALLBACK LOGIC TRIGGERED - Trying to SignIn instead 🔥🔥🔥")
                
                // Case 3: Other errors? Try fallback just in case, but usually dangerous for Apple Sign In.
                // Keeping original fallback logic for non-critical errors if any.
                do {
                    let authResult = try await Auth.auth().signIn(with: credential)
                    print("✅ Fallback SignIn successful. uid = \(authResult.user.uid)")
                    
                    if authResult.user.uid == current.uid {
                        print("   -> (Re-logged in to same account)")
                    } else {
                        print("   -> (Switched to existing account)")
                    }
                } catch {
                    print("💀 FATAL: SignIn fallback also failed: \(error)")
                    throw NSError(
                        domain: "AuthManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Fallback SignIn Failed: \(error.localizedDescription)"]
                    )
                }
            }
        } else {
            // 新規または既存ユーザーとしてサインイン
            let authResult = try await Auth.auth().signIn(with: credential)
            print("✅ Signed in. uid = \(authResult.user.uid)")
        }
        self.isSignedIn = true
    }

    // MARK: - Guest Sign In
    func signInAsGuest() async throws {
        if let user = Auth.auth().currentUser {
            if user.isAnonymous {
                // すでに匿名ユーザーならそのまま利用
                print("✅ Using existing anonymous user. uid = \(user.uid)")
                self.isSignedIn = true
                return
            } else {
                // もし通常アカウント(Apple/Google)でログイン中なら、
                // ゲストボタンが押されたということは「ゲストとしてやり直したい」意図なので、
                // 一旦ログアウトして匿名ユーザーを作り直す
                print("⚠️ Signed in as verified user, but Guest requested. Signing out first.")
                try Auth.auth().signOut()
            }
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
