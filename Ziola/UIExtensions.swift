import SwiftUI

// 16進カラー "908FF7" などから Color を作る
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0) // Default to black
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// 日付表示用フォーマッタ
extension DateFormatter {
    static let zioraDisplay: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy.MM.dd HH:mm"
        return df
    }()
}

// MARK: - Custom Colors
extension Color {
    static let zioraPrimary = Color(hex: "6C6BFF") // アプリのメインカラー（青紫）
}

// MARK: - Button Styles
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Orb Border Effect
struct OrbBorderModifier: ViewModifier {
    let width: CGFloat
    let cornerRadius: CGFloat
    
    @State private var rotation: Double = 0
    
    // Ziora Theme Colors for the Orb Gradient
    private let gradientColors: [Color] = [
        Color(hex: "4347E6"), // Ziora Blue
        Color(hex: "908FF7"), // Lighter Purple
        .cyan,
        .white,
        .cyan,
        Color(hex: "908FF7"),
        Color(hex: "4347E6")
    ]
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: gradientColors),
                            center: .center,
                            startAngle: .degrees(rotation),
                            endAngle: .degrees(rotation + 360)
                        ),
                        lineWidth: width * 2 // Double width in background -> half visible as "outside" border
                    )
                    .blur(radius: 4) // Increased blur for better "Orb" glow
            )
            .shadow(color: Color(hex: "908FF7").opacity(0.5), radius: 15, x: 0, y: 0) // Stronger ambient glow
            .onAppear {
                withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) { // Slower animation
                    rotation = 360
                }
            }
    }
}

extension View {
    func orbBorder(width: CGFloat = 2, cornerRadius: CGFloat = 32) -> some View {
        self.modifier(OrbBorderModifier(width: width, cornerRadius: cornerRadius))
    }
}

// MARK: - Localization Helper
extension String {
    func localized() -> String {
        // ユーザーが選択した言語コードを取得 (デフォルトは "en")
        let langCode = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en"
        
        // 言語ごとのバンドルを取得
        if let path = Bundle.main.path(forResource: langCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: self, value: nil, table: nil)
        }
        
        // フォールバック
        return NSLocalizedString(self, comment: "")
    }
}
