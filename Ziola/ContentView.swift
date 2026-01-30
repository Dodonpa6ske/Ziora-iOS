import SwiftUI
import FirebaseMessaging

// MARK: - オンボーディングのステップ管理

enum OnboardingStep {
    case splash          // ①起動画面
    case language        // ②言語選択
    case intro           // ②-2 イントロダクション（5画面）
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
    @State private var isFromOnboarding: Bool = false

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
                            withAnimation(.easeInOut(duration: 0.2)) { step = .home }
                        } else {
                            // オンボ済みだけどログインはまだ → サインイン画面へ
                            withAnimation(.easeInOut(duration: 0.2)) { step = .signIn }
                        }
                    } else {
                        // まだ一度もオンボを完了していない → 言語選択から
                        withAnimation(.easeInOut(duration: 0.2)) { step = .language }
                    }
                }

            case .language:
                LanguageSelectionView(
                    // ★修正: AppStorage(String) と View(String?) の型の不一致を解消するための変換
                    selectedLanguageCode: Binding(
                        get: { selectedLanguageCode },
                        set: { newValue in
                            // nilが来たらデフォルトの "en" を入れる
                            let lang = newValue ?? "en"
                            selectedLanguageCode = lang
                            // ★追加: 通知用言語設定を保存
                            PhotoService.shared.saveUserLanguage(lang)
                        }
                    ),
                    onNext: {
                        withAnimation(.easeInOut(duration: 0.2)) { step = .terms }
                    }
                )

            case .intro:
                OnboardingView {
                    // 👇 オンボーディング完了フラグ設定
                    hasCompletedOnboarding = true
                    isFromOnboarding = true // アニメーション用フラグ
                    withAnimation(.easeInOut(duration: 0.2)) { step = .home }
                }

            case .terms:
                TermsAgreementView(
                    onAgree: {
                        hasAgreedToTerms = true
                        withAnimation(.easeInOut(duration: 0.2)) { step = .signIn }
                    },
                    onDisagree: {
                        hasAgreedToTerms = false
                        withAnimation(.easeInOut(duration: 0.2)) { step = .agreementNeeded }
                    }
                )

            case .agreementNeeded:
                AgreementRequiredView(
                    onBackToAgreement: {
                        withAnimation(.easeInOut(duration: 0.2)) { step = .terms }
                    },
                    onClose: {
                        // ★修正: nilではなく初期値に戻す
                        selectedLanguageCode = "en"
                        hasAgreedToTerms = false
                        withAnimation(.easeInOut(duration: 0.2)) { step = .splash }
                    }
                )

            case .signIn:
                SignInView(
                    onSignedIn: {
                        // 👇 サインイン後にイントロダクション（オンボーディング）へ
                        withAnimation(.easeInOut(duration: 0.2)) { step = .intro }
                    }
                )

            case .home:
                HomeView(animateEntry: isFromOnboarding)
            }
        }
        .preferredColorScheme(.light)
        .environment(\.locale, Locale(identifier: selectedLanguageCode))
        // ★修正: サインアウト時に自動的にログイン画面へ戻る
        .onChange(of: authManager.isSignedIn) { isSignedIn in
            if isSignedIn {
                // ★追加: ログイン時にFCMトークンを再同期する（重要！）
                // アプリ起動時に取得したトークンは、その時点で未ログインだと保存されないため、
                // ログイン完了のタイミングで再度保存を試みる必要がある。
                Messaging.messaging().token { token, error in
                    if let token = token {
                        print("🔥 FCM Token Resync on Login: \(token)")
                        PhotoService.shared.saveFCMToken(token)
                    }
                }
            } else if hasCompletedOnboarding {
                withAnimation(.easeInOut(duration: 0.2)) {
                    step = .signIn
                }
            }
        }
    }
}

// MARK: - プレビュー

#Preview {
    ContentView()
        // ✅ プレビュー用にも EnvironmentObject を渡しておく
        .environmentObject(AuthManager.shared)
}
