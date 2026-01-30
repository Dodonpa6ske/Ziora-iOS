import SwiftUI

// MARK: - Typewriter Text
struct TypewriterText: View {
    let text: LocalizedStringKey
    let font: Font
    let color: Color
    
    @State private var displayedText: String = ""
    @State private var showCursor: Bool = true
    
    // Config
    private let typingSpeed: TimeInterval = 0.075 // 75ms
    private let cursorBlinkSpeed: TimeInterval = 0.5
    
    var body: some View {
        HStack(spacing: 0) {
            Text(displayedText)
                .font(font)
                .foregroundColor(color)
            
            // Cursor
            if showCursor {
                Text("_")
                    .font(font)
                    .foregroundColor(color)
                    .opacity(showCursor ? 1 : 0)
            }
        }
        .onAppear {
            startTyping()
        }
    }
    
    private func startTyping() {
        // Blink cursor
        withAnimation(.easeInOut(duration: cursorBlinkSpeed).repeatForever()) {
            showCursor.toggle()
        }
        
        // Resolve LocalizedStringKey to String (simplified for this context)
        // Note: In a real app with strict localization, we'd need a better way to get the string content.
        // For now, let's assume direct string usage or basic reflection if needed, 
        // but robustly we might just pass String.
        // However, OnboardingCard uses Strings, let's accept String.
    }
}

// Improved TypewriterText accepting String directly to handle character count easier
struct TypewriterTextView: View {
    let text: String
    let font: Font
    let color: Color
    var startAnimation: Bool = true
    
    @State private var displayedText: String = ""
    @State private var timer: Timer?
    @State private var hasStarted: Bool = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Invisible full text to reserve layout space
            Text(text)
                .font(font)
                .foregroundColor(.clear)
                .fixedSize(horizontal: false, vertical: true)
            
            // Visible typed text
            Text(displayedText)
                .font(font)
                .foregroundColor(color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear {
            if startAnimation {
                runTyping()
            }
        }
        .onChange(of: startAnimation) { newValue in
            if newValue {
                runTyping()
            } else {
                // Should we reset? If user swipes back, maybe reset.
                // For now, let's keep it simple.
                timer?.invalidate()
                displayedText = ""
                hasStarted = false
            }
        }
    }
    
    private func runTyping() {
        guard !hasStarted else { return }
        hasStarted = true
        displayedText = ""
        timer?.invalidate()
        
        var charIndex = 0
        let chars = Array(text)
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { t in
            if charIndex < chars.count {
                displayedText.append(chars[charIndex])
                charIndex += 1
            } else {
                t.invalidate()
            }
        }
    }
}


// MARK: - Shiny Text
struct ShinyText: View {
    let text: String
    let font: Font
    let baseColor: Color
    let shineColor: Color

    @State private var offset: CGFloat = -1.0

    var body: some View {
        Text(text)
            .font(font)
            .foregroundColor(.clear) // Hide original text
            .overlay(
                // Gradient Mask
                GeometryReader { geo in
                    ZStack {
                        // Base Text
                        Text(text)
                            .font(font)
                            .foregroundColor(baseColor)

                        // Shine Layer
                        Text(text)
                            .font(font)
                            .foregroundColor(shineColor)
                            .mask(
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(stops: [
                                                .init(color: .clear, location: 0.1),
                                                .init(color: .white, location: 0.5), // Shine center
                                                .init(color: .clear, location: 0.9)
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .rotationEffect(.degrees(30)) // Slight angle
                                    .offset(x: -geo.size.width + (geo.size.width * 2 * offset))
                            )
                    }
                }
            )
            .fixedSize(horizontal: false, vertical: true)
            .onAppear {
                withAnimation(.linear(duration: 5.0).repeatForever(autoreverses: false)) {
                    offset = 1.0
                }
            }
    }
}

// MARK: - Split Text Animation (character by character with stagger)
struct SplitTextAnimation: View {
    let text: String
    let font: Font
    let color: Color
    var startAnimation: Bool = true

    @State private var animationProgress: CGFloat = 0

    var body: some View {
        // Use Text with multiline support instead of HStack to allow proper line wrapping
        Text(text)
            .font(font)
            .foregroundColor(color)
            .opacity(animationProgress)
            .offset(y: animationProgress < 1 ? 20 : 0)
            .blur(radius: animationProgress < 1 ? 8 : 0)
            .animation(
                .spring(response: 0.8, dampingFraction: 0.85)
                    .delay(0.2),
                value: animationProgress
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .onChange(of: startAnimation) { newValue in
                if newValue {
                    animationProgress = 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            animationProgress = 1
                        }
                    }
                } else {
                    animationProgress = 0
                }
            }
            .onAppear {
                if startAnimation {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation {
                            animationProgress = 1
                        }
                    }
                }
            }
    }
}

// MARK: - Scroll Reveal Animation (fade and slide up with blur)
struct ScrollRevealAnimation: View {
    let text: String
    let font: Font
    let color: Color
    var startAnimation: Bool = true

    @State private var revealed = false

    var body: some View {
        Text(text)
            .font(font)
            .foregroundColor(color)
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 50)
            .blur(radius: revealed ? 0 : 10)
            .animation(
                .spring(response: 1.0, dampingFraction: 0.8)
                    .delay(0.3),
                value: revealed
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .onChange(of: startAnimation) { newValue in
                if newValue {
                    revealed = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        revealed = true
                    }
                } else {
                    revealed = false
                }
            }
            .onAppear {
                if startAnimation {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        revealed = true
                    }
                }
            }
    }
}


