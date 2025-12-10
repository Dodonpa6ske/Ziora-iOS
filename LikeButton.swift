import SwiftUI
import UIKit

struct LikeButton: View {
    @Binding var isLiked: Bool
    
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        Button(action: {
            feedbackGenerator.impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isLiked.toggle()
            }
        }) {
            // ★変更点: 常に "heart.fill" (塗り) を使用
            Image(systemName: "heart.fill")
                .font(.system(size: 20, weight: .light))
                // ★変更点: OFFのときは黒色、ONのときはピンク
                .foregroundColor(isLiked ? Color(hex: "4347E6") : Color.black)
                // ★変更点: OFFのときは透明度40%
                .opacity(isLiked ? 1.0 : 0.2)
                .scaleEffect(isLiked ? 1.0 : 0.85)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLiked)
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)
    }
}

// プレビュー
struct LikeButton_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LikeButton(isLiked: .constant(false))
                .previewDisplayName("OFF (Opacity 20%)")
            LikeButton(isLiked: .constant(true))
                .previewDisplayName("ON")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
