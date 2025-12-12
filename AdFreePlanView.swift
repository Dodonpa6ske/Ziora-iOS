import SwiftUI
import StoreKit

struct AdFreePlanView: View {
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.zioraLightBackground.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // ヘッダー
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "6C6BFF"))
                        .padding(.top, 40)
                    
                    Text("Go Ad-Free")
                        .font(.system(size: 28, weight: .bold))
                    
                    Text("Support development and enjoy Ziora without interruptions.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 32)
                }
                
                Spacer().frame(height: 20)
                
                // 購入状態に応じた表示
                if storeManager.hasPurchasedAdFree {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                        Text("You are on the Ad-Free plan!")
                            .font(.headline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(20)
                    .padding(.horizontal, 24)
                    
                } else {
                    // 購入ボタン
                    if let product = storeManager.products.first(where: { $0.id == productIdAdFree }) {
                        VStack(spacing: 16) {
                            Button {
                                Task { try? await storeManager.purchase(product) }
                            } label: {
                                HStack {
                                    Text("Subscribe")
                                    Spacer()
                                    Text(product.displayPrice + " / month")
                                }
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .padding()
                                .frame(height: 60)
                                .background(Color(hex: "6C6BFF"))
                                .cornerRadius(16)
                            }
                            
                            // 復元 & コード入力
                            HStack(spacing: 20) {
                                Button("Restore Purchases") {
                                    Task { await storeManager.restorePurchases() }
                                }
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                
                                Divider().frame(height: 12)
                                
                                // ★追加: プロモーションコード入力（Apple標準シート）
                                Button("Redeem Code") {
                                    SKPaymentQueue.default().presentCodeRedemptionSheet()
                                }
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 24)
                        
                    } else {
                        ProgressView("Loading products...")
                    }
                }
                
                Spacer()
                
                Button("Close") { dismiss() }
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            Task { await storeManager.loadProducts() }
        }
    }
}
