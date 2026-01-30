import SwiftUI

/// Large orb background that changes color based on current page
/// Similar size to the globe in HomeView
struct OnboardingOrbBackground: View {
    let currentPage: Int
    var parallaxOffset: CGFloat = 0

    @State private var animateOffset1: CGFloat = 0
    @State private var animateOffset2: CGFloat = 0
    @State private var animateScale: CGFloat = 1.0
    @State private var animateRotation: Double = 0
    @State private var colorProgress: CGFloat = 0

    // Color scheme for each page (All similar to Ready to depart color)
    // Based on home gradient color #4347E6 with subtle variations
    private let pageColors: [Color] = [
        Color(hex: "5B5FED"), // Slightly lighter blue-purple - Page 0
        Color(hex: "5256EB"), // Medium blue-purple - Page 1
        Color(hex: "4A4EE9"), // Closer to base - Page 2
        Color(hex: "4549E7"), // Very close to base - Page 3
        Color(hex: "4347E6")  // Home gradient color - Page 4 (Ready to Depart)
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "F8F9FF"),
                        Color(hex: "EEF2FF"),
                        Color(hex: "E0E7FF")
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Organic blob orb with color animation
                let orbSize: CGFloat = geometry.size.height * 0.58 * 2
                let currentColor = pageColors[min(currentPage, pageColors.count - 1)]
                let nextColor = pageColors[min(currentPage + 1, pageColors.count - 1)]

                // Interpolate between current and next color for smooth transition
                let blendedColor = Color(
                    red: Double(currentColor.cgColor?.components?[0] ?? 0) * (1 - colorProgress) + Double(nextColor.cgColor?.components?[0] ?? 0) * colorProgress,
                    green: Double(currentColor.cgColor?.components?[1] ?? 0) * (1 - colorProgress) + Double(nextColor.cgColor?.components?[1] ?? 0) * colorProgress,
                    blue: Double(currentColor.cgColor?.components?[2] ?? 0) * (1 - colorProgress) + Double(nextColor.cgColor?.components?[2] ?? 0) * colorProgress
                )

                // Organic blob shape using multiple overlapping circles
                ZStack {
                    // Main blob with stronger shape animation
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    blendedColor.opacity(0.9),
                                    blendedColor.opacity(0.7),
                                    blendedColor.opacity(0.5),
                                    blendedColor.opacity(0.2),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: orbSize / 2
                            )
                        )
                        .frame(width: orbSize, height: orbSize)
                        .scaleEffect(x: 1.0 + animateOffset1 * 0.25, y: 1.0 - animateOffset1 * 0.18)

                    // Secondary blob for organic movement with stronger animation
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    blendedColor.opacity(0.6),
                                    blendedColor.opacity(0.4),
                                    blendedColor.opacity(0.2),
                                    Color.clear
                                ]),
                                center: UnitPoint(x: 0.6, y: 0.4),
                                startRadius: 0,
                                endRadius: orbSize / 2.5
                            )
                        )
                        .frame(width: orbSize * 0.8, height: orbSize * 0.8)
                        .offset(x: animateOffset2 * 50, y: animateOffset2 * 40)
                        .scaleEffect(x: 1.0 + animateOffset2 * 0.15, y: 1.0 - animateOffset2 * 0.12)

                    // Tertiary blob for more organic feel with stronger animation
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    blendedColor.opacity(0.5),
                                    blendedColor.opacity(0.3),
                                    Color.clear
                                ]),
                                center: UnitPoint(x: 0.3, y: 0.7),
                                startRadius: 0,
                                endRadius: orbSize / 3
                            )
                        )
                        .frame(width: orbSize * 0.6, height: orbSize * 0.6)
                        .offset(x: -animateOffset1 * 40, y: animateOffset2 * 35)
                        .scaleEffect(x: 1.0 - animateOffset1 * 0.12, y: 1.0 + animateOffset1 * 0.15)
                }
                .blur(radius: 45)
                .scaleEffect(animateScale)
                .rotationEffect(.degrees(animateRotation))
                .position(
                    x: geometry.size.width / 2,
                    y: geometry.size.height * 0.55 + parallaxOffset
                )
                .onAppear {
                    // Organic movement animation 1
                    withAnimation(
                        Animation.easeInOut(duration: 5.0)
                            .repeatForever(autoreverses: true)
                    ) {
                        animateOffset1 = 1.0
                    }
                    // Organic movement animation 2 (different timing for more organic feel)
                    withAnimation(
                        Animation.easeInOut(duration: 6.5)
                            .repeatForever(autoreverses: true)
                    ) {
                        animateOffset2 = 1.0
                    }
                    // Scale pulsing - stronger breathing effect
                    withAnimation(
                        Animation.easeInOut(duration: 4.0)
                            .repeatForever(autoreverses: true)
                    ) {
                        animateScale = 1.15
                    }
                    // Slow rotation for organic movement
                    withAnimation(
                        Animation.linear(duration: 20.0)
                            .repeatForever(autoreverses: false)
                    ) {
                        animateRotation = 360
                    }
                    // Color gradient animation
                    withAnimation(
                        Animation.easeInOut(duration: 3.0)
                            .repeatForever(autoreverses: true)
                    ) {
                        colorProgress = 0.3
                    }
                }

                // Subtle overlay gradient for depth
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.1),
                        Color.clear,
                        Color.black.opacity(0.03)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        }
    }
}

#Preview {
    OnboardingOrbBackground(currentPage: 0)
}
