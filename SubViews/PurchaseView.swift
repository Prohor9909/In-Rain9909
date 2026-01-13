import SwiftUI
import StoreKit

struct PurchaseView: View {
    @ObservedObject var audioManager: AudioEngineManager
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var purchaseManager = PurchaseManager.shared
    
    var body: some View {
        VStack (spacing: 10) {
            
            Spacer()
                        
            Text("Upgrade to Premium")
                .font(.largeTitle)
            
            Text("Enjoy uninterrupted relaxation")
                .font(.title3)
            
            Spacer()
            
            Image("InRain")
                .resizable()
                .scaledToFill()
                .frame(width: 150, height: 150)
                .cornerRadius(20)
                .padding(5)
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
            
            Spacer()
            
            Button(action: { purchaseManager.purchasePremium() }) {
                Text("Purchase Full Version \(purchaseManager.products.first?.displayPrice ?? "$2.99")")
                    .frame(width: 300, height: 40)
            }
            .buttonStyle(.glass)
            
            Button(action: { dismiss(); audioManager.play() }) {
                Text("Continue Trial Mode")
                    .frame(width: 300, height: 40)
            }
            .buttonStyle(.glass)
            
            Button(action: { Task { try? await purchaseManager.restorePurchases() } }) {
                Text("Restore Purchase")
                    .frame(width: 300, height: 40)
            }
            .buttonStyle(.glass)
        }
        .statusBarHidden(true)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .presentationBackground(.clear)
        .onChange(of: purchaseManager.isPremium) { _, newValue in
            if newValue {
                dismiss()
                audioManager.play()
            }
        }
    }
}
