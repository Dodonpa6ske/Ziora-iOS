import SwiftUI
import StoreKit

struct AdFreePlanView: View {
    @EnvironmentObject var storeManager: StoreManager
    @Binding var isPresented: Bool

    // カードの表示アニメーション用
    @State private var showCard = false
    @State private var isTimeout = false

    var body: some View {
        ZStack {
            // 1. 背景（フェードイン）
            Color.black.opacity(0.4) // 少し暗くして視認性を上げる（好みで透明度調整可）
                .ignoresSafeArea()
                .onTapGesture {
                    close()
                }
                .transition(.opacity)
            
            // 2. カード本体（下からスライドイン）
            if showCard {
                VStack(spacing: 0) {
                    
                    // --- ヘッダーアイコン ---
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 72, height: 72) // サイズ縮小 (80 -> 72)
                        
                        Image(systemName: "sparkles")
                            .font(.system(size: 32)) // サイズ縮小 (36 -> 32)
                            .foregroundColor(Color(hex: "6C6BFF"))
                    }
                    .padding(.top, 32) // 余白縮小 (40 -> 32)
                    .padding(.bottom, 12) // 余白縮小 (16 -> 12)
                    
                    if let product = storeManager.products.first(where: { $0.id == productIdAdFree }) {
                        
                        // --- 価格などの情報 ---
                        VStack(spacing: 0) {
                            // 言語設定に基づいた価格表示 (StoreKitの価格とは見た目だけ分離)
                            let currentLang = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en"
                            let displayPrice: String = {
                                switch currentLang {
                                case "ja": return "300円"
                                case "ko": return "₩3,300.00"
                                case "fr", "es": return "€1.99"
                                default: return "$1.99"
                                }
                            }()
                            
                            Text(displayPrice)
                                .font(.system(size: 48, weight: .bold)) // フォント縮小 (56 -> 48)
                                .foregroundColor(.black)
                                .padding(.bottom, 4)
                            
                            Text("AdFree_MonthlySubscription".localized())
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.bottom, 24) // 余白大幅縮小 (40 -> 24)
                            
                            // 明細リスト
                            VStack(spacing: 16) { // 間隔縮小 (20 -> 16)
                                DetailRow(label: "AdFree_PlanLabel".localized(), value: "Ziora Premium")
                                DetailRow(label: "AdFree_RenewsLabel".localized(), value: "AdFree_RenewsValue".localized())
                                DetailRow(label: "AdFree_ExperienceLabel".localized(), value: "AdFree_ExperienceValue".localized())
                                Divider()
                                DetailRow(label: "AdFree_TotalPayLabel".localized(), value: displayPrice, isBold: true)
                            }
                            .padding(.horizontal, 24) // 横余白縮小 (32 -> 24)
                            .padding(.bottom, 32) // 余白縮小 (40 -> 32)
                            
                            // ボタンエリア
                            if storeManager.hasPurchasedAdFree {
                                VStack(spacing: 12) {
                                    Text("AdFree_CurrentPlanActive".localized())
                                        .font(.headline)
                                        .foregroundColor(.green)
                                    
                                    Button(action: { close() }) {
                                        Text("AdFree_Close".localized())
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundColor(.black)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 50) // 高さ縮小 (56 -> 50)
                                            .background(Color(.systemGray5))
                                            .cornerRadius(25)
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 24)
                            } else {
                                Button {
                                    Task { await storeManager.purchase(product) }
                                } label: {
                                    Text("AdFree_Subscribe".localized())
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50) // 高さ縮小 (56 -> 50)
                                        .background(Color.black)
                                        .cornerRadius(25)
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 16)
                                
                                HStack(spacing: 16) {
                                    Button("AdFree_Restore".localized()) {
                                        Task { await storeManager.restorePurchases() }
                                    }
                                    Divider().frame(height: 12)
                                    Button("AdFree_RedeemCode".localized()) {
                                        SKPaymentQueue.default().presentCodeRedemptionSheet()
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 12)

                                // Error Message Display (Purchase/Restore errors)
                                if let errorMessage = storeManager.errorMessage {
                                    Text(errorMessage)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 24)
                                        .padding(.bottom, 12)
                                }
                                
                                Spacer().frame(height: 12)
                            }
                            
                            // Terms and Privacy
                            VStack(spacing: 4) {
                                HStack(spacing: 4) {
                                    Link("Terms of Service".localized(), destination: URL(string: "https://www.notion.so/Ziora-Terms-of-Service-2c0aacfc1c6f801f934cdafe1e0bf063?source=copy_link")!)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .underline()
                                    
                                    Text("and".localized())
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Link("Privacy Policy".localized(), destination: URL(string: "https://www.notion.so/Ziora-Privacy-Policy-2c0aacfc1c6f805e99a5e847005b669e?source=copy_link")!)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .underline()
                                }
                            }
                            .padding(.bottom, 24)
                        }
                    } else {
                        // ロード中 (高さを固定してガクつき防止)
                        VStack {
                            if let errorMessage = storeManager.errorMessage {
                                // Explicit Error from StoreManager
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 30))
                                    .foregroundColor(.red)
                                    .padding(.bottom, 8)
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                Button("Retry") {
                                    Task { await storeManager.loadProducts() }
                                }
                                .font(.caption)
                                .padding(.top, 4)
                            } else if isTimeout {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 30))
                                    .foregroundColor(.orange)
                                    .padding(.bottom, 8)
                                Text("Failed to load products (Timeout).")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Button("Retry") {
                                    isTimeout = false
                                    Task { await storeManager.loadProducts() }
                                    // Reset timer
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                                        if !storeManager.products.contains(where: { $0.id == productIdAdFree }) {
                                            isTimeout = true
                                        }
                                    }
                                }
                                .font(.caption)
                                .padding(.top, 4)
                            } else {
                                ProgressView()
                                    .scaleEffect(1.2)
                                    .padding(30)
                                Text("AdFree_Loading".localized())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.bottom, 30)
                            }
                        }
                        .frame(height: 200)
                    }
                }
                .background(Color.white)
                .cornerRadius(32)
                .padding(.horizontal, 24) // 画面端との余白を少し広げる
                .shadow(color: .black.opacity(0.2), radius: 24, x: 0, y: 12)
                // ★重要: カード全体を合成してからアニメーションさせる（文字先走り防止）
                .compositingGroup()
                // ★アニメーション定義: 下からスライドイン
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(1)
            }
        }
                .onAppear {
            // 背景が表示された直後にカードをスライドインさせる
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                showCard = true
            }
            
            // ★追加: 画面表示時にもロードを試みる（HomeViewでのロードが失敗/未完了の場合に備える）
            Task {
                await storeManager.loadProducts()
            }
            
            // 5秒経っても対象の商品が取れなかったらタイムアウト表示
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                // 商品リストが空、または指定の商品IDが含まれていない場合にタイムアウトとする
                if !storeManager.products.contains(where: { $0.id == productIdAdFree }) {
                    isTimeout = true
                }
            }
        }
    }
    
    private func close() {
        // 閉じるアニメーション
        withAnimation(.easeIn(duration: 0.2)) {
            showCard = false
        }
        // カードが消えた後に本体を非表示にする
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation {
                isPresented = false
            }
        }
    }
}

// MARK: - Helper Components

struct DetailRow: View {
    let label: String
    let value: String
    var isBold: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .font(.system(size: 15)) // フォント微調整
            
            Spacer()
            
            Text(value)
                .foregroundColor(.primary)
                .font(.system(size: 15, weight: isBold ? .bold : .regular))
        }
    }
}
