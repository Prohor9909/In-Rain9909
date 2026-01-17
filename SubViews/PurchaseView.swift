import SwiftUI
import StoreKit

struct PurchaseView: View {
    @ObservedObject var audioManager: AudioEngineManager
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var purchaseManager = PurchaseManager.shared
    @State private var isPulsing = false

    private let features = [
        ("infinity", "Unlimited Playback", "No time limits or interruptions"),
        ("speaker.wave.3.fill", "Background Audio", "Play while using other apps"),
        ("slider.horizontal.3", "Mixer Mode", "Blend with other audio sources"),
        ("wind", "Dynamic Ambience", "Smart, changing atmosphere"),
        ("sparkles", "Visual Effects", "Immersive rain and fire visuals")
    ]
    
    var body: some View {
        ZStack {
            // Background Image - Shifted up slightly as requested
            Color.clear
                .background {
                    Image("background")
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .blur(radius: 20)
                        .offset(y: -100) // Moved background up
                }

            // Rain Effect
            RainEffectView(
                intensity: 0.1,
                windAngle: -15,
                isEnabled: audioManager.isParticleEffectsEnabled,
                isPlaying: audioManager.isPlaying
            )
            .edgesIgnoringSafeArea(.all)
            .allowsHitTesting(false)
            .padding(-200)
            
            VStack(spacing: 0) {
                // Header & Logo
                VStack(spacing: 15) {
                    Text(purchaseManager.isPremium ? "Premium Unlocked" : "Unlock Premium")
                        .font(.title).bold()
                        .shadow(radius: 5)
                    
                    Text(purchaseManager.isPremium ? "You have the full version" : "For Uninterrupted Playback")
                        .font(.subheadline)
                        .opacity(0.8)
                        .shadow(radius: 5)

                    Image("InRain")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .scaleEffect(isPulsing ? 1.05 : 1)
                        .cornerRadius(25)
                        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 25))
                        .shadow(color: .white.opacity(isPulsing ? 0.3 : 0.0), radius: isPulsing ? 20 : 0)
                        .animation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true), value: isPulsing)
                        .onAppear { isPulsing = true }
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Features List
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(features, id: \.1) { icon, title, subtitle in
                        HStack(spacing: 15) {
                            Image(systemName: icon)
                                .font(.title3)
                                .frame(width: 30, height: 30)
                                .foregroundStyle(.white)
                                .glassEffect(.clear)
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title)
                                    .font(.headline)
                                    .bold()
                                Text(subtitle)
                                    .font(.caption)
                                    .opacity(0.7)
                            }
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 20)
                .background(.ultraThinMaterial.opacity(0.3), in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Buttons at the very bottom
                VStack(spacing: 12) {
                    if purchaseManager.isPremium {
                        Button(action: { dismiss() }) {
                            Text("\(Image(systemName: "checkmark.circle.fill"))   Return to App")
                                .bold()
                                .frame(width: 300, height: 45)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.glass)
                        .shadow(color: .white.opacity(0.2), radius: 10)
                    } else {
                        Button(action: { purchaseManager.purchasePremium() }) {
                            Text("\(Image(systemName: "balloon.2"))   Full Version \(purchaseManager.products.first?.displayPrice ?? "$0.99")")
                                .bold()
                                .frame(width: 300, height: 45)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.glass)
                        .shadow(color: .white.opacity(0.2), radius: 10)
                        
                        Button(action: { Task { try? await purchaseManager.restorePurchases() } }) {
                            Text("\(Image(systemName: "icloud.and.arrow.down"))   Restore Purchase")
                                .bold()
                                .frame(width: 300, height: 45)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.glass)
                        .shadow(color: .white.opacity(0.2), radius: 10)
                        
                        Button(action: { dismiss() }) {
                            Text("\(Image(systemName: "hourglass"))   Continue Trial")
                                .bold()
                                .foregroundStyle(.black)
                                .frame(width: 250, height: 40)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.glassProminent)
                        .shadow(color: .white.opacity(0.2), radius: 10)
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .statusBarHidden(true)
        .presentationBackground(.clear)
        .onChange(of: purchaseManager.isPremium) { _, newValue in
            if newValue {
                audioManager.play()
            }
        }
    }
}
