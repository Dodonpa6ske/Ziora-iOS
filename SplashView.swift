import SwiftUI

struct SplashView: View {
    let onFinished: () -> Void

    @State private var logoOpacity: Double = 0.0

    var body: some View {
        ZStack {
            Color.zioraBlue
                .ignoresSafeArea()

            // Ziora ロゴ（PDF アセット名を "ziola_logo" として追加する想定）
            Image("ziora_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96) // 120px の 0.8倍サイズ
                .opacity(logoOpacity)
        }
        .onAppear {
            // ロゴをふわっと表示させるアニメーション
            withAnimation(.easeOut(duration: 0.8)) {
                logoOpacity = 1.0
            }

            // 一定時間表示したら次の画面へ
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                onFinished()
            }
        }
    }
}
