import SwiftUI

struct SwipeUpHint: View {
    @State private var offset: CGFloat = 0

    var body: some View {
        Image(systemName: "arrow.up")
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(Color.white.opacity(0.9))
            .offset(y: offset)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true)
                ) {
                    offset = -10
                }
            }
    }
}
// MARK: - Camera main button

struct CameraMainButton: View {
    let action: () -> Void
    private let size: CGFloat = 85

    var body: some View {
        Button(action: action) {
            ZStack {
                // 外周ストローク
                Circle()
                    .strokeBorder(Color(hex: "6C6BFF").opacity(0.10), lineWidth: 2)
                    .frame(width: 80, height: 80)

                // 中央のグラデーション丸
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "908FF7"),
                                Color(hex: "6C6BFF")
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Image(systemName: "plus")
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
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

// MARK: - Circle icon button (paperplane / heart)

struct CircleIconButton: View {
    let systemName: String
    let size: CGFloat
    let foreground: Color
    let background: Color
    let showShadow: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(background)

                Circle()
                    .strokeBorder(Color.black.opacity(0.10), lineWidth: 2)

                if showShadow {
                    Circle()
                        .stroke(Color.white.opacity(0.4), lineWidth: 4)
                        .blur(radius: 2)
                        .offset(y: 2)
                        .opacity(0.6)
                }

                Image(systemName: systemName)
                    .font(.system(size: 25, weight: .bold))
                    .foregroundColor(foreground)
                    .frame(width: 25, height: 25)
            }
            .frame(width: size, height: size)
            .shadow(
                color: showShadow ? Color.black.opacity(0.25) : .clear,
                radius: showShadow ? 10 : 0,
                x: 0,
                y: showShadow ? 6 : 0
            )
        }
        .buttonStyle(.plain)
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
