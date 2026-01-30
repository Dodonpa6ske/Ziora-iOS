import SwiftUI

/// Animated gradient orb background inspired by modern design trends
/// Features floating, pulsating orbs with blur effects
struct OrbBackgroundView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            // Base gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "1a1a2e"),
                    Color(hex: "16213e"),
                    Color(hex: "0f3460")
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Floating orbs
            ZStack {
                // Purple orb - top left
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "8B5CF6").opacity(0.8),
                                Color(hex: "7C3AED").opacity(0.4),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .blur(radius: 60)
                    .offset(
                        x: animate ? -120 : -80,
                        y: animate ? -200 : -240
                    )
                    .animation(
                        Animation.easeInOut(duration: 8)
                            .repeatForever(autoreverses: true),
                        value: animate
                    )

                // Blue orb - center right
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "3B82F6").opacity(0.7),
                                Color(hex: "2563EB").opacity(0.3),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 180
                        )
                    )
                    .frame(width: 350, height: 350)
                    .blur(radius: 50)
                    .offset(
                        x: animate ? 140 : 180,
                        y: animate ? 20 : -20
                    )
                    .animation(
                        Animation.easeInOut(duration: 7)
                            .repeatForever(autoreverses: true)
                            .delay(1),
                        value: animate
                    )

                // Pink orb - bottom center
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "EC4899").opacity(0.6),
                                Color(hex: "DB2777").opacity(0.3),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 160
                        )
                    )
                    .frame(width: 320, height: 320)
                    .blur(radius: 55)
                    .offset(
                        x: animate ? -40 : 20,
                        y: animate ? 280 : 320
                    )
                    .animation(
                        Animation.easeInOut(duration: 9)
                            .repeatForever(autoreverses: true)
                            .delay(2),
                        value: animate
                    )

                // Cyan orb - top right
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "06B6D4").opacity(0.5),
                                Color(hex: "0891B2").opacity(0.25),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 140
                        )
                    )
                    .frame(width: 280, height: 280)
                    .blur(radius: 45)
                    .offset(
                        x: animate ? 100 : 140,
                        y: animate ? -140 : -100
                    )
                    .animation(
                        Animation.easeInOut(duration: 6.5)
                            .repeatForever(autoreverses: true)
                            .delay(1.5),
                        value: animate
                    )

                // Amber orb - bottom left
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "F59E0B").opacity(0.4),
                                Color(hex: "D97706").opacity(0.2),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
                    .frame(width: 250, height: 250)
                    .blur(radius: 40)
                    .offset(
                        x: animate ? -160 : -120,
                        y: animate ? 240 : 200
                    )
                    .animation(
                        Animation.easeInOut(duration: 7.5)
                            .repeatForever(autoreverses: true)
                            .delay(0.5),
                        value: animate
                    )
            }
            .compositingGroup()
            .opacity(0.7)

            // Overlay for depth
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.3),
                    Color.clear,
                    Color.black.opacity(0.4)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .onAppear {
            animate = true
        }
    }
}

/// Lighter variant for onboarding with white base
struct OrbBackgroundLightView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            // Light gradient background
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

            // Floating orbs with lighter colors
            ZStack {
                // Purple orb
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "A78BFA").opacity(0.4),
                                Color(hex: "8B5CF6").opacity(0.2),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .blur(radius: 70)
                    .offset(
                        x: animate ? -120 : -80,
                        y: animate ? -200 : -240
                    )
                    .animation(
                        Animation.easeInOut(duration: 8)
                            .repeatForever(autoreverses: true),
                        value: animate
                    )

                // Blue orb
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "60A5FA").opacity(0.35),
                                Color(hex: "3B82F6").opacity(0.15),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 180
                        )
                    )
                    .frame(width: 350, height: 350)
                    .blur(radius: 60)
                    .offset(
                        x: animate ? 140 : 180,
                        y: animate ? 20 : -20
                    )
                    .animation(
                        Animation.easeInOut(duration: 7)
                            .repeatForever(autoreverses: true)
                            .delay(1),
                        value: animate
                    )

                // Pink orb
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "F472B6").opacity(0.3),
                                Color(hex: "EC4899").opacity(0.15),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 160
                        )
                    )
                    .frame(width: 320, height: 320)
                    .blur(radius: 65)
                    .offset(
                        x: animate ? -40 : 20,
                        y: animate ? 280 : 320
                    )
                    .animation(
                        Animation.easeInOut(duration: 9)
                            .repeatForever(autoreverses: true)
                            .delay(2),
                        value: animate
                    )

                // Cyan orb
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "22D3EE").opacity(0.25),
                                Color(hex: "06B6D4").opacity(0.12),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 140
                        )
                    )
                    .frame(width: 280, height: 280)
                    .blur(radius: 55)
                    .offset(
                        x: animate ? 100 : 140,
                        y: animate ? -140 : -100
                    )
                    .animation(
                        Animation.easeInOut(duration: 6.5)
                            .repeatForever(autoreverses: true)
                            .delay(1.5),
                        value: animate
                    )
            }
            .compositingGroup()
            .opacity(0.6)
        }
        .onAppear {
            animate = true
        }
    }
}

#Preview("Dark Orb Background") {
    OrbBackgroundView()
}

#Preview("Light Orb Background") {
    OrbBackgroundLightView()
}
