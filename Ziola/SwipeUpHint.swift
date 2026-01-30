import SwiftUI

struct SwipeUpHint: View {
    @State private var animate = false

    var body: some View {

        VStack(spacing: -8) { // 間隔を詰めて一体感を出す
            ForEach(0..<2) { index in
                // Custom wide chevron path for sharp edges and natural width
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 20))
                    path.addLine(to: CGPoint(x: 50, y: 0)) // Center top
                    path.addLine(to: CGPoint(x: 100, y: 20))
                }
                .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, lineCap: .butt, lineJoin: .miter))
                .frame(width: 100, height: 20)
                .opacity(animate ? 0.3 : 1.0)
                .offset(y: animate ? -8 : 0)
                    .animation(
                        Animation.easeInOut(duration: 1.0)
                            .repeatForever(autoreverses: true)
                            .delay(Double(1 - index) * 0.2),
                        value: animate
                    )
            }
        }
        .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
        .onAppear {
            animate = true
        }
    }
}
