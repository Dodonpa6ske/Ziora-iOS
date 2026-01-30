import SwiftUI

// MARK: - ③ 利用規約同意画面

struct TermsAgreementView: View {
    let onAgree: () -> Void
    let onDisagree: () -> Void

    // URL for terms and privacy
    private let termsURL = "https://www.notion.so/Ziora-Terms-of-Service-2c0aacfc1c6f801f934cdafe1e0bf063?source=copy_link"
    private let privacyURL = "https://www.notion.so/Ziora-Privacy-Policy-2c0aacfc1c6f805e99a5e847005b669e?source=copy_link"

    // ★追加: 言語設定を取得
    @AppStorage("selectedLanguage") private var language: String = "en"
    
    private func localized(_ key: String) -> String {
        if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(key, tableName: nil, bundle: bundle, value: "", comment: "")
        }
        return key
    }

    var body: some View {
        ZStack {
            Color.zioraLightBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // ヘッダー (SwiftUIのTextはEnvironmentのLocaleを見るのでそのままでOKだが、もしここもダメなら同様の対応が必要)
                OnboardingHeaderView(
                    systemIconName: "doc.text",
                    icon: nil,
                    title: localized("Accept\nTerms")
                )

                Color.clear
                    .frame(height: OnboardingLayout.titleBodySpacing)

                VStack(alignment: .leading, spacing: 8) {
                    // ★修正: Helperを使用して簡潔に
                    let key = "By continuing, you agree to the [Ziora Terms of Service](%@) and [Privacy Policy](%@)"
                    let baseText = localized(key)
                    
                    let formattedText = String(format: baseText, termsURL, privacyURL)
                    
                    if let attributedText = try? AttributedString(markdown: formattedText) {
                        Text(attributedText)
                        .font(ZioraFont.body(16))
                        .foregroundColor(.primary)
                        .tint(.zioraBlue)
                    } else {
                        // Markdownパース失敗時のフォールバック (英語で表示)
                        Text("By continuing, you agree to the [Ziora Terms of Service](\(termsURL)) and [Privacy Policy](\(privacyURL))")
                            .font(ZioraFont.body(16))
                            .foregroundColor(.primary)
                            .tint(.zioraBlue)
                    }
                }
                .lineSpacing(16 * 0.1)

                // 本文とボタンの間 75pt
                Color.clear
                    .frame(height: 75)

                VStack(spacing: OnboardingLayout.buttonSpacing) {
                    Button(action: onAgree) {
                        Text(localized("Agree and Continue"))
                            .font(ZioraFont.buttonSemibold(16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 65)
                    }
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.zioraBlue.opacity(0.85),
                                        Color.zioraBlue
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )

                    Button(action: onDisagree) {
                        Text(localized("Disagree"))
                            .font(ZioraFont.button(16))
                            .foregroundColor(.zioraBlue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 65)
                            .overlay(
                                Capsule()
                                    .stroke(Color.zioraBlue, lineWidth: 1)
                            )
                    }
                }

                Spacer()
            }
            .padding(.horizontal, OnboardingLayout.horizontalPadding)
            .padding(.bottom,
                     OnboardingLayout.progressBottomOffset
                     + OnboardingLayout.contentToDotsSpacing)

            VStack {
                Spacer()
                OnboardingProgressDots(currentIndex: 1, totalCount: 3)
                .padding(.bottom, OnboardingLayout.progressBottomOffset - 15)
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}

// MARK: - ③-1 Agreement Required

struct AgreementRequiredView: View {
    let onBackToAgreement: () -> Void
    let onClose: () -> Void
    
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
            Color.zioraLightBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                OnboardingHeaderView(
                    systemIconName: "exclamationmark.triangle.fill",
                    icon: nil,
                    title: localized("Agreement\nRequired")
                )

                Color.clear
                    .frame(height: OnboardingLayout.titleBodySpacing)

                Text(localized("To use Ziora, you need to agree to the Terms of Service and Privacy Policy.\nThese policies explain how we protect your data and ensure a safe experience for all users."))
                .font(ZioraFont.body(16))
                .foregroundColor(.primary)
                .lineSpacing(16 * 0.1)
                .fixedSize(horizontal: false, vertical: true)

                // 本文とボタンの間 75pt
                Color.clear
                    .frame(height: 75)

                VStack(spacing: OnboardingLayout.buttonSpacing) {
                    Button(action: onBackToAgreement) {
                        Text(localized("Back to Agreement"))
                            .font(ZioraFont.buttonSemibold(16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 65)
                    }
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.zioraBlue.opacity(0.85),
                                        Color.zioraBlue
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )

                    Button(action: onClose) {
                        Text(localized("Close"))
                            .font(ZioraFont.button(16))
                            .foregroundColor(.zioraBlue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 65)
                            .overlay(
                                Capsule()
                                    .stroke(Color.zioraBlue, lineWidth: 1)
                            )
                    }
                }

                Spacer()
            }
            .padding(.horizontal, OnboardingLayout.horizontalPadding)
            // この画面はドット無しなので progressBottomOffset だけ
            .padding(.bottom, OnboardingLayout.progressBottomOffset)
        }
    }
}
