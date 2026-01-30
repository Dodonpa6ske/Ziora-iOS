import SwiftUI
import Lottie

struct SplashView: View {
    let onFinished: () -> Void

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            // Lottie Animation
            // JSON filename must be "splash.json" (imported as "splash") in the project
            LottieView(
                filename: "splash",
                loopMode: .playOnce,
                contentMode: .scaleAspectFit,
                delay: 0.5,
                onAnimationFinished: {
                    // Animation finished -> Wait 0.5s then transition
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onFinished()
                    }
                }
            )
            .frame(width: 77, height: 77) // 0.8x of previous 96
            .offset(y: -70) // Lowered additional 5px from -75
        }
    }
}
