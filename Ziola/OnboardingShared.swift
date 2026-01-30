import SwiftUI

// MARK: - 共通レイアウト定数
enum OnboardingLayout {
    static let horizontalPadding: CGFloat = 57

    // セーフエリア上端からアイコンまで「130pt固定」
    static let iconTopSpacing: CGFloat = 130

    static let iconSize: CGFloat = 47
    static let iconTitleSpacing: CGFloat = 20
    static let titleBodySpacing: CGFloat = 60
    static let buttonSpacing: CGFloat = 20

    // 画面下から進行状況ドットまでの距離
    static let progressBottomOffset: CGFloat = 90

    // 本文／ボタンの一番下から進行状況ドットまでの距離
    static let contentToDotsSpacing: CGFloat = 50
}

// MARK: - 色とフォント

extension Color {
    static let zioraBlue = Color(
        red: 67/255, green: 71/255, blue: 230/255
    )

    /// オンボーディング用の淡いグレー背景 (#F6F6F6)
    static let zioraLightBackground = Color(
        red: 246/255, green: 246/255, blue: 246/255
    )
}

enum ZioraFont {
    static func title(_ size: CGFloat) -> Font {
        .custom("Helvetica-Bold", size: size)
    }
    static func body(_ size: CGFloat) -> Font {
        .custom("Helvetica", size: size)
    }
    static func button(_ size: CGFloat) -> Font {
        .custom("Helvetica", size: size)
    }
    static func buttonSemibold(_ size: CGFloat) -> Font {
        .custom("Helvetica-Bold", size: size)
    }
}

// MARK: - ドット

struct OnboardingProgressDots: View {
    let currentIndex: Int
    let totalCount: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalCount, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.primary
                                                : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - 共通ヘッダー（アイコン + タイトル）

struct OnboardingHeaderView: View {
    let systemIconName: String?
    let icon: Image?
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // 👇 Spacer ではなく「空ビュー＋高さ固定」
            Color.clear
                .frame(height: OnboardingLayout.iconTopSpacing)

            Group {
                if let icon = icon {
                    icon
                        .resizable()
                        .scaledToFit()
                } else if let systemIconName = systemIconName {
                    Image(systemName: systemIconName)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.primary)
                }
            }
            .frame(
                width: OnboardingLayout.iconSize,
                height: OnboardingLayout.iconSize
            )

            Color.clear
                .frame(height: OnboardingLayout.iconTitleSpacing)

            Text(title)
                .font(ZioraFont.title(18))
                .lineSpacing(18 * 0.1)
                .kerning(18 * 0.14)
                .foregroundColor(.primary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.9)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
