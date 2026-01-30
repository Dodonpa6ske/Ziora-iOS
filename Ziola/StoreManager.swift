import Foundation
import StoreKit
import Combine

// ★ 修正: サブスクリプション用の新しいProduct IDに変更
public let productIdAdFree = "com.akira.ziora.adfree.monthly"

@MainActor
class StoreManager: ObservableObject {
    
    static let shared = StoreManager()
    
    @Published var products: [Product] = []
    @Published var hasPurchasedAdFree: Bool = false
    @Published var errorMessage: String? = nil
    
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
        // エラーリセット
        self.errorMessage = nil
        do {
            let products = try await Product.products(for: [productIdAdFree])
            if products.isEmpty {
                self.errorMessage = "No products found. Please check App Store Connect configuration for ID: \(productIdAdFree)"
            }
            self.products = products
        } catch {
            self.errorMessage = "Failed to load products: \(error.localizedDescription)"
            print("Failed to load products: \(error)")
        }
    }
    
    // 購入処理
    func purchase(_ product: Product) async {
        self.errorMessage = nil
        do {
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
        } catch {
            self.errorMessage = "Purchase failed: \(error.localizedDescription)"
            print("Purchase failed: \(error)")
        }
    }
    
    // 復元（Restore）
    func restorePurchases() async {
        self.errorMessage = nil
        do {
            try await AppStore.sync()
            await updatePurchasedStatus()
        } catch {
            self.errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }
    
    // 購入状態の更新
    private func updatePurchasedStatus() async {
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? result.payloadValue else { continue }
            
            // Product IDの一致を確認
            if transaction.productID == productIdAdFree {
                // 有効期限のチェック（サブスクリプションの場合）
                if transaction.revocationDate != nil {
                    // 取り消し済み
                    continue
                }
                // ※ StoreKit 2の currentEntitlements は自動的に有効なものだけを返すため、
                // expirationDate のチェックは厳密には不要ですが、有効期限内であることを確認済みとして扱います。
                self.hasPurchasedAdFree = true
                return
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
