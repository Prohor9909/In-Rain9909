import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var audioManager: AudioEngineManager
    @State private var showUpsell = false
    @State private var showRestoreAlert = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Membership Status").foregroundColor(.gray)) {
                    if PurchaseManager.shared.isPremium {
                        Menu {
                            Button(action: { Task { try? await PurchaseManager.shared.restorePurchases(); showRestoreAlert = true } }) {
                                Label("Restore Purchases", systemImage: "arrow.clockwise")
                            }
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.seal.fill").foregroundColor(.orange)
                                Text("Full Version").foregroundColor(.orange)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray)
                            }
                        }
                    } else {
                        Button(action: { showUpsell = true }) {
                            HStack { Image(systemName: "crown.fill").foregroundColor(.orange); Text("Trial Version").foregroundColor(.white) }
                        }
                    }
                }.listRowBackground(Color.white.opacity(0.1))
                Section(header: Text("Background Audio").foregroundColor(.gray), footer: Text(audioManager.isBackgroundAudioEnabled ? "Mixer Mode allows audio to play simultaneously with other apps." : "Audio will stop when the app is in the background.").foregroundColor(.gray)) {
                    Toggle("Background Audio", isOn: $audioManager.isBackgroundAudioEnabled.animation()).toggleStyle(SwitchToggleStyle(tint: .green)).foregroundColor(.white)
                    if audioManager.isBackgroundAudioEnabled {
                        Toggle("Mixer Mode", isOn: $audioManager.isMixerModeEnabled).toggleStyle(SwitchToggleStyle(tint: .green)).foregroundColor(.white)
                    }
                }.listRowBackground(Color.white.opacity(0.1))
                Section(header: Text("Modulators").foregroundColor(.gray), footer: Text("Create subtle natural variations to your mix.").foregroundColor(.gray)) {
                    Toggle("Dynamic Intensity", isOn: $audioManager.isRandomVolumeEnabled).toggleStyle(SwitchToggleStyle(tint: .green)).foregroundColor(.white)
                    Toggle("Spatial Polarization", isOn: $audioManager.isRandomOscillationEnabled).toggleStyle(SwitchToggleStyle(tint: .green)).foregroundColor(.white)
                }.listRowBackground(Color.white.opacity(0.1))
                Section(header: Text("Beta Features").foregroundColor(.gray), footer: Text("These features are currently in beta.").foregroundColor(.gray)) {
                    Toggle("Visuals", isOn: $audioManager.isParticleEffectsEnabled).toggleStyle(SwitchToggleStyle(tint: .green)).foregroundColor(.white)
                }.listRowBackground(Color.white.opacity(0.1))
            }
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.08, green: 0.08, blue: 0.12).ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.font(.headline).foregroundColor(.blue) }
            }
            .fullScreenCover(isPresented: $showUpsell) { PurchaseView(audioManager: audioManager) }
            .alert(isPresented: $showRestoreAlert) {
                Alert(title: Text("Restore Complete"), message: Text(PurchaseManager.shared.isPremium ? "Your purchases have been restored." : "No previous purchases were found."), dismissButton: .default(Text("OK")))
            }
        }
        .preferredColorScheme(.dark)
    }
}
