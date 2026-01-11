import Foundation
import StoreKit
import Combine

class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()
    @Published var isPremium: Bool = UserDefaults.standard.bool(forKey: "isPremium") {
        didSet { UserDefaults.standard.set(isPremium, forKey: "isPremium") }
    }
    @Published var products: [Product] = []
    private let productID = "com.studio.In.Rain.premium"
    private var updates: Task<Void, Never>? = nil
    
    init() {
        updates = Task.detached { [weak self] in
            for await result in StoreKit.Transaction.updates {
                if let transaction = try? self?.checkVerified(result) {
                    await self?.process(transaction: transaction)
                    await transaction.finish()
                }
            }
        }
        Task { await requestProducts(); await updatePurchasedStatus() }
    }
    deinit { updates?.cancel() }
    @MainActor func requestProducts() async { do { products = try await Product.products(for: [productID]) } catch {} }
    @MainActor func updatePurchasedStatus() async {
        var hasPremium = false
        for await result in StoreKit.Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result), transaction.productID == productID { hasPremium = true }
        }
        self.setPremiumStatus(hasPremium)
    }
    @MainActor func purchasePremium() {
        guard let product = products.first else { return }
        Task {
            if let result = try? await product.purchase(), case .success(let verification) = result {
                let transaction = try checkVerified(verification)
                process(transaction: transaction)
                await transaction.finish()
            }
        }
    }
    @MainActor func restorePurchases() async throws { try? await AppStore.sync(); await updatePurchasedStatus() }
    @MainActor private func process(transaction: StoreKit.Transaction) {
        if transaction.productID == productID { setPremiumStatus(transaction.revocationDate == nil) }
    }
    private func setPremiumStatus(_ status: Bool) { DispatchQueue.main.async { self.isPremium = status } }
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result { case .unverified: throw URLError(.badServerResponse); case .verified(let safe): return safe }
    }
}
