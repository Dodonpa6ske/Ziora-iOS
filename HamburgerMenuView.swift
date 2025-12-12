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
    let onOpenLegal: () -> Void
    let onOpenContact: () -> Void
    let onSignOut: () -> Void
    let onDeleteAccount: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let safeArea = proxy.safeAreaInsets
            let width = proxy.size.width
            // メニューの幅を画面幅の85%程度に制限
            let menuWidth = width * 0.85
            
            ZStack(alignment: .leading) {
                
                // 1. メニュー外のタップ領域 (透明な背景)
                // これを置くことで、メニューの右側（隙間）をタップした時に閉じられるようにする
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeIn(duration: 0.22)) { isPresented = false }
                    }
                
                // 2. メニュー本体 (左側のパネル)
                ZStack(alignment: .leading) {
                    // 背景
                    Color.white.ignoresSafeArea()
                    
                    // コンテンツ
                    VStack(alignment: .leading, spacing: 0) {
                        
                        // --- Header ---
                        HStack(spacing: 16) {
                            if let _ = UIImage(named: "icon-1024") {
                                 Image("icon-1024")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 54, height: 54)
                                    .cornerRadius(12)
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            } else {
                                 Image(systemName: "app.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 54, height: 54)
                                    .foregroundColor(Color(hex: "6C6BFF"))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Ziora")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                                
                                Text(userStatusText)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, safeArea.top + 130)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 30)

                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 24) {
                                
                                // --- Premium Card ---
                                Button(action: {
                                    isPresented = false
                                    onOpenAdFreePlan()
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(storeManager.hasPurchasedAdFree ? "Premium Plan" : "Go Ad-Free")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.white)
                                            
                                            Text(storeManager.hasPurchasedAdFree ? "Active" : "Remove ads & support us")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.white.opacity(0.9))
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
                                    SectionHeader(text: "SETTINGS")
                                    MenuRowItem(icon: "bell.fill", title: "Notifications", action: onOpenNotificationSettings)
                                    MenuRowItem(icon: "globe", title: "Language", action: onOpenLanguage)
                                }
                                .padding(.horizontal, 24)
                                
                                // --- Support ---
                                VStack(spacing: 8) {
                                    SectionHeader(text: "SUPPORT")
                                    MenuRowItem(icon: "envelope.fill", title: "Contact Us", action: onOpenContact)
                                    MenuRowItem(icon: "doc.text.fill", title: "Terms & Privacy", action: onOpenLegal)
                                }
                                .padding(.horizontal, 24)
                                
                                // --- Account ---
                                VStack(spacing: 8) {
                                    SectionHeader(text: "ACCOUNT")
                                    MenuRowItem(icon: "rectangle.portrait.and.arrow.right", title: "Sign Out", color: .gray, action: onSignOut)
                                    MenuRowItem(icon: "trash.fill", title: "Delete Account", color: .red, action: onDeleteAccount)
                                }
                                .padding(.horizontal, 24)
                            }
                            .padding(.bottom, 40)
                        }
                        
                        Spacer()
                        
                        // --- Footer ---
                        Text("Version 1.0.0")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, safeArea.bottom + 10)
                    }
                }
                .frame(width: menuWidth)
                .mask(RoundedCorner(radius: 30, corners: [.topRight, .bottomRight]))
                .shadow(color: Color.black.opacity(0.15), radius: 20, x: 5, y: 0)
                
                // 左スワイプで閉じるジェスチャー
                .gesture(
                    DragGesture().onEnded { value in
                        if value.translation.width < -50 {
                            withAnimation(.easeIn(duration: 0.22)) { isPresented = false }
                        }
                    }
                )
            }
        }
    }
    
    private var userStatusText: String {
        if !authManager.isSignedIn { return "Not Signed In" }
        if Auth.auth().currentUser?.isAnonymous ?? true { return "Guest User" }
        return "Signed In"
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
                ZStack {
                    Circle()
                        .fill(Color(.secondarySystemBackground))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(color)
                }
                
                // ★修正: 1行制限と自動縮小を追加して改行を防ぐ
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1) // 1行に制限
                    .minimumScaleFactor(0.8) // 幅が足りない場合は80%まで文字を小さくする
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(uiColor: .tertiaryLabel))
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
