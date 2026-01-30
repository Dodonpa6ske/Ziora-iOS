import SwiftUI

struct CameraTutorialOverlayView: View {
    @Binding var isShowing: Bool
    var onOpenCamera: () -> Void

    @AppStorage("selectedLanguage") private var selectedLanguage: String = "en"
    @State private var textOpacity: Double = 0.0

    // Camera button dimensions (from HomeComponents.swift: buttonSize 84 + frame 8 = 92)
    private let cameraButtonSize: CGFloat = 92
    private var cameraButtonYPosition: CGFloat {
        // Button is at bottom with padding 40 from HomeView
        // Button center Y = screen height - bottom padding - button half height
        return UIScreen.main.bounds.height - 40 - cameraButtonSize / 2 - 30
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
            ZStack {
                Color.black.opacity(0.7)

                // The Hole for the Camera Button
                Circle()
                    .frame(width: cameraButtonSize, height: cameraButtonSize)
                    .position(x: UIScreen.main.bounds.width / 2, y: cameraButtonYPosition)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
            .ignoresSafeArea()
            .allowsHitTesting(false) // Don't block camera button taps

            // Layer 2: UI Elements with proper hit testing
            ZStack {
                VStack {
                    // Skip Button (Top Right)
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

                    // Instructions - positioned near camera button
                    VStack(spacing: 16) {
                        Text(localized("Your Turn to Share!"))
                            .font(.custom("Helvetica-Bold", size: 28))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .opacity(textOpacity)
                        
                        Text(localized("Capture your view and share it\nwith someone across the world.")) // \n is preserved from Localizable.strings
                            .font(.custom("Helvetica", size: 18))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .opacity(textOpacity)

                        // Arrow pointing down
                        Image(systemName: "arrow.down")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.top, 10)
                            .opacity(textOpacity)
                    }
                    .padding(.bottom, 180)
                    .allowsHitTesting(false)
                    .onAppear {
                        withAnimation(.easeIn(duration: 0.8).delay(0.5)) {
                            textOpacity = 1.0
                        }
                    }
                }

                // Interactive button area that receives taps - larger hit area
                Button {
                    onOpenCamera()
                    dismissTutorial()
                } label: {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: cameraButtonSize + 20, height: cameraButtonSize + 20)
                }
                .position(x: UIScreen.main.bounds.width / 2, y: cameraButtonYPosition)
            }
        }
        .transition(.opacity)
    }
    
    private func dismissTutorial() {
        UserDefaults.standard.set(true, forKey: "hasSeenCameraTutorial")
        withAnimation(.easeOut(duration: 0.3)) {
            isShowing = false
        }
    }
}
