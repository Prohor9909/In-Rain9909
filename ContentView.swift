import SwiftUI
import AVKit

struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.backgroundColor = .clear;
        picker.activeTintColor = .orange;
        picker.tintColor = .white
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
    
    @State private var showOverwriteAlert = false
    @State private var tempProfileName = ""
    
    @State private var profileToRename: SoundProfile? = nil
    @State private var showRenameAlert = false
    @State private var renameText = ""
    
    @State private var bulbValues: [Double] = [0.45, 0.45, 0.45, 0.45, 0.45]
    @State private var isRandomizing = false
    @State private var isWindBouncing = false
    @State private var shuffleRotation = -30.0
    
    @State private var profileRotations: [Double] = [0.0, 0.0, 0.0, 0.0, 0.0]
    @State private var overRotating: [Bool] = [false, false, false, false, false]
    @State private var reRotating: [Bool] = [false, false, false, false, false]
    
    @State private var activeProfileId: UUID? = nil
    
    private let presetTemplates: [PresetTemplate] = [
        PresetTemplate(name: "Unwind", icon: "apple.meditate", values: [0.45, 0.45, 0.45, 0.45, 0.45]),
        PresetTemplate(name: "Study", icon: "lamp.desk.fill", values: [0.5, 0.5, 0.5, 0.5, 0.5]),
        PresetTemplate(name: "Sleep", icon: "moon.fill", values: [0.3, 0.6, 0.6, 0.2, 0.3]),
        PresetTemplate(name: "Isolation", icon: "person.fill", values: [0.35, 0.85, 0.15, 0.35, 0.25]),
        PresetTemplate(name: "Focus", icon: "brain.filled.head.profile", values: [0.5, 0.05, 0.45, 0.65, 0.25])
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
    
    let sliderIcons = ["cloud.bolt.rain", "flame.fill", "drop.halffull", "bolt.fill", "waveform"]
    let sliderColors: [[Color]] = [
        [.black.opacity(0.6), .blue],
        [.black.opacity(0.6), .red],
        [.black.opacity(0.6), .green],
        [.black.opacity(0.6), .yellow],
        [.black.opacity(0.6), .brown]
    ]
    
    var isAnyBulbOn: Bool { bulbValues.contains(where: { $0 > 0 }) }
    
    var body: some View {
        ZStack {
            ZStack {
                Color.clear
                    .background {
                        Image("background")
                            .resizable()
                            .scaledToFill()
                            .ignoresSafeArea()
                            .blur(radius: 10)
                            .onTapGesture {
                                withAnimation  (.bouncy) {
                                    showTimerDetail ? showProfiles = false : showProfiles.toggle()
                                    showTimerDetail = false
                                }
                            }

                    }
                
                RumbleEffectView(
                    intensity: audioManager.isPlaying ? bulbValues[4] : 0,
                    isEnabled: audioManager.isParticleEffectsEnabled
                )
                
                LightningEffectView(
                    intensity: audioManager.isPlaying ? bulbValues[3] : 0,
                    triggerFlash: audioManager.triggerFlash,
                    isEnabled: audioManager.isParticleEffectsEnabled
                )
                
                RainEffectView(
                    intensity: bulbValues.indices.contains(0) ? bulbValues[0] : 0.0,
                    windAngle: bulbValues[2],
                    isEnabled: audioManager.isParticleEffectsEnabled,
                    isPlaying: audioManager.isPlaying
                )
                .edgesIgnoringSafeArea(.all)
                .allowsHitTesting(false)
                .padding(-200)
                
                FireEffectView(
                    intensity: (audioManager.isPlaying && bulbValues.indices.contains(1) && bulbValues[1] > 0) ? bulbValues[1] : 0.0,
                    isEnabled: audioManager.isParticleEffectsEnabled
                )
                .edgesIgnoringSafeArea(.all)
                .allowsHitTesting(false)
            }
            
            VStack(spacing: 0) {
                
                if timerManager.isTimerActive {
                    GlassEffectContainer (spacing : 0){
                        HStack {
                            Button(action: {
                                withAnimation(.bouncy){
                                    showTimerDetail.toggle()
                                }
                            }) {
                                HStack {
                                    ZStack {
                                        Circle().stroke(Color.white.opacity(0.3), lineWidth: 2)
                                        Circle().trim(from: 0, to: CGFloat(timerManager.progress))
                                            .stroke(Color.orange, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                            .rotationEffect(.degrees(-90))
                                            .frame(width: 20, height: 20)
                                    }
                                    .frame(width: 20, height: 20)
                                    Text(timerManager.formattedTime)
                                        .font(.title2)
                                        .monospacedDigit()
                                }
                                .padding(10)
                                .padding(.horizontal, 10)
                                .glassEffect(.clear)
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .animation(.spring(), value: timerManager.isTimerActive)
                            
                            if showTimerDetail {
                                Button(action: {
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                    timerManager.stopTimer()
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.title3)
                                        .foregroundStyle(.red)
                                        .frame(width: 50, height: 50)
                                        .glassEffect(.clear)
                                }
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .scale),
                                    removal: .move(edge: .leading).combined(with: .scale)
                                ))
                            }
                        }
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { idx in
                        ControlView(
                            value: $bulbValues[idx],
                            activeIcon: sliderIcons[idx],
                            activeColors: sliderColors[idx],
                            onUpdate: { updateVolume(for: idx) }
                        )
                        .onChange(of: bulbValues[idx]) { _, _ in updateVolume(for: idx) }
                    }
                }
                
                Spacer()
                

                Text(currentProfileButtonText)
                    .font(.caption).bold()
                    .textCase(.uppercase).tracking(2)
                    .padding(.top, 20)
                    .offset(y: showProfiles ? -20 : 0)
                
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
                                    .foregroundColor(bulbValues == profile.bulbValues ? .orange : .white)
                                    .frame(width: 45, height: 45)
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
                    .offset(y: showProfiles ? -20 : 0)
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
                    Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                        .frame(width: 100, height: 100)
                        .glassEffect(.clear)
                }
                .scaleEffect(audioManager.isPlaying ? 1.05 : 1.0).animation(.spring, value: audioManager.isPlaying)

                Spacer()
                
                HStack(spacing: 15) {
                    Button(action: randomizeMix) {
                        Image(systemName: "scribble")
                            .rotationEffect(.degrees(shuffleRotation))
                            .foregroundStyle(.white)
                            .frame(width: 45, height: 45)
                            .glassEffect(.clear)
                            .scaleEffect(isRandomizing ? 1.2 : 1.0)
                    }
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        withAnimation{
                            audioManager.isAmbienceEnabled.toggle()
                        }
                        withAnimation(.spring(duration: 0.3)) {
                            isWindBouncing = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            withAnimation(.spring(duration: 0.3)) {
                                isWindBouncing = false
                            }
                        }
                    }) {
                        Image(systemName: "wind")
                            .font(.title2)
                            .foregroundStyle(audioManager.isAmbienceEnabled ? .orange : .white)
                            .frame(width: 45, height: 45)
                            .rotationEffect(.degrees(isWindBouncing ? -15 : 0))
                            .glassEffect(.clear)
                            .scaleEffect(isWindBouncing ? 1.2 : 1.0)
                    }
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        withAnimation (.bouncy) {
                            if timerManager.isTimerActive {
                                showTimerDetail.toggle()
                            }
                            else {
                                showCustomTimerSheet = true
                            }
                        }
                    }) {
                        Image(systemName: "timer")
                            .font(.title)
                            .foregroundStyle(timerManager.isTimerActive ? .orange : .white)
                            .frame(width: 70, height: 70)
                            .glassEffect(.clear)
                    }
                    .contextMenu {
                        Button { timerManager.startTimer(duration: 15 * 60) } label: { Text("15 Minutes") }
                        Button { timerManager.startTimer(duration: 30 * 60) } label: { Text("30 Minutes") }
                        Button { timerManager.startTimer(duration: 60 * 60) } label: { Text("60 Minutes") }
                    }
                    
                    AirPlayButton()
                        .scaleEffect(1.1)
                        .frame(width: 45, height: 45)
                        .glassEffect(.clear)
                    
                    Button(action: { let impact = UIImpactFeedbackGenerator(style: .light); impact.impactOccurred(); showSettings = true }) {
                        Image(systemName: "gear")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 47, height: 47)
                            .glassEffect(.clear)
                    }
                }
                .animation(.spring(), value: timerManager.isTimerActive)
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
        .sheet(isPresented: $showCustomTimerSheet) {
            TimerView(timerManager: timerManager, audioManager: audioManager)
                .presentationDetents([.medium, .fraction(0.4)])
        }
        .fullScreenCover(isPresented: $showSettings){
            SettingsView(audioManager: audioManager)
                .presentationBackground(.black.opacity(0.8))
        }
        .fullScreenCover(isPresented: $audioManager.showPremiumUpsell) {
            PurchaseView(audioManager: audioManager)
        }
        .statusBarHidden(true)
        .alert("Rename Profile", isPresented: $showRenameAlert) {
            TextField("New Name", text: $renameText)
            Button("Rename") {
                if let profile = profileToRename, !renameText.isEmpty, !profileManager.profiles.contains(where: { $0.name == renameText }) {
                    profileManager.updateProfile(id: profile.id, newName: renameText)
                }
            }
            .disabled(renameText.isEmpty || profileManager.profiles.contains(where: { $0.name == renameText }))
            Button("Cancel", role: .cancel) { }
        }
        .alert("Profile Already Exists", isPresented: $showOverwriteAlert) {
            Button("Overwrite", role: .destructive) {
                profileManager.updateProfileByName(name: tempProfileName, values: bulbValues)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("A profile with the name '\(tempProfileName)' already exists. Do you want to overwrite it?")
        }
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
        withAnimation(.spring(duration: 0.3)) {
            shuffleRotation = 15
            isRandomizing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.spring(duration: 0.3)) {
                shuffleRotation = -30
                isRandomizing = false
            }
        }
        withAnimation(.spring(duration: 0.3)) {
            for i in 0..<bulbValues.count {
                bulbValues[i] = Double.random(in: 0...1)
            }
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
