import SwiftUI

struct SplitTextView: View {
    let text: String
    let font: Font
    let color: Color
    var delay: Double = 0.0
    var duration: Double = 0.5
    
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { index, char in
                Text(String(char))
                    .font(font)
                    .foregroundColor(color)
                    .opacity(isVisible ? 1 : 0)
                    .offset(y: isVisible ? 0 : 20)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0)
                        .delay(delay + Double(index) * 0.03),
                        value: isVisible
                    )
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.3)
        .onAppear {
            isVisible = true
        }
    }
}

#Preview {
    ZStack {
        Color.black
        SplitTextView(text: "Spin the Globe", font: .largeTitle, color: .white)
    }
}
