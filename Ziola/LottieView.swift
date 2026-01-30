import SwiftUI
import Lottie

struct LottieView: UIViewRepresentable {
    var filename: String
    var loopMode: LottieLoopMode = .playOnce
    var contentMode: UIView.ContentMode = .scaleAspectFit
    var delay: TimeInterval = 0 // Delay before starting animation
    var onAnimationFinished: (() -> Void)? = nil
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        
        // Initialize LottieAnimationView here
        // Force Main Thread rendering to support Merge Paths (Exclude Intersections)
        let animationView = LottieAnimationView(
            name: filename,
            configuration: LottieConfiguration(renderingEngine: .mainThread)
        )
        animationView.contentMode = contentMode
        animationView.loopMode = loopMode
        animationView.backgroundBehavior = .pauseAndRestore
        
        animationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animationView)
        
        NSLayoutConstraint.activate([
            animationView.heightAnchor.constraint(equalTo: view.heightAnchor),
            animationView.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])
        
        // Start playing
        let playAnimation = {
            animationView.play { finished in
                if finished {
                    onAnimationFinished?()
                }
            }
        }
        
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                playAnimation()
            }
        } else {
            playAnimation()
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed for static filename/config
    }
}
