import SwiftUI

struct LikedThumbnailView: View {
    let photo: LikedPhoto
    let index: Int

    @State private var image: UIImage? = nil
    @State private var isVisible = false

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                // ロード中はグレーの背景
                Color.gray.opacity(0.2)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipped()
        .cornerRadius(20)
        // ふわっと表示させるアニメーション
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 24)
        .onAppear {
            // まだ読み込んでいなければローカルから画像をロード
            if image == nil {
                DispatchQueue.global(qos: .userInitiated).async {
                    let loaded = LikedPhotoStore.shared.loadLocalImage(for: photo)
                    DispatchQueue.main.async {
                        self.image = loaded
                    }
                }
            }
            
            // 表示アニメーション
            guard !isVisible else { return }
            let baseDelay = 0.08 * 1.5
            let delay = baseDelay * Double(index)

            withAnimation(.easeOut(duration: 0.45).delay(delay)) {
                isVisible = true
            }
        }
    }
}
