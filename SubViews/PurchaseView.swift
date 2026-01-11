import SwiftUI
import StoreKit

struct PurchaseView: View {
    @ObservedObject var audioManager: AudioEngineManager
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var purchaseManager = PurchaseManager.shared
    
    var body: some View {
        RadialGradient(gradient: Gradient(colors: [Color.purple.opacity(0.2), Color.black]), center: .center, startRadius: 5, endRadius: 400).ignoresSafeArea()
        VStack(spacing: 30) {
            Spacer()
            ZStack {
                Circle().fill(Color.orange.opacity(0.1)).frame(width: 150, height: 150)
                Image(systemName: "crown.fill").font(.system(size: 70)).foregroundColor(.orange).shadow(color: .orange.opacity(0.5), radius: 10, x: 0, y: 0)
            }.padding(.bottom, 20)
            Text("Upgrade to Premium").font(.system(size: 32, weight: .bold)).foregroundColor(.white)
            Text("Enjoy uninterrupted relaxation.").font(.title3).foregroundColor(.white.opacity(0.7)).multilineTextAlignment(.center).padding(.horizontal)
            Spacer()
            VStack(spacing: 16) {
                Button(action: { purchaseManager.purchasePremium() }) {
                    HStack {
                        Text("Purchase Full Version").fontWeight(.bold)
                        Spacer()
                        Text(purchaseManager.products.first?.displayPrice ?? "$0.99")
                    }
                    .foregroundColor(.white).padding().frame(height: 56)
                    .background(LinearGradient(colors: [Color.orange, Color.red], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(12)
                }
                Button(action: { dismiss(); audioManager.play() }) {
                    Text("Keep using free version").font(.subheadline).foregroundColor(.white.opacity(0.6)).padding()
                }
                Button("Restore Purchases") {
                    Task { try? await purchaseManager.restorePurchases() }
                }.font(.subheadline).foregroundColor(.white.opacity(0.6))
            }.padding(.horizontal, 30).padding(.bottom, 50)
        }
        .transition(.opacity)
        .onChange(of: purchaseManager.isPremium) { _, newValue in
            if newValue { dismiss(); audioManager.play() }
        }
    }
}
