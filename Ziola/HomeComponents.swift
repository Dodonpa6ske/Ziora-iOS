import SwiftUI

// MARK: - Camera main button

struct CameraMainButton: View {
    let action: () -> Void
    
    private let buttonSize: CGFloat = 84
    private let iconSize: CGFloat = 32
    private let plusThickness: CGFloat = 6
    private let plusCornerRadius: CGFloat = 2

    var body: some View {
        Button(action: action) {
            ZStack {
                // 背景の円
                Circle()
                    .fill(Color(hex: "908FF7")) // Main color (Hardcoded to match previous ZiolaPrimary logic if not available, or use Color("ZiolaPrimary") if asset exists. Using hex from prev file)
                    .frame(width: buttonSize, height: buttonSize)
                    
                    .background(
                        // Liquid Glass Outer Frame
                        LiquidGlassCircle(
                            size: buttonSize + 8,
                            topOpacity: 0.5,   // Reduced opacity (Half of 1.0)
                            bottomOpacity: 0.3, // Reduced opacity (Half of 0.6)
                            showShadow: false,  // User requested "keep shadow as is" (implied no extra shadow on ring)
                            isAnimated: true    // Enable gradient animation
                        )
                    )
                
                // プラスアイコン
                ZStack {
                    RoundedRectangle(cornerRadius: plusCornerRadius)
                        .fill(Color.white)
                        .frame(width: iconSize, height: plusThickness)
                    
                    RoundedRectangle(cornerRadius: plusCornerRadius)
                        .fill(Color.white)
                        .frame(width: plusThickness, height: iconSize)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Background gradient

struct ZioraBackgroundGradient: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(hex: "FFFFFF"), location: 0.0),
                .init(color: Color(hex: "ABACF4"), location: 0.27),
                .init(color: Color(hex: "4347E6"), location: 0.93)
            ]),
            startPoint: .bottom,
            endPoint: .top
        )
    }
}

// MARK: - Reusable Liquid Glass Style

struct LiquidGlassCircle: View {
    let size: CGFloat
    // Parameters to control brightness/transparency
    var topOpacity: Double = 0.85
    var bottomOpacity: Double = 0.25
    var showShadow: Bool = true
    var isAnimated: Bool = false // Toggle for animation
    
    @State private var startAnimation = false
    
    var body: some View {
        ZStack {
            // 1. Base Material (Blur)
            Circle()
                .fill(.ultraThinMaterial)
            
            // 2. Glossy Gradient (Liquid feel)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(topOpacity),
                            .white.opacity(bottomOpacity)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .rotationEffect(.degrees(isAnimated && startAnimation ? 360 : 0))
                .animation(
                    isAnimated ? Animation.linear(duration: 3).repeatForever(autoreverses: false) : .default,
                    value: startAnimation
                )
            
            // 3. Border
            Circle()
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
        }
        .frame(width: size, height: size)
        // Refined Shadow: Considerably more compact (Radius 2, Y 1) and Lighter (Opacity 0.08)
        .shadow(color: showShadow ? Color.black.opacity(0.08) : .clear, radius: 2, x: 0, y: 1)
        .onAppear {
            if isAnimated {
                startAnimation = true
            }
        }
    }
}

// MARK: - Circle icon button (paperplane / heart)

struct CircleIconButton: View {
    let systemName: String
    let size: CGFloat
    let foreground: Color
    let background: Color // NOTE: Ignored for Liquid Glass style, but kept for API compatibility
    var showShadow: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Liquid Glass Background - Even Brighter for Home Screen buttons
                LiquidGlassCircle(
                    size: size,
                    topOpacity: 1.0,    // Fully opaque white at top
                    bottomOpacity: 0.9  // Almost solid white at bottom
                )

                // Icon
                Image(systemName: systemName)
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundColor(foreground)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Rounded icon button (Square but smart)
struct RoundedIconButton: View {
    let systemName: String
    let size: CGFloat
    let foreground: Color
    let background: Color
    var showShadow: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // 背景
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(background)
                    .frame(width: size, height: size)
                    
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.black.opacity(0.05)) // 薄いグレー
                            .frame(width: size + 3, height: size + 3)
                    )

                // アイコン
                Image(systemName: systemName)
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundColor(foreground)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}


// MARK: - Hamburger icon (3本線)

struct HamburgerIcon: View {
    var body: some View {
        VStack(spacing: 6) {
            Rectangle()
                .frame(width: 28, height: 2)
            Rectangle()
                .frame(width: 28, height: 2)
            Rectangle()
                .frame(width: 28, height: 2)
        }
        .foregroundColor(.white)
    }
}

// MARK: - Liquid Glass Close Button

struct LiquidGlassCloseButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                LiquidGlassCircle(size: 60)
                
                // Icon
                Image(systemName: "xmark")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.black.opacity(0.7))
            }
            .frame(width: 60, height: 60)
        }
    }
}
