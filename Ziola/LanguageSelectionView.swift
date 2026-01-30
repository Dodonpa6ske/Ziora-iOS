import SwiftUI

struct LanguageOption: Identifiable {
    let id = UUID()
    let code: String
    let label: String
    let flagAssetName: String
}

struct LanguageSelectionView: View {
    @Binding var selectedLanguageCode: String?
    let onNext: () -> Void
    
    private let languages: [LanguageOption] = [
        .init(code: "en",      label: "English",    flagAssetName: "flag_us"),
        .init(code: "ja",      label: "日本語",       flagAssetName: "flag_jp"),
        .init(code: "ko",      label: "한국어",       flagAssetName: "flag_kr"),
        .init(code: "es",      label: "Español",    flagAssetName: "flag_es"),
        .init(code: "fr",      label: "Français",   flagAssetName: "flag_fr")
        
    ]

    var body: some View {
        ZStack {
            Color.zioraLightBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // ↑ ここからヘッダー部分は全画面共通
                OnboardingHeaderView(
                    systemIconName: "globe",
                    icon: nil,
                    title: "Select\nLanguage"
                )

                // タイトルとカードの間 60pt 固定
                Color.clear
                    .frame(height: OnboardingLayout.titleBodySpacing)

                // 言語リストカード
                VStack(spacing: 0) {
                    ForEach(languages.indices, id: \.self) { index in
                        let language = languages[index]

                        Button {
                            selectedLanguageCode = language.code
                            onNext()
                        } label: {
                            HStack(spacing: 12) {
                                Image(language.flagAssetName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)

                                Text(language.label)
                                    .font(ZioraFont.body(16))
                                    .foregroundColor(.primary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 20)
                        }
                        .buttonStyle(.plain)

                        if index < languages.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.vertical, 30)
                .padding(.horizontal, 55)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.white)
                )

                Spacer()
            }
            .padding(.horizontal, OnboardingLayout.horizontalPadding)
            // コンテンツ最下部とドットの間 115pt
            .padding(.bottom,
                     OnboardingLayout.progressBottomOffset
                     + OnboardingLayout.contentToDotsSpacing)

            // ★修正: Dotsをオーバーレイではなく兄弟要素として配置し、Safe Areaを尊重させる (位置統一のため)
            VStack {
                Spacer()
                OnboardingProgressDots(currentIndex: 0, totalCount: 3)
                    .padding(.bottom, OnboardingLayout.progressBottomOffset)
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}
