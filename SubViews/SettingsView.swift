import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var audioManager: AudioEngineManager
    @State private var showUpsell = false
    @State private var showRestoreAlert = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Membership Status"), footer: Text(PurchaseManager.shared.isPremium ? "You have the full version of this app." : "Trial mode interrupts playback every minute.")) {
                    if PurchaseManager.shared.isPremium {
                        Label("Full Version", systemImage: "balloon.2")
                    } else {
                        Button(action: { showUpsell = true }) {
                            Label("Trial Mode", systemImage: "hourglass")
                        }
                    }
                }
                .symbolRenderingMode(.hierarchical)
                
                Section(header: Text("Audio Behavior"), footer: Text(audioManager.isBackgroundAudioEnabled ? "Mixer mode allows audio to play simultaneously with other apps." : "Audio will stop when the app is in the background.")) {
                    Toggle("Background Audio", systemImage: "music.note", isOn: $audioManager.isBackgroundAudioEnabled.animation()).tint(.blue)
                    
                    if audioManager.isBackgroundAudioEnabled {
                        Toggle("Mixer Mode", systemImage: "music.quarternote.3", isOn: $audioManager.isMixerModeEnabled).tint(.blue)
                    }
                }
                .symbolRenderingMode(.hierarchical)
                
                Section(header: Text("Ambient Effects"), footer: Text("Ambience introduces a natural unpredictablity in rain.")) {
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
        .scrollContentBackground(.hidden)
        .preferredColorScheme(.dark)
    }
}
