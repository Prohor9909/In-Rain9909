import SwiftUI
import Combine
import AVFoundation
import MediaPlayer
import AVKit
import UIKit
import StoreKit

struct SaveProfileOverlay: View {
    @Binding var isPresented: Bool
    @State private var name: String = ""
    var onSave: (String) -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture { isPresented = false }
            VStack(spacing: 20) {
                Text("Name Your Mix").font(.headline).foregroundColor(.white)
                TextField("Mix Name", text: $name)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding().background(Color.white.opacity(0.1)).cornerRadius(12)
                    .foregroundColor(.white).accentColor(.orange)
                    .focused($isFocused).submitLabel(.done)
                    .onSubmit { if !name.isEmpty { onSave(name); isPresented = false; name = "" } }
                HStack(spacing: 15) {
                    Button("Cancel") { isPresented = false; name = "" }
                        .foregroundColor(.white.opacity(0.6)).padding(.vertical, 10).padding(.horizontal, 20)
                    Button("Save") { if !name.isEmpty { onSave(name); isPresented = false; name = "" } }
                        .fontWeight(.bold).foregroundColor(.black).padding(.vertical, 10).padding(.horizontal, 30)
                        .background(Color.orange).cornerRadius(20)
                }
            }
            .padding(25)
            .background(.ultraThinMaterial).cornerRadius(25)
            .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.white.opacity(0.1), lineWidth: 1))
            .padding(.horizontal, 40)
        }
        .onAppear { isFocused = true }
    }
}

struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.backgroundColor = .clear; picker.activeTintColor = .orange; picker.tintColor = .white.withAlphaComponent(0.7)
        return picker
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

struct PresetTemplate {
    let name: String
    let icon: String
    let values: [Double]
}

struct ContentView: View {
    @StateObject private var audioManager = AudioEngineManager()
    @StateObject private var timerManager = TimerManager()
    @StateObject private var profileManager = ProfileManager()
    
    @State private var showCustomTimerSheet = false
    @State private var showTimerDetail = false
    @State private var showSettings = false
    @State private var showProfiles = false
    
    @State private var showSaveProfileOverlay = false
    @State private var showOverwriteAlert = false
    @State private var tempProfileName = ""
    
    @State private var profileToRename: SoundProfile? = nil
    @State private var showRenameAlert = false
    @State private var renameText = ""
    
    @State private var bulbValues: [Double] = [0.0, 0.0, 0.0, 0.0, 0.0]
    @State private var isRandomizing = false
    @State private var shuffleRotation = 0.0
    
    @State private var profileRotations: [Double] = [0.0, 0.0, 0.0, 0.0, 0.0]
    @State private var overRotating: [Bool] = [false, false, false, false, false]
    @State private var reRotating: [Bool] = [false, false, false, false, false]
    
    @State private var activeProfileId: UUID? = nil
    
    private let presetTemplates: [PresetTemplate] = [
        PresetTemplate(name: "Focus", icon: "brain.head.profile", values: [0.45, 0.45, 0.45, 0.45, 0.45]),
        PresetTemplate(name: "Relax", icon: "wind", values: [0.5, 0.5, 0.5, 0.5, 0.5]),
        PresetTemplate(name: "Energy", icon: "bolt.fill", values: [0.5, 0.5, 0.5, 0.5, 0.5]),
        PresetTemplate(name: "Sleep", icon: "moon.stars.fill", values: [0.5, 0.5, 0.5, 0.5, 0.5]),
        PresetTemplate(name: "Zen", icon: "leaf.fill", values: [0.5, 0.5, 0.5, 0.5, 0.5])
    ]
    
    private var currentProfileButtonText: String {
        if let activeId = activeProfileId,
           let match = profileManager.profiles.first(where: { $0.id == activeId }),
           match.bulbValues == bulbValues {
            let name = match.name
            if name.count > 15 { return String(name.prefix(15)) + "..." }
            return name
        }
        
        if let match = profileManager.profiles.first(where: { $0.bulbValues == bulbValues }) {
            let name = match.name
            if name.count > 15 { return String(name.prefix(15)) + "..." }
            return name
        }
        return "Profiles"
    }
    
    private var isCurrentMixSaved: Bool {
        profileManager.profiles.contains(where: { $0.bulbValues == bulbValues })
    }
    
    let sliderIcons = ["cloud.rain.fill", "flame.fill", "drop.fill", "bolt.fill", "waveform"]
    let sliderColors: [[Color]] = [
        [Color.black.opacity(0.6), Color.blue],
        [Color.black.opacity(0.6), Color.red],
        [Color.black.opacity(0.6), Color.green],
        [Color.black.opacity(0.6), Color.yellow],
        [Color.black.opacity(0.6), Color.brown]
    ]
    
    var isAnyBulbOn: Bool { bulbValues.contains(where: { $0 > 0 }) }
    
    var body: some View {
        ZStack {
            ZStack {
                Image("background").resizable().scaledToFill().ignoresSafeArea().blur(radius: 10).onTapGesture { withAnimation { showProfiles = false } }
                RainEffectView(intensity: (audioManager.isParticleEffectsEnabled && bulbValues.indices.contains(0) && bulbValues[0] > 0) ? bulbValues[0] : 0.0, windAngle: bulbValues[2])
                    .edgesIgnoringSafeArea(.all).allowsHitTesting(false)
                    .padding(-200)
                FireEffectView(intensity: (audioManager.isParticleEffectsEnabled && bulbValues.indices.contains(1) && bulbValues[1] > 0) ? bulbValues[1] : 0.0).edgesIgnoringSafeArea(.all).allowsHitTesting(false)
            }.ignoresSafeArea(.keyboard)
            
            VStack(spacing: 0) {
                if timerManager.isTimerActive && !showProfiles {
                    Button(action: { showTimerDetail = true }) {
                        HStack {
                            ZStack {
                                Circle().stroke(Color.white.opacity(0.3), lineWidth: 2)
                                Circle().trim(from: 0, to: CGFloat(timerManager.progress)).stroke(Color.orange, style: StrokeStyle(lineWidth: 2, lineCap: .round)).rotationEffect(.degrees(-90)).frame(width: 20, height: 20)
                            }.frame(width: 20, height: 20)
                            Text(timerManager.formattedTime).font(.title2).monospacedDigit().foregroundColor(.white)
                        }
                        .padding(10).padding(.horizontal, 10).glassEffect(.clear)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity)).frame(maxWidth: .infinity).animation(.spring(), value: timerManager.isTimerActive)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { idx in
                        ControlView(
                            value: $bulbValues[idx],
                            activeIcon: sliderIcons[idx],
                            activeColors: sliderColors[idx],
                            iconColorOverride: (idx == 3 || idx == 4) ? sliderColors[idx].first : nil,
                            onUpdate: { updateVolume(for: idx) }
                        )
                        .onChange(of: bulbValues[idx]) { _, _ in updateVolume(for: idx) }
                    }
                }
                .offset(y: showProfiles ? 0 : 60)
                
                Button(
                    action: {
                        withAnimation(.bouncy)
                        {
                            showProfiles.toggle()
                        }
                    }) {
                    Text(currentProfileButtonText).font(.caption).bold().foregroundColor(.white).textCase(.uppercase).tracking(2).padding(.top, 20)
                }
                    .offset(y: showProfiles ? 0 : 60)
                
                
                HStack(spacing: 15) {
                    ForEach(0..<5, id: \.self) { index in
                        if index < profileManager.profiles.count {
                            let profile = profileManager.profiles[index]
                            let template = index < presetTemplates.count ? presetTemplates[index] : presetTemplates[0]
                            
                            Button(action: {
                                withAnimation {
                                    bulbValues = profile.bulbValues
                                    activeProfileId = profile.id
                                }
                                for idx in 0..<bulbValues.count { updateVolume(for: idx) }
                                let impact = UIImpactFeedbackGenerator(style: .light); impact.impactOccurred()
                            }) {
                                Image(systemName: template.icon)
                                    .foregroundColor(.white)
                                    .padding(15)
                                    .rotationEffect(.degrees(reRotating[index] ? -360 : profileRotations[index]))
                                    .scaleEffect(reRotating[index] ? 0.8 : (overRotating[index] ? 1.5 : 1.0))
                                    .glassEffect(.clear)
                                    .clipShape(Circle())
                            }
                            .contextMenu {
                                Button {
                                    profileToRename = profile
                                    renameText = profile.name
                                    showRenameAlert = true
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                
                                Button {
                                    profileManager.updateProfileSettings(id: profile.id, values: bulbValues)
                                    let impact = UIImpactFeedbackGenerator(style: .medium); impact.impactOccurred()
                                    animateProfileOverwrite(at: index)
                                } label: {
                                    Label("Overwrite", systemImage: "arrow.triangle.2.circlepath")
                                        .foregroundColor(.orange)
                                }
                                
                                Button(role: .destructive) {
                                    let resetValues = template.values
                                    
                                    profileManager.updateProfile(id: profile.id, newName: template.name)
                                    profileManager.updateProfileSettings(id: profile.id, values: resetValues)
                                    
                                    withAnimation {
                                        bulbValues = resetValues
                                        activeProfileId = profile.id
                                    }
                                    for idx in 0..<bulbValues.count { updateVolume(for: idx) }
                                    
                                    let impact = UIImpactFeedbackGenerator(style: .medium); impact.impactOccurred()
                                    animateProfileReset(at: index)
                                } label: {
                                    Label("Reset", systemImage: "arrow.counterclockwise")
                                }
                            }
                        }
                    }
                    .padding(.vertical, 20)
                    .scaleEffect(showProfiles ? 1 : 0)
                }
                
                Spacer()
                
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .medium); impact.impactOccurred()
                    if audioManager.isPlaying {
                        audioManager.stop(); if timerManager.isTimerActive { timerManager.pauseTimer() }
                    } else {
                        audioManager.play(); if timerManager.isTimerActive && timerManager.isPaused { timerManager.resumeTimer() }
                    }
                }) {
                    Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill").font(.largeTitle).foregroundStyle(.white).padding(35).glassEffect(.clear)
                }
                .scaleEffect(audioManager.isPlaying ? 1.05 : 1.0).animation(.spring, value: audioManager.isPlaying)
                .offset(y: -30)

                Spacer()
                
                HStack(spacing: 10) {
                    Button(action: randomizeMix) {
                        Image(systemName: "scribble").padding(15).rotationEffect(.degrees(shuffleRotation)).foregroundStyle(.white).glassEffect(.clear).scaleEffect(isRandomizing ? 1.5 : 1.0)
                    }
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .light); impact.impactOccurred(); withAnimation{ showSaveProfileOverlay = true }
                    }) {
                        Image(systemName: "plus").font(.title2).padding(15).foregroundStyle(.white).glassEffect(.clear).opacity(isCurrentMixSaved ? 0.5 : 1.0)
                    }.disabled(isCurrentMixSaved)
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .light); impact.impactOccurred(); if timerManager.isTimerActive { showTimerDetail = true } else { showCustomTimerSheet = true }
                    }) {
                        Image(systemName: "timer").font(.title).padding(20).foregroundStyle(.white).glassEffect(.clear)
                    }
                    .contentShape(Circle()).zIndex(1)
                    .contextMenu {
                        Button { timerManager.startTimer(duration: 15 * 60) } label: { Text("15 Minutes") }
                        Button { timerManager.startTimer(duration: 30 * 60) } label: { Text("30 Minutes") }
                        Button { timerManager.startTimer(duration: 60 * 60) } label: { Text("60 Minutes") }
                    }
                    AirPlayButton().frame(width: 45, height: 45).foregroundStyle(.white).padding(4).glassEffect(.clear)
                    Button(action: { let impact = UIImpactFeedbackGenerator(style: .light); impact.impactOccurred(); showSettings = true }) {
                        Image(systemName: "gearshape.fill").foregroundStyle(.white).padding(15).glassEffect(.clear)
                    }
                }
                .animation(.spring(), value: timerManager.isTimerActive)
                .offset(y: UIDevice.current.userInterfaceIdiom == .pad ? -200 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            if showSaveProfileOverlay {
                SaveProfileOverlay(isPresented: $showSaveProfileOverlay) { name in
                    if profileManager.profiles.contains(where: { $0.name == name }) {
                        tempProfileName = name; showOverwriteAlert = true
                    } else {
                        profileManager.saveProfile(name: name, values: bulbValues)
                    }
                }
            }
        }
        .onAppear {
            timerManager.setAudioManager(audioManager)
            for idx in 0..<bulbValues.count { updateVolume(for: idx) }
            
            if profileManager.profiles.count < 5 {
                for i in profileManager.profiles.count..<5 {
                    if i < presetTemplates.count {
                        let t = presetTemplates[i]
                        profileManager.saveProfile(name: t.name, values: t.values)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showCustomTimerSheet) { TimerView(timerManager: timerManager, audioManager: audioManager) }
        .sheet(isPresented: $showTimerDetail) { CountDownView(timerManager: timerManager) }
        .fullScreenCover(isPresented: $showSettings) { SettingsView(audioManager: audioManager) }
        .fullScreenCover(isPresented: $audioManager.showPremiumUpsell) { PurchaseView(audioManager: audioManager) }
        .statusBarHidden(true)
    }
    
    private func animateProfileOverwrite(at index: Int) {
        withAnimation {
            profileRotations[index] = 15
            overRotating[index] = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation {
                profileRotations[index] = 0
                overRotating[index] = false
            }
        }
    }
    
    private func animateProfileReset(at index: Int) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { reRotating[index] = true }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { reRotating[index] = false }
        }
    }
    
    private func randomizeMix() {
        let impact = UIImpactFeedbackGenerator(style: .medium); impact.impactOccurred()
        withAnimation { shuffleRotation = 15 }
        withAnimation { isRandomizing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation { shuffleRotation = 0 }
            withAnimation { isRandomizing = false }
        }
        withAnimation {
            for i in 0..<bulbValues.count { bulbValues[i] = 0.0 }
            let count = Int.random(in: 1...4)
            let indices = Array(0..<bulbValues.count).shuffled().prefix(count)
            for idx in indices { bulbValues[idx] = Double.random(in: 0.3...0.9) }
        }
        for i in 0..<bulbValues.count { updateVolume(for: i) }
    }
    
    private func updateVolume(for index: Int) {
        let targetVolume: Float = Float(bulbValues[index])
        audioManager.setVolume(for: index, volume: targetVolume)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View { ContentView().preferredColorScheme(.dark) }
}
