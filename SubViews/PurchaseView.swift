import SwiftUI
import StoreKit

struct PurchaseView: View {
    @ObservedObject var audioManager: AudioEngineManager
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var purchaseManager = PurchaseManager.shared
    
    var body: some View {
        ZStack{
            Color.clear
                .background {
                    Image("background")
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .blur(radius: 20)
                }

            RainEffectView(
                intensity: 0.1,
                windAngle: -15,
                isEnabled: audioManager.isParticleEffectsEnabled,
                isPlaying: audioManager.isPlaying
            )
            .edgesIgnoringSafeArea(.all)
            .allowsHitTesting(false)
            .padding(-200)
            
            VStack (spacing: 0) {
                                
                Text("Unlock Premium")
                    .font(.title).bold()
                    .padding(.top, 30)
                
                Text("For Uninterrupted Playback")
                
                Spacer()
                
                Image("InRain")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 150, height: 150)
                    .cornerRadius(30)
                    .padding(5)
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 30))
                    .shadow(color: .white.opacity(0.3), radius: 30)
                    .shadow(color: .white.opacity(0.3), radius: 30)
                
                Spacer()
                
                Button(action: { purchaseManager.purchasePremium() }) {
                    Text("\(Image(systemName: "balloon.2"))   Full Version \(purchaseManager.products.first?.displayPrice ?? "$0.99")")
                        .bold()
                        .frame(width: 200, height: 40)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.glass)
                .shadow(color: .white.opacity(0.3), radius: 30)
                .shadow(color: .white.opacity(0.3), radius: 30)
                .padding(.bottom, 10)
                
                Button(action: { Task { try? await purchaseManager.restorePurchases() } }) {
                    Text("\(Image(systemName: "icloud.and.arrow.down"))   Restore Purchase")
                        .bold()
                        .frame(width: 200, height: 40)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.glass)
                .shadow(color: .white.opacity(0.3), radius: 30)
                .shadow(color: .white.opacity(0.3), radius: 30)
                .padding(.bottom, 10)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Text("\(Image(systemName: "hourglass"))   Continue Trial")
                        .bold()
                        .foregroundStyle(.black)
                        .frame(width: 160, height: 40)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.glassProminent)
                .shadow(color: .white.opacity(0.3), radius: 30)
                .shadow(color: .white.opacity(0.3), radius: 30)
                .padding(.bottom, 10)
            }
        }
        .statusBarHidden(true)
        .presentationBackground(.clear)
        .onChange(of: purchaseManager.isPremium) { _, newValue in
            if newValue {
                dismiss()
                audioManager.play()
            }
        }
    }
}
