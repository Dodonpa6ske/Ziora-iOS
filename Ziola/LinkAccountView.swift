import SwiftUI
import AuthenticationServices

struct LinkAccountView: View {
    @Binding var isPresented: Bool
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Apple Sign In 用ヘルパー
    @StateObject private var appleSignInHelper = AppleSignInHelper()

    // カードの表示アニメーション用
    @State private var showCard = false

    // ★追加: ローカライズヘルパー
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
            // 1. 背景（フェードイン・タップで閉じる）
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    close()
                }
                .transition(.opacity)
            
            // 2. カード本体（下からスライドイン）
            if showCard {
                VStack(spacing: 0) {
                    
                    // --- ヘッダーアイコン ---
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 72, height: 72)
                        
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 32))
                            .foregroundColor(Color(hex: "6C6BFF"))
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 16)
                    
                    // --- タイトル & 説明 ---
                    Text(localized("Link Account"))
                        .font(.system(size: 22, weight: .bold)) // 24 -> 22 に微調整
                        .foregroundColor(.black)
                        .padding(.bottom, 8)
                    
                    Text(localized("Link your account to save your\ndata permanently."))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 20) // 24 -> 20 に短縮
                    
                    // --- サインインボタン群 ---
                    VStack(spacing: 12) {
                        // Google
                        Button {
                            Task { await handleGoogleSignIn() }
                        } label: {
                            HStack(spacing: 12) {
                                Image("google_logo") // Assetsにある前提
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                                
                                Text(localized("Link with Google"))
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundColor(.black)
                            .background(Color.white)
                            .cornerRadius(25)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                            )
                        }
                        
                        // Apple
                        Button {
                            appleSignInHelper.startSignIn { result in
                                handleAppleSignInResult(result)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image("apple_logo") // Assetsにある前提
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18) // ロゴサイズ調整
                                
                                Text(localized("Link with Apple"))
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundColor(.white)
                            .background(Color.black)
                            .cornerRadius(25)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16) // ボタン下の余白を短縮
                    
                    // 閉じるボタン
                    Button(localized("Cancel")) {
                        close()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 24)
                }
                // カードスタイル
                .background(Color.white)
                .cornerRadius(32)
                .padding(.horizontal, 24)
                .shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: 12)
                
                // ローディングオーバーレイ
                .overlay {
                    if isLoading {
                        ZStack {
                            Color.white.opacity(0.8)
                            .cornerRadius(32)
                            ProgressView()
                        }
                    }
                }
                // 描画設定
                .compositingGroup()
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                showCard = true
            }
        }
        .alert(localized("Error"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private func close() {
        withAnimation(.easeIn(duration: 0.2)) {
            showCard = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation {
                isPresented = false
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleGoogleSignIn() async {
        guard let presentingVC = UIApplication.topViewController() else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await AuthManager.shared.signInWithGoogle(presenting: presentingVC)
            close()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await AuthManager.shared.handleAppleSignInCompletion(result: result)
                close()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
