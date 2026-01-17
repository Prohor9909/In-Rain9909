import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var audioManager: AudioEngineManager
    @State private var showUpsell = false
    @State private var showRestoreAlert = false
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("App Status"), footer: Text(PurchaseManager.shared.isPremium ? "You have the full version of this app." : "Trial mode interrupts playback every minute.")) {
                    if PurchaseManager.shared.isPremium {
                        Button(action: { showUpsell = true }) {
                            Label("In Rain v\(version)", systemImage: "balloon.2")
                                .foregroundStyle(.primary)
                        }
                    } else {
                        Button(action: { showUpsell = true }) {
                            Label("Trial Mode", systemImage: "hourglass")
                        }
                    }
                }
                .symbolRenderingMode(.hierarchical)
                
                Section(header: Text("Audio Behavior"), footer: Text(audioManager.isBackgroundAudioEnabled ? "Mixer allows audio to blend with other apps." : "Audio continues to play in background.")) {
                    Toggle("Background Audio", systemImage: "music.note", isOn: $audioManager.isBackgroundAudioEnabled.animation()).tint(.blue)
                    
                    if audioManager.isBackgroundAudioEnabled {
                        Toggle("Mixer Mode", systemImage: "music.quarternote.3", isOn: $audioManager.isMixerModeEnabled).tint(.blue)
                    }
                }
                .symbolRenderingMode(.hierarchical)
                
                Section(header: Text("Ambient Effects"), footer: Text("Ambience creates an ever changing variation.")) {
                    Toggle("Visuals", systemImage: "bird",  isOn: $audioManager.isParticleEffectsEnabled).tint(.blue)
                    Toggle("Ambience", systemImage: "wind", isOn: $audioManager.isAmbienceEnabled).tint(.blue)
                }
                .symbolRenderingMode(.hierarchical)
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.foregroundColor(.blue)}
            }
            .fullScreenCover(isPresented: $showUpsell) {
                PurchaseView(audioManager: audioManager)
            }
            
            .alert(isPresented: $showRestoreAlert) {
                Alert(title: Text("Restore Complete"), message: Text(PurchaseManager.shared.isPremium ? "Your purchases have been restored." : "No previous purchases were found."), dismissButton: .default(Text("OK")))
            }
        }
        .statusBarHidden(true)
        .scrollContentBackground(.hidden)
        .preferredColorScheme(.dark)
    }
}
