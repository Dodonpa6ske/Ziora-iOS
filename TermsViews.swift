import SwiftUI

// MARK: - ③ 利用規約同意画面

import SwiftUI

struct TermsAgreementView: View {
    let onAgree: () -> Void
    let onDisagree: () -> Void

    private let termsURL = URL(string: "https://example.com/terms")!
    private let privacyURL = URL(string: "https://example.com/privacy")!

    var body: some View {
        ZStack {
            Color.zioraLightBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                OnboardingHeaderView(
                    systemIconName: "doc.text",
                    icon: nil,
                    title: "Accept\nTerms"
                )

                Color.clear
                    .frame(height: OnboardingLayout.titleBodySpacing)

                VStack(alignment: .leading, spacing: 8) {
                    Text("By continuing, you agree to the Ziora ")
                        .font(ZioraFont.body(16))
                        .foregroundColor(.primary)
                    +
                    Text("Terms of Service")
                        .font(ZioraFont.body(16))
                        .underline()
                        .foregroundColor(.blue)
                    +
                    Text(" and ")
                        .font(ZioraFont.body(16))
                        .foregroundColor(.primary)
                    +
                    Text("Privacy Policy")
                        .font(ZioraFont.body(16))
                        .underline()
                        .foregroundColor(.blue)
                }
                .lineSpacing(16 * 0.1)

                // 本文とボタンの間 75pt
                Color.clear
                    .frame(height: 75)

                VStack(spacing: OnboardingLayout.buttonSpacing) {
                    Button(action: onAgree) {
                        Text("Agree and Continue")
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
                        Text("Disagree")
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
        }
        .overlay(
            VStack {
                Spacer()
                OnboardingProgressDots(currentIndex: 1, totalCount: 3)
                    .padding(.bottom, OnboardingLayout.progressBottomOffset)
            }
        )
    }
}

// MARK: - ③-1 Agreement Required

struct AgreementRequiredView: View {
    let onBackToAgreement: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.zioraLightBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                OnboardingHeaderView(
                    systemIconName: "exclamationmark.triangle.fill",
                    icon: nil,
                    title: "Agreement\nRequired"
                )

                Color.clear
                    .frame(height: OnboardingLayout.titleBodySpacing)

                Text("""
To use Ziora, you need to agree to the Terms of Service and Privacy Policy.
These policies explain how we protect your data and ensure a safe experience for all users.
""")
                .font(ZioraFont.body(16))
                .foregroundColor(.primary)
                .lineSpacing(16 * 0.1)

                // 本文とボタンの間 75pt
                Color.clear
                    .frame(height: 75)

                VStack(spacing: OnboardingLayout.buttonSpacing) {
                    Button(action: onBackToAgreement) {
                        Text("Back to Agreement")
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
                        Text("Close")
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
