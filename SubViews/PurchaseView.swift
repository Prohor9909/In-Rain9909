import SwiftUI
import StoreKit

struct PurchaseView: View {
    @ObservedObject var audioManager: AudioEngineManager
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var purchaseManager = PurchaseManager.shared
    @State private var isPulsing = false
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    private let features = [
        ("slider.vertical.3", "Atmospheric Canvas", "Rain, Fire, Splash, Thunder, Rumble"),
        ("sparkles", "Immersive Visuals", "Vivid real-time atmospheric effects"),
        ("wind", "Ambient Drift", "An infinite, ever-evolving atmosphere"),
        ("music.quarternote.3", "Mixer Mode", "Blend with music from other apps"),
        ("apple.meditate", "Sound Profiles", "Pin your fine-tuned favorites"),
        ("hourglass", "Limitless Playback", "Remove trial restrictions"),
        ("timer", "Crossfade Timer", "Clock your ambient lifespan"),
        ("moon", "Background Audio", "Play while your device sleeps"),
        ("infinity", "Lifetime Unlock", "Not a subscription, forever yours!")
    ]
    
    var body: some View {
        ZStack {
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
            
            VStack(spacing: 10) {
                
                VStack(spacing: 0) {
                    Text(purchaseManager.isPremium ? "In Rain" : "In Rain v\(version)")
                        .font(.title).bold()
                        .shadow(radius: 5)
                    
                    Text(purchaseManager.isPremium ? "Create your own Soundscape" : "Exclusive 75% Launch Discount")
                        .font(.subheadline)
                        .opacity(0.8)
                        .shadow(radius: 5)
                }
                
                Spacer()
                
                Image("InRain")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 180, height: 180)
                    .scaleEffect(isPulsing ? 1.25 : 1)
                    .cornerRadius(25)
                    .padding(3)
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 25))
                    .shadow(color: .white.opacity(isPulsing ? 0.3 : 0.0), radius: isPulsing ? 20 : 0)
                    .animation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true), value: isPulsing)
                    .onAppear { isPulsing = true }
                
                Spacer()

                ScrollView {
                    ForEach(features, id: \.1) { icon, title, subtitle in
                        HStack(spacing: 15) {
                            Image(systemName: icon)
                                .font(.title3)
                                .frame(width: 40, height: 40)
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
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .scrollIndicators(.hidden)
                
                Spacer()
                                
                if !purchaseManager.isPremium {
                    Button(action: { purchaseManager.purchasePremium() }) {
                        Text("\(Image(systemName: "balloon.2"))   Full Version \(purchaseManager.products.first?.displayPrice ?? "$9.99")")
                            .bold()
                            .frame(width: 250, height: 35)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.glass)
                    .shadow(color: .white.opacity(0.2), radius: 10)
                    
                    Button(action: { Task { try? await purchaseManager.restorePurchases() } }) {
                        Text("\(Image(systemName: "icloud.and.arrow.down"))   Restore Purchase")
                            .bold()
                            .frame(width: 250, height: 35)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.glass)
                    .shadow(color: .white.opacity(0.2), radius: 10)
                }
            }
            VStack{
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .padding(10)
                            .glassEffect(.clear)
                            .clipShape(Circle())
                    }
                }
                Spacer()
            }
            .padding(30)
            .ignoresSafeArea()
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
