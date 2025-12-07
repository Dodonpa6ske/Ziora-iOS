import SwiftUI

struct HamburgerMenuView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var storeManager: StoreManager

    // メニュー項目に対応するアクション
    let onOpenAdFreePlan: () -> Void
    let onOpenNotificationSettings: () -> Void
    let onOpenLegal: () -> Void
    let onOpenContact: () -> Void
    let onSignOut: () -> Void
    let onDeleteAccount: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            
            // 閉じるボタンの位置（基準）
            let closeTopPadding = max(75, safeTop + 35) + 10
            
            // ★ 変更: リストの開始位置を大幅に下げて余白（ホワイトスペース）を作る
            // 旧: max(120, safeTop + 80) -> 新: max(220, safeTop + 180)
            let listTopPadding  = max(220, safeTop + 180)

            ZStack(alignment: .topLeading) {
                // 背景パネル（白・角丸・影付き）
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 8)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .ignoresSafeArea(edges: .vertical)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        // 上部の余白スペース
                        Spacer().frame(height: listTopPadding)

                        VStack(alignment: .leading, spacing: 18) {
                            
                            // MARK: - Premium Section
                            MenuRowButton(
                                title: "Ad-free plan",
                                subtitle: storeManager.hasPurchasedAdFree ? "Active" : "Remove all ads",
                                systemIcon: storeManager.hasPurchasedAdFree ? "checkmark.circle.fill" : "sparkles",
                                iconColor: storeManager.hasPurchasedAdFree ? .green : .orange,
                                action: {
                                    isPresented = false
                                    onOpenAdFreePlan()
                                }
                            )

                            Divider()

                            // MARK: - Support Section
                            Group {
                                Text("Support & Info")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 8)
                                    .padding(.bottom, -8)
                                
                                MenuRowButton(
                                    title: "Contact Us",
                                    subtitle: "Help & Feedback",
                                    systemIcon: "envelope.fill",
                                    action: {
                                        isPresented = false
                                        onOpenContact()
                                    }
                                )

                                MenuRowButton(
                                    title: "Terms & Privacy",
                                    subtitle: "Legal information",
                                    systemIcon: "doc.text.fill",
                                    action: {
                                        isPresented = false
                                        onOpenLegal()
                                    }
                                )
                                
                                MenuRowButton(
                                    title: "Notifications",
                                    subtitle: "System settings",
                                    systemIcon: "bell.fill",
                                    action: {
                                        isPresented = false
                                        onOpenNotificationSettings()
                                    }
                                )
                            }
                            
                            Divider()
                            
                            // MARK: - Account Section
                            Group {
                                MenuRowButton(
                                    title: "Sign Out",
                                    subtitle: "Log out",
                                    systemIcon: "rectangle.portrait.and.arrow.right",
                                    iconColor: .gray,
                                    action: {
                                        isPresented = false
                                        onSignOut()
                                    }
                                )
                                
                                MenuRowButton(
                                    title: "Delete Account",
                                    subtitle: "Permanently delete data",
                                    systemIcon: "trash.fill",
                                    iconColor: .red,
                                    action: {
                                        isPresented = false
                                        onDeleteAccount()
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer().frame(height: 100)
                    }
                }

                // 閉じるボタン（右上の×）
                Button {
                    withAnimation(.easeIn(duration: 0.22)) { isPresented = false }
                } label: {
                    ZStack {
                        Rectangle().fill(Color.black).frame(width: 30, height: 2).rotationEffect(.degrees(45))
                        Rectangle().fill(Color.black).frame(width: 30, height: 2).rotationEffect(.degrees(-45))
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .padding(.top, closeTopPadding + 25)
                .padding(.leading, 25)
                .buttonStyle(.plain)
            }
            // 左スワイプで閉じるジェスチャー
            .gesture(
                DragGesture().onEnded { value in
                    if abs(value.translation.width) > abs(value.translation.height), value.translation.width < -60 {
                        withAnimation(.easeIn(duration: 0.22)) { isPresented = false }
                    }
                }
            )
        }
    }
}

// リストの行デザイン（変更なし）
struct MenuRowButton: View {
    let title: String
    let subtitle: String
    let systemIcon: String
    var iconColor: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.zioraLightBackground)
                    Image(systemName: systemIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(iconColor ?? Color(hex: "6C6BFF"))
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }
}
