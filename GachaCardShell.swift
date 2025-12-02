import SwiftUI
import GoogleMobileAds
import UIKit

/// ガチャカードと同じ見た目・サイズの外側だけをまとめたシェル
struct GachaCardShell<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            // 白いカード（GachaResultCard と同じスタイル）
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.18),
                        radius: 18, x: 0, y: 10)

            // 中身（画像 or 広告）
            content
                .padding(18)
        }
        // 幅だけ親ビューに任せる（高さは HomeView 側で統一）
        .frame(maxWidth: .infinity)
        .compositingGroup()
    }
}
