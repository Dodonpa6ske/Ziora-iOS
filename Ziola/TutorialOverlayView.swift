import SwiftUI

/// Tutorial overlay shown on first app launch
struct TutorialOverlayView: View {
    @Binding var isShowing: Bool
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "en"

    @State private var pulseScale: CGFloat = 0.8
    @State private var textOpacity: Double = 1.0

    // Globe dimensions (matches GlobeSceneView padding in HomeView)
    private let globeSize: CGFloat = UIScreen.main.bounds.width * 1.1 // Approximate visible globe size
    private var globeYOffset: CGFloat {
        // Globe is padded: top 40, bottom 140
        // Center of available space
        return UIScreen.main.bounds.height / 2 - 10 // Raised by 5pts (Total -10 from center)
    }

    // Camera button dimensions (from HomeComponents.swift: buttonSize 84 + frame 8 = 92)
    private let cameraButtonSize: CGFloat = 100
    private var cameraButtonYOffset: CGFloat {
        // Button is at bottom with padding 40
        return UIScreen.main.bounds.height - 40 - cameraButtonSize / 1 - 20
    }

    // Helper to get string from specific language bundle
    private func localized(_ key: String) -> String {
        if let path = Bundle.main.path(forResource: selectedLanguage, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(key, tableName: nil, bundle: bundle, value: "", comment: "")
        }
        return key
    }

    var body: some View {
        ZStack {
            // Layer 1: Dimmed Background with Hole (Spotlight Effect)
            // Use clear color for the hole area to allow touch passthrough
            GeometryReader { geometry in
                ZStack {
                    Color.black.opacity(0.7)

                    // The Hole for the Globe
                    Circle()
                        .frame(width: globeSize, height: globeSize)
                        .position(x: UIScreen.main.bounds.width / 2, y: globeYOffset)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissTutorial()
                }
                // Allow touches in the hole to pass through to the globe
                .allowsHitTesting(true)
            }
            .allowsHitTesting(false) // Disable hit testing on the dimmed area to let globe receive swipes

            // Layer 2: UI Elements
            VStack {
                // Skip button
                HStack {
                    Spacer()
                    Button {
                        dismissTutorial()
                    } label: {
                        Text(localized("Skip"))
                            .font(.custom("Helvetica", size: 16))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    .padding(.top, 60)
                    .padding(.trailing, 30)
                }

                Spacer()

                // Instruction text - moved to bottom
                VStack(spacing: 16) {
                    Text(localized("Spin the Globe"))
                        .font(.custom("Helvetica-Bold", size: 40))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .opacity(textOpacity)
                    
                    Text(localized("Search for unseen landscapes."))
                        .font(.custom("Helvetica", size: 18))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .opacity(textOpacity)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
                .allowsHitTesting(false)
                .onAppear {
                    withAnimation(.easeIn(duration: 0.8).delay(0.3)) {
                        textOpacity = 1.0
                    }
                }
            }
        }
        .transition(.opacity)
    }

    private func dismissTutorial() {
        UserDefaults.standard.set(true, forKey: "hasSeenTutorial")
        withAnimation(.easeOut(duration: 0.3)) {
            isShowing = false
        }
    }
}

#Preview {
    TutorialOverlayView(isShowing: .constant(true))
}
