import SwiftUI

struct OnboardingCard: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let iconName: String
}

/// 縦スクロールのオンボーディング画面
struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var currentPage = 0
    @State private var dragOffset: CGFloat = 0
    @State private var backgroundOffset: CGFloat = 0
    @State private var contentOffset: CGFloat = 0
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "en"

    // オンボーディングデータの定義（ローカライズキー）
    private let cards: [OnboardingCard] = [
        OnboardingCard(
            title: "Onboarding_Welcome_Title",
            description: "Onboarding_Welcome_Desc",
            iconName: "party.popper.fill"
        ),
        OnboardingCard(
            title: "Onboarding_Share_Title",
            description: "Onboarding_Share_Desc",
            iconName: "camera.fill"
        ),
        OnboardingCard(
            title: "Onboarding_Discover_Title",
            description: "Onboarding_Discover_Desc",
            iconName: "binoculars.fill"
        ),
        OnboardingCard(
            title: "Onboarding_Ready_Title",
            description: "Onboarding_Ready_Desc",
            iconName: "airplane"
        )
    ]

    // Helper to get string from specific language bundle
    private func localized(_ key: String) -> String {
        if let path = Bundle.main.path(forResource: selectedLanguage, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(key, tableName: nil, bundle: bundle, value: "", comment: "")
        }
        return key
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Large orb background that changes color per page
                OnboardingOrbBackground(currentPage: currentPage)
                    .offset(y: backgroundOffset * 0.3) // Slower parallax

                // Content container with full screen gesture area
                ZStack {
                    ForEach(0..<cards.count, id: \.self) { index in
                        OnboardingCardView(
                            card: cards[index],
                            isActive: currentPage == index,
                            currentIndex: currentPage,
                            totalCount: cards.count,
                            isLast: index == cards.count - 1,
                            onStart: onFinish
                        )
                        .offset(y: CGFloat(index - currentPage) * geometry.size.height + dragOffset)
                        .offset(y: contentOffset * 0.6) // Medium parallax for content
                        .opacity(index == currentPage ? 1 : 0)
                        .animation(.easeInOut(duration: 0.5), value: currentPage)
                        .animation(.easeInOut(duration: 0.3), value: contentOffset)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            // Allow upward swipe to go forward and downward swipe to go back
                            if value.translation.height < 0 && currentPage < cards.count - 1 {
                                // Swipe up - go to next page
                                dragOffset = value.translation.height
                                backgroundOffset = value.translation.height
                                contentOffset = value.translation.height
                            } else if value.translation.height > 0 && currentPage > 0 {
                                // Swipe down - go to previous page
                                dragOffset = value.translation.height
                                backgroundOffset = value.translation.height
                                contentOffset = value.translation.height
                            }
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 50
                            if value.translation.height < -threshold && currentPage < cards.count - 1 {
                                // Swipe up - advance to next page
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    currentPage += 1
                                    dragOffset = 0
                                    backgroundOffset = 0
                                    contentOffset = 0
                                }
                            } else if value.translation.height > threshold && currentPage > 0 {
                                // Swipe down - go back to previous page
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    currentPage -= 1
                                    dragOffset = 0
                                    backgroundOffset = 0
                                    contentOffset = 0
                                }
                            } else {
                                // Reset to current page
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    dragOffset = 0
                                    backgroundOffset = 0
                                    contentOffset = 0
                                }
                            }
                        }
                )

                // Swipe up hint overlay
                VStack {
                    Spacer()
                    if currentPage < cards.count - 1 {
                        SwipeUpIndicator()
                            .padding(.bottom, 60)
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: currentPage)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Card View
struct OnboardingCardView: View {
    let card: OnboardingCard
    let isActive: Bool
    let currentIndex: Int
    let totalCount: Int
    let isLast: Bool
    let onStart: () -> Void
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "en"

    // Helper to get string from specific language bundle
    private func localized(_ key: String) -> String {
        if let path = Bundle.main.path(forResource: selectedLanguage, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(key, tableName: nil, bundle: bundle, value: "", comment: "")
        }
        return key
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                    .frame(height: geometry.size.height * 0.15)

                // All titles and descriptions stacked vertically
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(0..<totalCount, id: \.self) { index in
                        let isCurrent = index == currentIndex
                        let cardData = getCardForIndex(index)

                        VStack(alignment: .leading, spacing: 0) {
                            // Title
                            Text(localized(cardData.title))
                                .font(.system(size: isCurrent ? 52 : 44, weight: .heavy))
                                .foregroundColor(.white.opacity(isCurrent ? 1.0 : 0.4))
                                .animation(.easeInOut(duration: 0.4), value: currentIndex)

                            // Description - slides in from top and pushes other content down
                            if isCurrent {
                                Text(localized(cardData.description))
                                    .font(.system(size: selectedLanguage == "ja" ? 16 : (selectedLanguage == "fr" ? 14 : (selectedLanguage == "es" ? 15 : 18)), weight: .regular))
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineSpacing(selectedLanguage == "ja" ? 5 : (selectedLanguage == "fr" ? 3 : (selectedLanguage == "es" ? 5 : 6)))
                                    .padding(.top, 12)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .move(edge: .top).combined(with: .opacity)
                                    ))
                            }
                        }
                        .animation(.easeInOut(duration: 0.45), value: currentIndex)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 40)

                Spacer()

                // Start button on last page - 固定高さで配置
                ZStack {
                    if isLast {
                        LongPressStartButton(onComplete: onStart)
                            .padding(.horizontal, 40)
                    }
                }
                .frame(height: 56) // ボタンと同じ高さに固定
                .padding(.bottom, 100)
            }
        }
    }

    // Helper to get card data for any index
    private func getCardForIndex(_ index: Int) -> OnboardingCard {
        let allCards = [
            OnboardingCard(title: "Onboarding_Welcome_Title", description: "Onboarding_Welcome_Desc", iconName: "party.popper.fill"),
            OnboardingCard(title: "Onboarding_Share_Title", description: "Onboarding_Share_Desc", iconName: "camera.fill"),
            OnboardingCard(title: "Onboarding_Discover_Title", description: "Onboarding_Discover_Desc", iconName: "binoculars.fill"),
            OnboardingCard(title: "Onboarding_Ready_Title", description: "Onboarding_Ready_Desc", iconName: "airplane")
        ]
        return allCards[index]
    }
}


