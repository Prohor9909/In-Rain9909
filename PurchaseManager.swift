import Foundation
import StoreKit
import Combine
import SwiftUI

class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()
    
    @Published var isPremium: Bool = false
    
    @Published private var hasRealPurchase: Bool = UserDefaults.standard.bool(forKey: "hasRealPurchase") {
        didSet {
            UserDefaults.standard.set(hasRealPurchase, forKey: "hasRealPurchase")
            updateFinalStatus()
        }
    }
    
    @AppStorage("isDevUnlocked") private var isDevUnlocked: Bool = false {
        didSet {
            updateFinalStatus()
        }
    }
    
    @Published var products: [Product] = []
    private let productID = "com.studio.In.Rain.premium"
    private var updates: Task<Void, Never>? = nil
    
    init() {
        updateFinalStatus()
        
        updates = Task.detached { [weak self] in
            for await result in StoreKit.Transaction.updates {
                if let transaction = try? self?.checkVerified(result) {
                    await self?.process(transaction: transaction)
                    await transaction.finish()
                }
            }
        }
        Task {
            await requestProducts()
            await updatePurchasedStatus()
        }
    }
    
    deinit { updates?.cancel() }
    
    private func updateFinalStatus() {
        DispatchQueue.main.async {
            if self.hasRealPurchase {
                self.isPremium = true
            } else {
                self.isPremium = self.isDevUnlocked
            }
        }
    }
    
    func toggleDevUnlock() {
        guard !hasRealPurchase else { return }
        isDevUnlocked.toggle()
    }
    
    @MainActor func requestProducts() async {
        do {
            products = try await Product.products(for: [productID])
        } catch {}
    }
    
    @MainActor func updatePurchasedStatus() async {
        var foundRealPurchase = false
        for await result in StoreKit.Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result), transaction.productID == productID {
                foundRealPurchase = true
            }
        }
        self.hasRealPurchase = foundRealPurchase
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
    
    @MainActor func restorePurchases() async throws {
        try? await AppStore.sync()
        await updatePurchasedStatus()
    }
    
    @MainActor private func process(transaction: StoreKit.Transaction) {
        if transaction.productID == productID {
            self.hasRealPurchase = (transaction.revocationDate == nil)
        }
    }
    
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw URLError(.badServerResponse)
        case .verified(let safe): return safe
        }
    }
}
