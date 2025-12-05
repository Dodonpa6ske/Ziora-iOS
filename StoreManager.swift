import Foundation
import StoreKit
import Combine

// ★ 設定ファイルの Product ID と一致させる
public let productIdAdFree = "com.akira.ziora.adfree"

@MainActor
class StoreManager: ObservableObject {
    
    static let shared = StoreManager()
    
    @Published var products: [Product] = []
    @Published var hasPurchasedAdFree: Bool = false
    
    private var updateListenerTask: Task<Void, Error>? = nil

    private init() {
        // 起動時にリスナー開始 & 購入状態チェック
        updateListenerTask = listenForTransactions()
        Task { await updatePurchasedStatus() }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // 商品情報の取得
    func loadProducts() async {
        do {
            let products = try await Product.products(for: [productIdAdFree])
            self.products = products
        } catch {
            print("Failed to load products: \(error)")
        }
    }
    
    // 購入処理
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            guard let transaction = try? verification.payloadValue else { return }
            await transaction.finish()
            await updatePurchasedStatus()
            
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }
    
    // 復元（Restore）
    func restorePurchases() async {
        try? await AppStore.sync()
        await updatePurchasedStatus()
    }
    
    // 購入状態の更新
    private func updatePurchasedStatus() async {
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? result.payloadValue else { continue }
            
            if transaction.productID == productIdAdFree {
                if transaction.revocationDate == nil {
                    self.hasPurchasedAdFree = true
                    return
                }
            }
        }
        self.hasPurchasedAdFree = false
    }
    
    // トランザクション監視
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                guard let transaction = try? result.payloadValue else { continue }
                await transaction.finish()
                await self.updatePurchasedStatus()
            }
        }
    }
}
