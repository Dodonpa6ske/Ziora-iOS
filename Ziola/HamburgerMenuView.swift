import SwiftUI
import FirebaseAuth

struct HamburgerMenuView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var storeManager: StoreManager
    @EnvironmentObject var authManager: AuthManager

    // アクション
    let onOpenAdFreePlan: () -> Void
    let onOpenNotificationSettings: () -> Void
    let onOpenLanguage: () -> Void
    
    // ★変更: Legalを2つに分割
    let onOpenTerms: () -> Void
    let onOpenPrivacy: () -> Void
    
    let onOpenContact: () -> Void
    let onOpenLinkAccount: () -> Void
    let onSignOut: () -> Void
    let onDeleteAccount: () -> Void
    
    @State private var isSharingApp = false
    private let appStoreUrl = URL(string: "https://apps.apple.com/jp/app/ziora/id6756263715")! // Correct Ziora URL

    // ★追加: 言語設定を取得
    @AppStorage("selectedLanguage") private var language: String = "en"
    
    // ★追加: ローカライズヘルパー
    private func localized(_ key: String) -> String {
        if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
        }
        return key
    }

    var body: some View {
        GeometryReader { proxy in
            let safeArea = proxy.safeAreaInsets
            let width = proxy.size.width
            let menuWidth = width * 0.85
            
            ZStack(alignment: .leading) {
                
                // 1. 背景
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeIn(duration: 0.22)) { isPresented = false }
                    }
                
                // 2. メニュー本体
                ZStack(alignment: .leading) {
                    Color.white.ignoresSafeArea()
                    
                    VStack(alignment: .leading, spacing: 0) {
                        
                        // --- Header ---
                        // User profile removed as requested
                        VStack(spacing: 0) { // Empty container to maintain structure if needed, or just remove spacing above
                        }
                        .padding(.top, safeArea.top + 80) // Increased from 40 to 80 to lower content
                        .padding(.bottom, 10)

                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 24) {
                                
                                // --- Premium Card ---
                                Button(action: {
                                    isPresented = false
                                    onOpenAdFreePlan()
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(localized(storeManager.hasPurchasedAdFree ? "Premium Plan" : "Go Ad-Free"))
                                                .font(.system(size: 18, weight: .bold, design: .rounded)) // Rounded Font
                                                .foregroundColor(.white)
                                            
                                            Text(localized(storeManager.hasPurchasedAdFree ? "Active" : "Remove ads"))
                                                .font(.system(size: 12, weight: .bold, design: .rounded)) // Rounded
                                                .foregroundColor(storeManager.hasPurchasedAdFree ? Color(hex: "6C6BFF") : .white)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(
                                                    Capsule()
                                                        .fill(storeManager.hasPurchasedAdFree ? Color.white : Color.white.opacity(0.2))
                                                )
                                        }
                                        Spacer()
                                        Image(systemName: storeManager.hasPurchasedAdFree ? "checkmark.circle.fill" : "sparkles")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                    }
                                    .padding(16)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color(hex: "6C6BFF"), Color(hex: "8E8DFF")]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .cornerRadius(16)
                                    .shadow(color: Color(hex: "6C6BFF").opacity(0.3), radius: 8, x: 0, y: 4)
                                }
                                .buttonStyle(ScaleButtonStyle())
                                .padding(.horizontal, 24)

                                // --- Settings ---
                                VStack(spacing: 8) {
                                    SectionHeader(text: localized("SETTINGS"))
                                    MenuRowItem(icon: "bell", title: localized("Notifications"), action: onOpenNotificationSettings) // bell.fill -> bell
                                    MenuRowItem(icon: "globe", title: localized("Language"), action: onOpenLanguage)
                                }
                                .padding(.horizontal, 24)
                                
                                // --- Community ---
                                VStack(spacing: 8) {
                                    SectionHeader(text: localized("COMMUNITY"))
                                    MenuRowItem(icon: "square.and.arrow.up", title: localized("Share App"), action: {
                                        isSharingApp = true
                                    })
                                }
                                .padding(.horizontal, 24)
                                
                                // --- Support ---
                                VStack(spacing: 8) {
                                    SectionHeader(text: localized("SUPPORT"))
                                    MenuRowItem(icon: "envelope", title: localized("Contact Us"), action: onOpenContact) // envelope.fill -> envelope
                                    
                                    // ★変更: 2つの項目に分割
                                    MenuRowItem(icon: "doc.text", title: localized("Terms of Service"), action: onOpenTerms)
                                    MenuRowItem(icon: "lock.shield", title: localized("Privacy Policy"), action: onOpenPrivacy)
                                }
                                .padding(.horizontal, 24)
                                
                                // --- Account ---
                                VStack(spacing: 8) {
                                    SectionHeader(text: localized("ACCOUNT"))
                                    
                                    // ★修正: authManager経由で監視
                                    if let user = authManager.currentUser, user.isAnonymous {
                                        MenuRowItem(
                                            icon: "person.crop.circle.badge.plus",
                                            title: localized("Link Account"),
                                            color: Color(hex: "6C6BFF"),
                                            action: onOpenLinkAccount
                                        )
                                    }
                                    
                                    MenuRowItem(icon: "rectangle.portrait.and.arrow.right", title: localized("Sign Out"), color: .gray, action: onSignOut)
                                    MenuRowItem(icon: "trash", title: localized("Delete Account"), color: .red, action: onDeleteAccount) // trash.fill -> trash
                                }
                                .padding(.horizontal, 24)
                            }
                            .padding(.bottom, 40)
                        }
                        
                        Spacer()
                        
                        // --- Footer ---
                        VStack(spacing: 4) {
                            Text(String(format: localized("Version %@"), appVersion))
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.6))
                            
                            Text("© 2025 Ziora. All rights reserved.")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, safeArea.bottom + 10)
                    }
                }
                .frame(width: menuWidth)
                .mask(RoundedCorner(radius: 30, corners: [.topRight, .bottomRight]))
                .shadow(color: Color.black.opacity(0.15), radius: 20, x: 5, y: 0)
                
                .gesture(
                    DragGesture().onEnded { value in
                        if value.translation.width < -50 {
                            withAnimation(.easeIn(duration: 0.22)) { isPresented = false }
                        }
                    }
                )
                .sheet(isPresented: $isSharingApp) {
                    ShareSheet(items: [localized("ShareMessage"), appStoreUrl])
                }
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var userName: String {
        guard let user = authManager.currentUser, !user.isAnonymous else {
            return localized("Guest User")
        }
        if let name = user.displayName, !name.isEmpty {
            return name
        }
        return user.email ?? localized("User")
    }
    
    private var userInitial: String {
        guard let user = authManager.currentUser, !user.isAnonymous else {
            return "G"
        }
        if let name = user.displayName, let first = name.first {
            return String(first).uppercased()
        }
        if let email = user.email, let first = email.first {
            return String(first).uppercased()
        }
        return "U"
    }
    
    private var userStatusText: String {
        if storeManager.hasPurchasedAdFree {
            return localized("Premium Member")
        }
        return localized("Free Plan")
    }
    
    private var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}

// MARK: - Components

struct SectionHeader: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.secondary.opacity(0.8))
            .padding(.leading, 8)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MenuRowItem: View {
    let icon: String
    let title: String
    var color: Color = Color(hex: "404040")
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20)) // 背景がなくなるので少し大きく(16->20)
                    .foregroundColor(color)
                    .frame(width: 30, height: 30) // アライメントを保つための枠確保
                
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded)) // Rounded Font
                    .foregroundColor(.primary)
                    .lineLimit(2) // Allow 2 lines for long languages (fr, es)
                    .minimumScaleFactor(0.6) // Scale down more if needed
                    .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(uiColor: .tertiaryLabel))
            }
            .padding(.vertical, 8) // Expanded touch area (4 -> 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}



struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
