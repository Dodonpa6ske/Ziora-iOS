import SwiftUI

// MARK: - オンボーディングのステップ管理

enum OnboardingStep {
    case splash          // ①起動画面
    case language        // ②言語選択
    case terms           // ③利用規約同意
    case agreementNeeded // ③-1 同意要求画面（不同意したとき）
    case signIn          // ④ログイン
    case home            // ⑤ホーム（仮）
}

// MARK: - アプリ全体の入口

struct ContentView: View {

    @EnvironmentObject var authManager: AuthManager

    @State private var step: OnboardingStep = .splash

    // 👇 これを追加（UserDefaultsに保存される）
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    @State private var selectedLanguageCode: String? = nil
    @State private var hasAgreedToTerms: Bool = false

    var body: some View {
        ZStack {
            switch step {
            case .splash:
                SplashView {
                    // 👇 オンボーディング済みかどうかでまず分岐
                    if hasCompletedOnboarding {
                        // すでにオンボーディングを終えている
                        if authManager.isSignedIn {
                            // ログイン済み → そのままホーム
                            step = .home
                        } else {
                            // オンボ済みだけどログインはまだ → サインイン画面へ
                            step = .signIn
                        }
                    } else {
                        // まだ一度もオンボを完了していない → 言語選択から
                        step = .language
                    }
                }

            case .language:
                LanguageSelectionView(
                    selectedLanguageCode: $selectedLanguageCode,
                    onNext: {
                        step = .terms
                    }
                )

            case .terms:
                TermsAgreementView(
                    onAgree: {
                        hasAgreedToTerms = true
                        step = .signIn
                    },
                    onDisagree: {
                        hasAgreedToTerms = false
                        step = .agreementNeeded
                    }
                )

            case .agreementNeeded:
                AgreementRequiredView(
                    onBackToAgreement: {
                        step = .terms
                    },
                    onClose: {
                        selectedLanguageCode = nil
                        hasAgreedToTerms = false
                        step = .splash
                    }
                )

            case .signIn:
                SignInView(
                    onSignedIn: {
                        // 👇 初めてサインインまで完走したらフラグを立てる
                        hasCompletedOnboarding = true
                        step = .home
                    }
                )

            case .home:
                HomeView()
            }
        }
        .preferredColorScheme(.light)
    }
}

// MARK: - プレビュー

#Preview {
    ContentView()
        // ✅ プレビュー用にも EnvironmentObject を渡しておく
        .environmentObject(AuthManager.shared)
}
