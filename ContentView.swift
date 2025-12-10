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

    // 👇 オンボーディング完了フラグ（UserDefaultsに保存）
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    // 👇 ★修正: 言語設定をUserDefaultsに保存するように変更 (初期値 "en")
    // これにより LocationManager など他の場所からも "selectedLanguage" キーで参照可能になります
    @AppStorage("selectedLanguage") private var selectedLanguageCode: String = "en"

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
                    // ★修正: AppStorage(String) と View(String?) の型の不一致を解消するための変換
                    selectedLanguageCode: Binding(
                        get: { selectedLanguageCode },
                        set: { newValue in
                            // nilが来たらデフォルトの "en" を入れる
                            selectedLanguageCode = newValue ?? "en"
                        }
                    ),
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
                        // ★修正: nilではなく初期値に戻す
                        selectedLanguageCode = "en"
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
