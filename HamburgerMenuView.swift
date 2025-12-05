import SwiftUI

struct HamburgerMenuView: View {
    @Binding var isPresented: Bool
    
    // ★ 追加: 課金状態を監視して表示を変えるため
    @EnvironmentObject var storeManager: StoreManager

    let onOpenSentList: () -> Void
    let onOpenLikedList: () -> Void
    let onOpenAdFreePlan: () -> Void
    let onOpenNotificationSettings: () -> Void
    let onOpenLegal: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            // 閉じるボタン用（10pt 下げている）
            let closeTopPadding = max(75, safeTop + 35) + 10
            // リストの開始位置
            let listTopPadding  = max(120, safeTop + 80)

            ZStack(alignment: .topLeading) {

                // 白い角丸 28px のパネル
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.12),
                            radius: 18, x: 0, y: 8)
                    .frame(width: proxy.size.width,
                           height: proxy.size.height)
                    .ignoresSafeArea(edges: .vertical)

                // メニュー項目
                VStack(alignment: .leading, spacing: 24) {
                    Spacer().frame(height: listTopPadding)

                    VStack(alignment: .leading, spacing: 18) {
                        MenuRowButton(
                            title: "Sent photos",
                            subtitle: "Photos you’ve uploaded",
                            systemIcon: "paperplane.fill",
                            action: {
                                isPresented = false
                                onOpenSentList()
                            }
                        )

                        MenuRowButton(
                            title: "Liked photos",
                            subtitle: "Photos you’ve liked",
                            systemIcon: "heart.fill",
                            action: {
                                isPresented = false
                                onOpenLikedList()
                            }
                        )

                        // ★ 変更: 購入状態に応じて表示を切り替え
                        MenuRowButton(
                            title: "Ad-free plan",
                            // 購入済みなら "Active"、未購入なら "Remove all ads"
                            subtitle: storeManager.hasPurchasedAdFree ? "Active" : "Remove all ads",
                            // 購入済みならチェックマーク、未購入ならキラキラ
                            systemIcon: storeManager.hasPurchasedAdFree ? "checkmark.circle.fill" : "sparkles",
                            // 購入済みなら緑色、未購入ならデフォルト（紫）
                            iconColor: storeManager.hasPurchasedAdFree ? .green : nil,
                            action: {
                                isPresented = false
                                onOpenAdFreePlan()
                            }
                        )

                        MenuRowButton(
                            title: "Notifications",
                            subtitle: "Notification settings",
                            systemIcon: "bell.fill",
                            action: {
                                isPresented = false
                                onOpenNotificationSettings()
                            }
                        )

                        MenuRowButton(
                            title: "Legal",
                            subtitle: "Terms & Privacy",
                            systemIcon: "doc.text.fill",
                            action: {
                                isPresented = false
                                onOpenLegal()
                            }
                        )
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }

                // 閉じるボタン
                Button {
                    withAnimation(.easeIn(duration: 0.22)) {
                        isPresented = false
                    }
                } label: {
                    // 線幅 2pt の X マーク
                    ZStack {
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: 30, height: 2)   // ← 線の太さ 2pt
                            .rotationEffect(.degrees(45))

                        Rectangle()
                            .fill(Color.black)
                            .frame(width: 30, height: 2)   // ← 線の太さ 2pt
                            .rotationEffect(.degrees(-45))
                    }
                    .frame(width: 44, height: 44)          // タップしやすい当たり判定
                    .contentShape(Rectangle())
                }
                .padding(.top, closeTopPadding + 25)        // ← 5pt 下げる
                .padding(.leading, 25)
                .buttonStyle(.plain)
            }
            // 左スワイプでメニューを閉じる
            .gesture(
                DragGesture()
                    .onEnded { value in
                        let horizontal = value.translation.width
                        let vertical = value.translation.height

                        if abs(horizontal) > abs(vertical),
                           horizontal < -60 {
                            withAnimation(.easeIn(duration: 0.22)) {
                                isPresented = false
                            }
                        }
                    }
            )
        }
    }
}

// MARK: - 1 行ぶんのメニューボタン

struct MenuRowButton: View {
    let title: String
    let subtitle: String
    let systemIcon: String
    // ★ 追加: アイコンの色を外部から指定できるように変更（デフォルトはnil）
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
                        // ★ 変更: iconColorが指定されていればそれを使い、なければデフォルトの紫を使う
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
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }
}
