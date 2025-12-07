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
    
    private let buttonSize: CGFloat = 84
    private let iconSize: CGFloat = 32
    private let plusThickness: CGFloat = 6
    private let plusCornerRadius: CGFloat = 2

    var body: some View {
        Button(action: action) {
            ZStack {
                // 背景の円
                Circle()
                    .fill(Color.zioraPrimary) // メインカラー（青紫）
                    .frame(width: buttonSize, height: buttonSize)
                    
                    // ★ 変更: overlay ではなく background にして背面に配置
                    // stroke ではなく、少し大きい円を敷いて縁取りに見せる
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            // ボタンより少し大きくして縁として見せる
                            .frame(width: buttonSize + 8, height: buttonSize + 8)
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

// プレビュー
struct CameraMainButton_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.2).ignoresSafeArea()
            CameraMainButton(action: {})
        }
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
    var showShadow: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // 背景の円
                Circle()
                    .fill(background)
                    .frame(width: size, height: size)
                    
                    // ★ 変更: background で背面に配置
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.05)) // 薄いグレー
                            // ボタンより少し大きくする（枠線の太さ分）
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

// プレビュー
struct CircleIconButton_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 20) {
            CircleIconButton(
                systemName: "paperplane.fill",
                size: 60,
                foreground: Color(hex: "908FF7"),
                background: .white,
                showShadow: true // 常にシャドウあり
            ) {}
            
            CircleIconButton(
                systemName: "heart.fill",
                size: 60,
                foreground: Color(hex: "908FF7"),
                background: .white,
                showShadow: true // 常にシャドウあり
            ) {}
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .previewLayout(.sizeThatFits)
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
