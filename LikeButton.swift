import SwiftUI

struct LikeButton: View {
    @Binding var isLiked: Bool

    var body: some View {
        Button(action: {
            // 状態の切り替え時に spring アニメーションを適用
            // これにより、アイコンが「ボヨン」と跳ねるように切り替わります
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4, blendDuration: 0)) {
                isLiked.toggle()
            }
        }) {
            // 背景の円は削除し、アイコンのみ表示
            Image(systemName: isLiked ? "heart.fill" : "heart")
                // サイズを少し大きめに設定 (以前の1.2倍スケール相当)
                .font(.system(size: 28, weight: .medium))
                // ONのときは鮮やかなピンク赤、OFFのときは少し濃いグレー
                .foregroundColor(isLiked ? Color(red: 1.0, green: 0.2, blue: 0.4) : Color.gray)
                // isLikedの状態変化に合わせてスケールも少しアニメーションさせることでポップアップ感を強調
                .scaleEffect(isLiked ? 1.05 : 1.0)
        }
        // タップ領域を少し広げるためにフレームを設定（見た目には影響しません）
        .frame(width: 44, height: 44)
    }
}

// プレビュー用（確認したい場合）
struct LikeButton_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LikeButton(isLiked: .constant(false))
                .previewDisplayName("OFF")
            LikeButton(isLiked: .constant(true))
                .previewDisplayName("ON")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
