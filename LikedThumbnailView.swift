import SwiftUI

struct LikedThumbnailView: View {
    let photo: LikedPhoto
    let index: Int

    @State private var isVisible = false

    var body: some View {
        Image(uiImage: photo.image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipped()
            .cornerRadius(20)
            // ばらばらスライドイン
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 24)
            .onAppear {
                guard !isVisible else { return }
                let baseDelay = 0.08 * 1.5
                let delay = baseDelay * Double(index)

                withAnimation(.easeOut(duration: 0.45).delay(delay)) {
                    isVisible = true
                }
            }
    }
}
