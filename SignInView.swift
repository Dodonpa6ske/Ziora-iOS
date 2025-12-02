import SwiftUI

struct SignInView: View {
    let onSignedIn: () -> Void

    private let termsURL = URL(string: "https://example.com/terms")!
    private let privacyURL = URL(string: "https://example.com/privacy")!

    @State private var isLoading = false
    @State private var errorMessage: String?

    // 👇 Guest モードの確認ダイアログ表示フラグ
    @State private var showGuestWarning = false

    var body: some View {
        ZStack {
            Color.zioraLightBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                OnboardingHeaderView(
                    systemIconName: "arrow.right.to.line",
                    icon: nil,
                    title: "Sign\nIn"
                )

                Color.clear
                    .frame(height: OnboardingLayout.titleBodySpacing)

                Spacer(minLength: 0)

                VStack(spacing: OnboardingLayout.buttonSpacing) {
                    // Google button
                    Button {
                        Task { await handleGoogleSignIn() }
                    } label: {
                        HStack(spacing: 8) {
                            Image("google_logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)

                            Text("Sign in with Google")
                                .font(ZioraFont.buttonSemibold(16))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 65)
                        .foregroundColor(.primary)
                    }
                    .disabled(isLoading)
                    .background(
                        Capsule()
                            .fill(Color.white)
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.primary.opacity(0.25), lineWidth: 1.5)
                    )

                    // Apple button (placeholder implementation)
                    Button {
                        Task { await handleAppleSignInPlaceholder() }
                    } label: {
                        HStack(spacing: 8) {
                            Image("apple_logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)

                            Text("Sign in with Apple")
                                .font(ZioraFont.buttonSemibold(16))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 65)
                        .foregroundColor(.white)
                    }
                    .disabled(isLoading)
                    .background(
                        Capsule()
                            .fill(Color.black)
                    )

                    // Continue as Guest  →  まずは確認ダイアログを出す
                    Button {
                        showGuestWarning = true
                    } label: {
                        Text("Continue as Guest")
                            .font(ZioraFont.button(14))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 8)
                    }
                    .disabled(isLoading)
                }

                // space between "Continue as Guest" and terms
                Color.clear
                    .frame(height: 30)

                // Terms / Privacy
                VStack(spacing: 4) {
                    Text("By signing in, you agree to our")
                        .font(ZioraFont.body(12))
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        Link("Terms of Service", destination: termsURL)
                            .font(ZioraFont.body(12))

                        Text("and")
                            .font(ZioraFont.body(12))
                            .foregroundColor(.secondary)

                        Link("Privacy Policy", destination: privacyURL)
                            .font(ZioraFont.body(12))

                        Text(".")
                            .font(ZioraFont.body(12))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, OnboardingLayout.horizontalPadding)
            .padding(.bottom,
                     OnboardingLayout.progressBottomOffset
                     + OnboardingLayout.contentToDotsSpacing)

            // ローディング
            if isLoading {
                Color.black.opacity(0.1).ignoresSafeArea()
                ProgressView()
            }

            // SignInView 内の ZStack の中、showGuestWarning == true のところだけ差し替え

            if showGuestWarning {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showGuestWarning = false
                    }

                GuestModeWarningDialog(
                    onContinue: {
                        // ゲストモードで続行
                        showGuestWarning = false
                        Task { await handleGuestSignIn() }
                    },
                    onBack: {
                        // 何もせずダイアログを閉じてサインイン画面に戻る
                        showGuestWarning = false
                    }
                )
                .padding(.horizontal, 24)
            }
        }
        .overlay(
            VStack {
                Spacer()
                OnboardingProgressDots(currentIndex: 2, totalCount: 3)
                    .padding(.bottom, OnboardingLayout.progressBottomOffset)
            }
        )
        .alert("Sign in error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Actions

    private func handleGoogleSignIn() async {
        guard let presentingVC = UIApplication.topViewController() else {
            errorMessage = "Failed to get presenting view controller."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await AuthManager.shared.signInWithGoogle(presenting: presentingVC)
            onSignedIn()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleGuestSignIn() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AuthManager.shared.signInAsGuest()
            onSignedIn()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// For now this just behaves like guest sign-in.
    private func handleAppleSignInPlaceholder() async {
        await handleGuestSignIn()
    }
}

// MARK: - Guest mode warning dialog

struct GuestModeWarningDialog: View {
    let onContinue: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Title
            Text("Start in Guest Mode")
                .font(ZioraFont.buttonSemibold(20))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            // Body
            Text("""
If you delete the app, your data will be erased, but you can later link an account to carry your data over.
""")
                .font(ZioraFont.body(14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 16) {
                // ✅ Continue ボタンを少し小さめに（幅 240pt）
                Button {
                    onContinue()
                } label: {
                    Text("Continue")
                        .font(ZioraFont.buttonSemibold(16))
                        .foregroundColor(.white)
                        .frame(width: 240, height: 65)   // ← 横幅を絞る
                }
                .background(
                    Capsule()
                        .fill(Color.zioraBlue)
                )

                // Back（テキストだけでOK）
                Button {
                    onBack()
                } label: {
                    Text("Back")
                        .font(ZioraFont.button(14))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: 320)        // ← ダイアログ自体の最大幅も少し絞る
        .background(Color.white)
        .cornerRadius(32)
    }
}
