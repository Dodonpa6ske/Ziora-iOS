import SwiftUI

struct Carousel3DView<Content: View, Item: Identifiable>: View {
    var items: [Item]
    var cardWidth: CGFloat = 300
    var cardHeight: CGFloat = 500
    var spacing: CGFloat = 20
    @Binding var index: Int
    @ViewBuilder var content: (Item) -> Content
    
    var body: some View {
        TabView(selection: $index) {
            ForEach(Array(items.enumerated()), id: \.element.id) { currentIndex, item in
                GeometryReader { itemProxy in
                    let minX = itemProxy.frame(in: .global).minX
                    let screenWidth = UIScreen.main.bounds.width
                    let screenCenter = screenWidth / 2
                    
                    // カード中心のグローバルX座標
                    // タブView内では、自身のminX + width/2 が現在位置
                    let currentX = minX + (itemProxy.size.width / 2)
                    
                    // 画面中心からの距離
                    let distanceFromCenter = currentX - screenCenter
                    
                    // 回転角度計算
                    let rotation = Double(distanceFromCenter / (screenWidth / 60))
                    
                    content(item)
                        .frame(width: cardWidth, height: cardHeight) // 指定サイズを適用
                        .rotation3DEffect(
                            .degrees(-rotation),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.5
                        )
                        .scaleEffect(1.0 - abs(distanceFromCenter / (screenWidth * 3)))
                        .opacity(1.0 - abs(distanceFromCenter / (screenWidth * 1.5)))
                        .position(x: itemProxy.size.width / 2, y: itemProxy.size.height / 2) // 中央に配置
                }
                .tag(currentIndex)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
}
