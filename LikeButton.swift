import SwiftUI

struct LikeButton: View {
    @Binding var isLiked: Bool

    var body: some View {
        Button {
            isLiked.toggle()
            let impact = UIImpactFeedbackGenerator(style: .soft)
            impact.impactOccurred()
        } label: {
            Image(systemName: isLiked ? "heart.fill" : "heart")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(
                    isLiked
                    ? Color(hex: "6C6BFF")
                    : Color.gray.opacity(0.4)   // 通常時は薄いグレー
                )
                .frame(width: 30, height: 30)   // 30x30
                .background(Color.white)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)   // シャドウは付けない
    }
}
