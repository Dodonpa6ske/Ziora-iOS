import SwiftUI

struct CompletionCardView: View {
    let onReset: () -> Void
    let onReview: () -> Void
    
    // ★追加: ローカライズ
    @AppStorage("selectedLanguage") private var language: String = "en"
    private func localized(_ key: String) -> String {
        if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
        }
        return key
    }
    
    var body: some View {
        ZStack {
            // Background: Ziora Theme Gradient (Soft & Dreamy)
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "F3F0FF"), // Top-Left: Airy White/Purple
                    Color(hex: "E5E0FF"),
                    Color(hex: "908FF7").opacity(0.3) // Bottom-Right: Ziora Accent
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Decorative Blur Blobs
            GeometryReader { geo in
                Circle()
                    .fill(Color(hex: "908FF7").opacity(0.4))
                    .frame(width: 200, height: 200)
                    .position(x: geo.size.width * 0.9, y: geo.size.height * 0.2)
                    .blur(radius: 60)
                
                Circle()
                    .fill(Color(hex: "7573E6").opacity(0.3))
                    .frame(width: 250, height: 250)
                    .position(x: 0, y: geo.size.height * 0.8)
                    .blur(radius: 80)
            }
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

            // Main Content - Stacked Vertically
            VStack(alignment: .leading, spacing: 0) {
                
                // 1. Thank you! Section
                VStack(alignment: .leading, spacing: -20) { // Negative spacing for compact look
                    Text("DESIGN\nRESOURCES")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "908FF7").opacity(0.6))
                        .padding(.bottom, 8)
                        .hidden()
                    
                    // Split Text to guarantee line break and avoid truncation
                    Text("Thank")
                        .font(.system(size: 77, weight: .heavy))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "4A45C6"), Color(hex: "908FF7")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.white.opacity(0.8), radius: 0, x: 2, y: 2)
                    
                    Text("You!")
                        .font(.system(size: 77, weight: .heavy))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "4A45C6"), Color(hex: "908FF7")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.white.opacity(0.8), radius: 0, x: 2, y: 2)
                }
                .padding(.top, 48) // Increased top padding
                .padding(.horizontal, 30)
                .padding(.bottom, 32)
                
                // 2. Body Text
                Text(localized("CompletionMessage"))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .lineSpacing(5)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(Color(hex: "5A5586"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 30)
                
                Spacer()
                
                // 3. Buttons
                VStack(spacing: 14) {
                    Button(action: onReset) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text(localized("Reset & Re-spin"))
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56) // Standard height
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "908FF7"), Color(hex: "7573E6")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(28)
                        .shadow(color: Color(hex: "908FF7").opacity(0.4), radius: 10, x: 0, y: 6)
                    }
                    
                    Button(action: onReview) {
                        Text(localized("Write a Review"))
                            .font(.headline)
                            .foregroundColor(Color(hex: "7573E6"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56) // Standard height
                            .background(Color.white.opacity(0.5)) // Glassy
                            .cornerRadius(28)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 48) // Bottom padding for buttons
            }
        }
        // GachaResultCardと同じサイズとデザイン
        .frame(width: UIScreen.main.bounds.width - 48, height: 520) // Standard spacing
        .background(Color.white)
        .cornerRadius(32)
        .shadow(color: Color.black.opacity(0.15), radius: 24, x: 0, y: 12)
    }
}
