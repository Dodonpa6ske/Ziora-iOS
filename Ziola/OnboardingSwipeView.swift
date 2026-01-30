import SwiftUI

/// Enhanced onboarding with swipe-up transitions and parallax effects
struct OnboardingSwipeView: View {
    var onFinish: () -> Void

    @State private var currentPage = 0
    @State private var dragOffset: CGFloat = 0
    @State private var backgroundOffset: CGFloat = 0
    @State private var contentOffset: CGFloat = 0
    @State private var titleOffset: CGFloat = 0
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "en"

    // Helper to get string from specific language bundle
    private func localized(_ key: String) -> String {
        if let path = Bundle.main.path(forResource: selectedLanguage, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(key, tableName: nil, bundle: bundle, value: "", comment: "")
        }
        return key
    }

    private let pages: [OnboardingPageData] = [
        OnboardingPageData(
            titleKey: "Onboarding_Welcome_Title",
            descriptionKey: "Onboarding_Welcome_Desc",
            iconName: "party.popper.fill",
            accentColor: Color(hex: "8B5CF6")
        ),
        OnboardingPageData(
            titleKey: "Onboarding_Share_Title",
            descriptionKey: "Onboarding_Share_Desc",
            iconName: "camera.fill",
            accentColor: Color(hex: "EC4899")
        ),
        OnboardingPageData(
            titleKey: "Onboarding_Discover_Title",
            descriptionKey: "Onboarding_Discover_Desc",
            iconName: "binoculars.fill",
            accentColor: Color(hex: "3B82F6")
        ),
        OnboardingPageData(
            titleKey: "Onboarding_Ready_Title",
            descriptionKey: "Onboarding_Ready_Desc",
            iconName: "airplane",
            accentColor: Color(hex: "06B6D4")
        )
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Large orb background that changes color per page
                OnboardingOrbBackground(currentPage: currentPage, parallaxOffset: backgroundOffset * 0.3)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: backgroundOffset)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: backgroundOffset)

                // Content container with full screen gesture area
                ZStack {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(
                            page: pages[index],
                            isActive: currentPage == index,
                            isLast: index == pages.count - 1,
                            onStart: onFinish,
                            localizedTitle: localized(pages[index].titleKey),
                            localizedDescription: localized(pages[index].descriptionKey)
                        )
                        .offset(y: CGFloat(index - currentPage) * geometry.size.height + dragOffset)
                        .offset(y: contentOffset * 0.6) // Medium parallax for content
                        .opacity(index == currentPage ? 1 : 0.3)
                        .scaleEffect(index == currentPage ? 1 : 0.85)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentPage)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: contentOffset)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity) // Expand to full screen
                .contentShape(Rectangle()) // Make entire area tappable/swipeable
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            // Allow upward swipe to go forward and downward swipe to go back
                            if value.translation.height < 0 && currentPage < pages.count - 1 {
                                // Swipe up - go to next page
                                dragOffset = value.translation.height
                                // Parallax effect during drag
                                backgroundOffset = value.translation.height
                                contentOffset = value.translation.height
                                titleOffset = value.translation.height * 0.4 // Fastest parallax
                            } else if value.translation.height > 0 && currentPage > 0 {
                                // Swipe down - go to previous page
                                dragOffset = value.translation.height
                                // Parallax effect during drag
                                backgroundOffset = value.translation.height
                                contentOffset = value.translation.height
                                titleOffset = value.translation.height * 0.4
                            }
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 50
                            if value.translation.height < -threshold && currentPage < pages.count - 1 {
                                // Swipe up - advance to next page
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    currentPage += 1
                                    dragOffset = 0
                                    backgroundOffset = 0
                                    contentOffset = 0
                                    titleOffset = 0
                                }
                            } else if value.translation.height > threshold && currentPage > 0 {
                                // Swipe down - go back to previous page
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    currentPage -= 1
                                    dragOffset = 0
                                    backgroundOffset = 0
                                    contentOffset = 0
                                    titleOffset = 0
                                }
                            } else {
                                // Reset to current page
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    dragOffset = 0
                                    backgroundOffset = 0
                                    contentOffset = 0
                                    titleOffset = 0
                                }
                            }
                        }
                )


                // Swipe up hint overlay
                VStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        SwipeUpIndicator()
                            .padding(.bottom, 60)
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: currentPage)
            }
        }
        .ignoresSafeArea()
        .id(selectedLanguage) // Force redraw when language changes
    }
}

// MARK: - Supporting Types

struct OnboardingPageData {
    let titleKey: String
    let descriptionKey: String
    let iconName: String
    let accentColor: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPageData
    let isActive: Bool
    let isLast: Bool
    let onStart: () -> Void
    let localizedTitle: String
    let localizedDescription: String

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Content
            VStack(alignment: .leading, spacing: 24) {
                // Title with Split Text Animation (1.5x larger: 36 * 1.5 = 54)
                SplitTextAnimation(
                    text: localizedTitle,
                    font: .custom("Helvetica-Bold", size: 54),
                    color: .white,
                    startAnimation: isActive
                )

                // Description with Scroll Reveal Animation (1.5x larger: 17 * 1.5 = 25.5)
                ScrollRevealAnimation(
                    text: localizedDescription,
                    font: .custom("Helvetica", size: 25.5),
                    color: .white.opacity(0.95),
                    startAnimation: isActive
                )
                .lineSpacing(9) // Also scale line spacing (6 * 1.5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)

            Spacer()

            // Start button on last page (long press to start)
            if isLast {
                OnboardingStartButton(
                    accentColor: page.accentColor,
                    onComplete: onStart
                )
                .padding(.horizontal, 40)
                .padding(.bottom, 100)
            } else {
                Spacer()
                    .frame(height: 156)
            }
        }
    }
}

struct SwipeUpIndicator: View {
    @State private var animate = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chevron.up")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .offset(y: animate ? -10 : 0)
                .animation(
                    Animation.easeInOut(duration: 1)
                        .repeatForever(autoreverses: true),
                    value: animate
                )

            Text(NSLocalizedString("Swipe up", comment: ""))
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .onAppear {
            animate = true
        }
    }
}

// MARK: - Onboarding Start Button with Long Press
struct OnboardingStartButton: View {
    let accentColor: Color
    var onComplete: () -> Void

    @State private var isPressing = false
    @State private var progress: CGFloat = 0.0
    @State private var timer: Timer?
    @State private var starID = 0
    @State private var activeStars: [Int] = []
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "en"

    private let requiredDuration: TimeInterval = 1.0

    private func localized(_ key: String) -> String {
        if let path = Bundle.main.path(forResource: selectedLanguage, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(key, tableName: nil, bundle: bundle, value: "", comment: "")
        }
        return key
    }

    var body: some View {
        ZStack {
            // Star particles
            ForEach(activeStars, id: \.self) { _ in
                OnboardingStarParticle(color: Color(hex: "4347E6"))
            }

            // Button body
            ZStack(alignment: .leading) {
                // Base background with glassmorphism effect
                let buttonColor = Color(hex: "4347E6") // Orb color for progress

                RoundedRectangle(cornerRadius: 28)
                    .fill(.white.opacity(0.25))
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(.white.opacity(0.4), lineWidth: 1.5)
                    )

                // Progress bar
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                colors: [buttonColor.opacity(0.8), buttonColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress)
                        .animation(nil, value: progress) // Remove animation delay
                }
                .mask(RoundedRectangle(cornerRadius: 28))

                // Text
                HStack(spacing: 12) {
                    Spacer()
                    Image(systemName: isPressing ? "hand.tap.fill" : "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .scaleEffect(isPressing ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3), value: isPressing)

                    Text(progress >= 1.0 ? localized("Lets_Go") : (isPressing ? localized("Hold_to_Start") : localized("Start_Journey")))
                        .font(.custom("Helvetica-Bold", size: (selectedLanguage == "fr" || selectedLanguage == "es" || selectedLanguage == "ko") ? 16 : 18))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Spacer()
                }
                .foregroundColor(.white)
                .animation(.easeInOut(duration: 0.2), value: progress)
            }
            .frame(height: 56)
            .scaleEffect(isPressing ? 0.98 : 1.0)
            .shadow(
                color: Color(hex: "4347E6").opacity(isPressing ? 0.6 : 0.3),
                radius: isPressing ? 25 : 15,
                x: 0,
                y: 10
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressing)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressing { startPress() }
                    }
                    .onEnded { _ in
                        endPress()
                    }
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func startPress() {
        guard progress < 1.0 else { return }
        isPressing = true

        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()

        let startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            let elapsed = Date().timeIntervalSince(startTime)
            let newProgress = CGFloat(min(elapsed / requiredDuration, 1.0))

            // Update progress immediately without animation
            withAnimation(nil) {
                self.progress = newProgress
            }

            if Int(elapsed * 100) % 8 == 0 {
                addStar()
                feedback.impactOccurred(intensity: 0.3)
            }

            if newProgress >= 1.0 {
                completePress()
            }
        }
    }

    private func endPress() {
        if progress < 1.0 {
            isPressing = false
            timer?.invalidate()
            withAnimation(.easeOut(duration: 0.25)) {
                progress = 0.0
            }
        }
    }

    private func completePress() {
        timer?.invalidate()
        progress = 1.0

        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)

        for _ in 0..<15 { addStar() }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onComplete()
        }
    }

    private func addStar() {
        let id = starID
        starID += 1
        activeStars.append(id)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            activeStars.removeAll { $0 == id }
        }
    }
}

struct OnboardingStarParticle: View {
    let color: Color
    @State private var offset: CGSize = .zero
    @State private var opacity: Double = 1.0
    @State private var scale: CGFloat = 0.8

    var body: some View {
        Image(systemName: "star.fill")
            .foregroundColor(color)
            .font(.system(size: 10))
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(offset)
            .onAppear {
                withAnimation(.easeOut(duration: 1.2)) {
                    let angle = Double.random(in: -Double.pi...0)
                    let distance = CGFloat.random(in: 60...120)
                    offset = CGSize(
                        width: cos(angle) * distance,
                        height: sin(angle) * distance
                    )
                    opacity = 0
                    scale = 0.2
                }
            }
    }
}

#Preview {
    OnboardingSwipeView(onFinish: {})
}
