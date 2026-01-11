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

struct PremiumUpsellView: View {
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

struct CustomTimerSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var timerManager: TimerManager
    var audioManager: AudioEngineManager
    @State private var selectedHours = 0
    @State private var selectedMinutes = 5
    @State private var selectedSeconds = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Set Duration").font(.title3).foregroundColor(.white.opacity(0.7)).padding(.top, 20)
                HStack(spacing: 0) {
                    Picker("Hours", selection: $selectedHours) { ForEach(0..<24) { i in Text("\(i) h").tag(i).foregroundColor(.white) } }.pickerStyle(.wheel).frame(width: 70).clipped()
                    Picker("Minutes", selection: $selectedMinutes) { ForEach(0..<60) { i in Text("\(i) m").tag(i).foregroundColor(.white) } }.pickerStyle(.wheel).frame(width: 70).clipped()
                    Picker("Seconds", selection: $selectedSeconds) { ForEach(0..<60) { i in Text("\(i) s").tag(i).foregroundColor(.white) } }.pickerStyle(.wheel).frame(width: 70).clipped()
                }
                .colorScheme(.dark).padding()
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundColor(.white) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        let totalSeconds = TimeInterval((selectedHours * 3600) + (selectedMinutes * 60) + selectedSeconds)
                        if totalSeconds > 0 { timerManager.startTimer(duration: totalSeconds) }
                        dismiss()
                    }.font(.headline).foregroundColor(.blue)
                }
            }
        }
    }
}

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
                    Toggle("Background Audio", isOn: $audioManager.isBackgroundAudioEnabled).toggleStyle(SwitchToggleStyle(tint: .green)).foregroundColor(.white)
                    if audioManager.isBackgroundAudioEnabled {
                        Toggle("Mixer Mode", isOn: $audioManager.isMixerModeEnabled).toggleStyle(SwitchToggleStyle(tint: .green)).foregroundColor(.white)
                    }
                }.listRowBackground(Color.white.opacity(0.1))
                Section(header: Text("Randomizer").foregroundColor(.gray), footer: Text("Volume fades (70%-130%). Oscillation drifts audio (Left-Right).").foregroundColor(.gray)) {
                    Toggle("Random Volume", isOn: $audioManager.isRandomVolumeEnabled).toggleStyle(SwitchToggleStyle(tint: .green)).foregroundColor(.white)
                    Toggle("Random Oscillation", isOn: $audioManager.isRandomOscillationEnabled).toggleStyle(SwitchToggleStyle(tint: .green)).foregroundColor(.white)
                }.listRowBackground(Color.white.opacity(0.1))
                Section(header: Text("Beta Features").foregroundColor(.gray), footer: Text("These features are currently in beta.").foregroundColor(.gray)) {
                    Toggle("Particle Effects", isOn: $audioManager.isParticleEffectsEnabled).toggleStyle(SwitchToggleStyle(tint: .green)).foregroundColor(.white)
                }.listRowBackground(Color.white.opacity(0.1))
            }
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.08, green: 0.08, blue: 0.12).ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.font(.headline).foregroundColor(.blue) }
            }
            .fullScreenCover(isPresented: $showUpsell) { PremiumUpsellView(audioManager: audioManager) }
            .alert(isPresented: $showRestoreAlert) {
                Alert(title: Text("Restore Complete"), message: Text(PurchaseManager.shared.isPremium ? "Your purchases have been restored." : "No previous purchases were found."), dismissButton: .default(Text("OK")))
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct FullScreenTimerView: View {
    @ObservedObject var timerManager: TimerManager
    @Environment(\.dismiss) var dismiss
    @State private var showCancelConfirmation = false
    
    var body: some View {
        VStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.compact.down").font(.system(size: 44, weight: .bold)).foregroundColor(.white.opacity(0.5)).padding(.top, 20)
            }
            Spacer()
            ZStack {
                Circle().stroke(Color.gray.opacity(0.3), lineWidth: 15)
                Circle().trim(from: 0, to: CGFloat(timerManager.progress))
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: timerManager.progress)
                Text(timerManager.formattedTime)
                    .font(.system(size: 64, weight: .thin, design: .default)).monospacedDigit().foregroundColor(.white)
            }.frame(width: 300, height: 300).padding()
            Spacer()
            Button(action: { showCancelConfirmation = true }) {
                Text("Cancel").font(.title2).fontWeight(.medium).foregroundColor(.black)
                    .frame(width: 110, height: 110).background(Color.gray).clipShape(Circle())
                    .overlay(Circle().stroke(Color.black, lineWidth: 2))
            }.padding(.bottom, 50)
        }
        .alert(isPresented: $showCancelConfirmation) {
            Alert(title: Text("Cancel Timer"), message: Text("Are you sure you want to cancel the timer?"), primaryButton: .destructive(Text("Cancel Timer")) { timerManager.stopTimer(); dismiss() }, secondaryButton: .cancel())
        }
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

struct BulbSliderWithToggle: View {
    @Binding var value: Double
    @Binding var isOn: Bool
    var activeIcon: String
    var activeColors: [Color]
    var iconColorOverride: Color? = nil
    var onUpdate: () -> Void
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let knobDiameter: CGFloat = width - 4
            let bottomPadding: CGFloat = 2
            let trackWidth: CGFloat = 12
            let trackHeight = height - knobDiameter - (bottomPadding * 2)
            ZStack(alignment: .bottom) {
                Capsule().fill(Color.white.opacity(0.1)).frame(width: trackWidth).glassEffect(.clear).padding(.bottom, bottomPadding + 2)
                if isOn {
                    Capsule()
                        .fill(LinearGradient(colors: activeColors, startPoint: .bottom, endPoint: .top))
                        .frame(width: trackWidth, height: (CGFloat(value) * trackHeight) + knobDiameter + (bottomPadding * 2))
                        .animation(.spring(response: 0.3), value: value)
                }
                Image(systemName: activeIcon)
                    .font(.title2).foregroundColor(isOn ? .primary : .secondary)
                    .frame(width: knobDiameter, height: knobDiameter).padding(5)
                    .glassEffect().offset(y: -(CGFloat(value) * trackHeight)-2).padding(.bottom, bottomPadding)
            }
            .frame(width: width, height: height).contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { gesture in
                let dragY = gesture.location.y
                let rawValue = 1.0 - (dragY / height)
                let clamped = min(max(rawValue, 0.0), 1.0)
                let threshold: Double = 0.05
                if clamped > threshold && !isOn {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred(); isOn = true
                } else if clamped <= threshold && isOn {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred(); isOn = false
                }
                if !isOn { value = 0.0 } else { value = clamped }
                onUpdate()
            })
        }.frame(width: 40, height: 180)
    }
}

class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()
    @Published var isPremium: Bool = UserDefaults.standard.bool(forKey: "isPremium") {
        didSet { UserDefaults.standard.set(isPremium, forKey: "isPremium") }
    }
    @Published var products: [Product] = []
    private let productID = "com.studio.In.Rain.premium"
    private var updates: Task<Void, Never>? = nil
    
    init() {
        updates = Task.detached { [weak self] in
            for await result in StoreKit.Transaction.updates {
                if let transaction = try? self?.checkVerified(result) {
                    await self?.process(transaction: transaction)
                    await transaction.finish()
                }
            }
        }
        Task { await requestProducts(); await updatePurchasedStatus() }
    }
    deinit { updates?.cancel() }
    @MainActor func requestProducts() async { do { products = try await Product.products(for: [productID]) } catch {} }
    @MainActor func updatePurchasedStatus() async {
        var hasPremium = false
        for await result in StoreKit.Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result), transaction.productID == productID { hasPremium = true }
        }
        self.setPremiumStatus(hasPremium)
    }
    @MainActor func purchasePremium() {
        guard let product = products.first else { return }
        Task {
            if let result = try? await product.purchase(), case .success(let verification) = result {
                let transaction = try checkVerified(verification)
                process(transaction: transaction)
                await transaction.finish()
            }
        }
    }
    @MainActor func restorePurchases() async throws { try? await AppStore.sync(); await updatePurchasedStatus() }
    @MainActor private func process(transaction: StoreKit.Transaction) {
        if transaction.productID == productID { setPremiumStatus(transaction.revocationDate == nil) }
    }
    private func setPremiumStatus(_ status: Bool) { DispatchQueue.main.async { self.isPremium = status } }
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result { case .unverified: throw URLError(.badServerResponse); case .verified(let safe): return safe }
    }
}

class TimerManager: ObservableObject {
    @Published var timeRemaining: TimeInterval = 0
    @Published var totalDuration: TimeInterval = 0
    @Published var isTimerActive = false
    @Published var isPaused = false
    private var timer: Timer?
    private var audioManager: AudioEngineManager?
    
    func setAudioManager(_ manager: AudioEngineManager) { self.audioManager = manager }
    func startTimer(duration: TimeInterval) {
        stopTimer(); totalDuration = duration; timeRemaining = duration; isTimerActive = true; isPaused = false
        audioManager?.play(); createTimer()
    }
    func pauseTimer() { guard isTimerActive else { return }; timer?.invalidate(); timer = nil; isPaused = true }
    func resumeTimer() { guard isTimerActive, isPaused, timeRemaining > 0 else { return }; isPaused = false; createTimer() }
    private func createTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            if let self = self { if self.timeRemaining > 0 { self.timeRemaining -= 1 } else { self.timerFinished() } }
        }
    }
    func stopTimer() { timer?.invalidate(); timer = nil; isTimerActive = false; isPaused = false; timeRemaining = 0; totalDuration = 0 }
    private func timerFinished() { stopTimer(); audioManager?.stop() }
    var progress: Double { guard totalDuration > 0 else { return 0 }; return timeRemaining / totalDuration }
    var formattedTime: String {
        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        let seconds = Int(timeRemaining) % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, seconds) : String(format: "%02d:%02d", minutes, seconds)
    }
}

class SoundTrack: NSObject {
    private var players: [AVAudioPlayer] = []
    private var activePlayerIndex = 0
    var individualVolume: Float = 0.5, masterVolume: Float = 1.0, randomVolumeMultiplier: Float = 1.0
    var fileName: String
    private var crossfadeTimer: Timer?
    private let crossfadeDuration: TimeInterval = 2.5
    private var isPlaying: Bool = false
    private var volumeFadeTimer: Timer?
    private var panFadeTimer: Timer?
    
    init(fileName: String) {
        self.fileName = fileName
        super.init()
        let extensions = ["mp3", "wav", "m4a", "aac", "caf", "aiff", "flac"]
        if let url = extensions.compactMap({ Bundle.main.url(forResource: fileName, withExtension: $0) }).first {
            for _ in 0..<2 {
                if let p = try? AVAudioPlayer(contentsOf: url) {
                    p.numberOfLoops = 0; p.prepareToPlay(); players.append(p)
                }
            }
        }
    }
    func play() {
        guard !isPlaying, !players.isEmpty else { return }
        isPlaying = true
        let p = players[activePlayerIndex]
        if !p.isPlaying {
            p.currentTime = 0; p.volume = 0; p.play()
            p.setVolume(currentVolume, fadeDuration: 1.0)
            scheduleCrossfade(for: p)
        }
    }
    func pause() {
        isPlaying = false; crossfadeTimer?.invalidate(); volumeFadeTimer?.invalidate(); panFadeTimer?.invalidate()
        for p in players where p.isPlaying { p.setVolume(0, fadeDuration: 0.5) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { if !self.isPlaying { for p in self.players { p.pause() } } }
    }
    func setVolumes(individual: Float, master: Float) {
        self.individualVolume = individual; self.masterVolume = master
        if isPlaying { let active = players[activePlayerIndex]; if active.isPlaying { active.setVolume(currentVolume, fadeDuration: 0.2) } }
    }
    func fadeRandomVolume(to target: Float, duration: TimeInterval) {
        volumeFadeTimer?.invalidate()
        let start = randomVolumeMultiplier, steps = Int(duration * 20), stepAmount = (target - start) / Float(steps)
        var currentStep = 0
        volumeFadeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            currentStep += 1; self.randomVolumeMultiplier = start + (stepAmount * Float(currentStep))
            if self.isPlaying {
                let active = self.players[self.activePlayerIndex]
                if active.isPlaying { active.setVolume(self.currentVolume, fadeDuration: 0.05) }
            }
            if currentStep >= steps { timer.invalidate() }
        }
    }
    func fadePan(to target: Float, duration: TimeInterval) {
        panFadeTimer?.invalidate()
        let start = players.first?.pan ?? 0.0, steps = Int(duration * 20), stepAmount = (target - start) / Float(steps)
        var currentStep = 0
        panFadeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            currentStep += 1; let newPan = start + (stepAmount * Float(currentStep))
            for p in self.players { p.pan = newPan }
            if currentStep >= steps { timer.invalidate() }
        }
    }
    var currentVolume: Float { return individualVolume * masterVolume * randomVolumeMultiplier }
    private func scheduleCrossfade(for player: AVAudioPlayer) {
        crossfadeTimer?.invalidate()
        let delay = player.duration - player.currentTime - crossfadeDuration
        guard delay > 0 else { performCrossfade(); return }
        crossfadeTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in self?.performCrossfade() }
    }
    private func performCrossfade() {
        guard isPlaying, !players.isEmpty else { return }
        let outgoingPlayer = players[activePlayerIndex], nextIndex = (activePlayerIndex + 1) % players.count, incomingPlayer = players[nextIndex]
        incomingPlayer.currentTime = 0; incomingPlayer.volume = 0; incomingPlayer.play()
        incomingPlayer.setVolume(currentVolume, fadeDuration: crossfadeDuration)
        outgoingPlayer.setVolume(0, fadeDuration: crossfadeDuration)
        activePlayerIndex = nextIndex
        scheduleCrossfade(for: incomingPlayer)
        DispatchQueue.main.asyncAfter(deadline: .now() + crossfadeDuration + 0.2) {
            if self.isPlaying { outgoingPlayer.pause(); outgoingPlayer.currentTime = 0 }
        }
    }
}

class AudioEngineManager: ObservableObject {
    private var tracks: [SoundTrack] = []
    private let fileNames = ["rain", "fireplace", "umbrella", "Blizzard", "ocean"]
    private var individualVolumes: [Float] = []
    private var wasPlayingWhenBackgrounded = false, usageTimer: Timer?
    @Published var continuousPlayTime: TimeInterval = 0
    @Published var showPremiumUpsell = false
    private var volumeTask: Task<Void, Never>?, oscillationTask: Task<Void, Never>?
    @Published var isBackgroundAudioEnabled: Bool { didSet { UserDefaults.standard.set(isBackgroundAudioEnabled, forKey: "isBackgroundAudioEnabled"); configureAudioSession() } }
    @Published var isMixerModeEnabled: Bool { didSet { UserDefaults.standard.set(isMixerModeEnabled, forKey: "isMixerModeEnabled"); configureAudioSession() } }
    @Published var isRandomVolumeEnabled: Bool { didSet { UserDefaults.standard.set(isRandomVolumeEnabled, forKey: "isRandomVolumeEnabled"); updateRandomizerState() } }
    @Published var isRandomOscillationEnabled: Bool { didSet { UserDefaults.standard.set(isRandomOscillationEnabled, forKey: "isRandomOscillationEnabled"); updateRandomizerState() } }
    @Published var isParticleEffectsEnabled: Bool { didSet { UserDefaults.standard.set(isParticleEffectsEnabled, forKey: "isParticleEffectsEnabled") } }
    @Published var isPlaying: Bool = false {
        didSet {
            var info = [String: Any](); info[MPMediaItemPropertyTitle] = "White Noise"; info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            if isPlaying { startUsageTracking(); updateRandomizerState() } else { stopUsageTracking(); volumeTask?.cancel(); oscillationTask?.cancel() }
        }
    }
    @Published var masterVolume: Float = 1.0 { didSet { updateAllVolumes() } }
    
    init() {
        self.isBackgroundAudioEnabled = UserDefaults.standard.object(forKey: "isBackgroundAudioEnabled") as? Bool ?? true
        self.isMixerModeEnabled = UserDefaults.standard.object(forKey: "isMixerModeEnabled") as? Bool ?? false
        self.isRandomVolumeEnabled = UserDefaults.standard.bool(forKey: "isRandomVolumeEnabled")
        self.isRandomOscillationEnabled = UserDefaults.standard.bool(forKey: "isRandomOscillationEnabled")
        self.isParticleEffectsEnabled = UserDefaults.standard.bool(forKey: "isParticleEffectsEnabled")
        individualVolumes = Array(repeating: 0.5, count: fileNames.count)
        configureAudioSession(); setupTracks(); setupInterruptionObserver(); setupRemoteTransportControls(); setupLifecycleObservers()
    }
    deinit { NotificationCenter.default.removeObserver(self); volumeTask?.cancel(); oscillationTask?.cancel(); usageTimer?.invalidate() }
    private func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    @objc private func appDidEnterBackground() { if !isBackgroundAudioEnabled { if isPlaying { wasPlayingWhenBackgrounded = true; stop() } else { wasPlayingWhenBackgrounded = false } } }
    @objc private func appWillEnterForeground() { if !isBackgroundAudioEnabled && wasPlayingWhenBackgrounded { play(); wasPlayingWhenBackgrounded = false } }
    private func configureAudioSession() {
        do {
            let options: AVAudioSession.CategoryOptions = (isBackgroundAudioEnabled && isMixerModeEnabled) ? [.mixWithOthers] : []
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: options); try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
    }
    private func setupInterruptionObserver() { NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance()) }
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { [weak self] _ in self?.play(); return .success }
        commandCenter.pauseCommand.addTarget { [weak self] _ in self?.stop(); return .success }
        commandCenter.nextTrackCommand.isEnabled = false; commandCenter.previousTrackCommand.isEnabled = false
    }
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo, let type = (userInfo[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init) else { return }
        if type == .began { DispatchQueue.main.async { self.isPlaying = false } }
        else if type == .ended, let options = (userInfo[AVAudioSessionInterruptionOptionKey] as? UInt).map(AVAudioSession.InterruptionOptions.init), options.contains(.shouldResume) { self.play() }
    }
    private func setupTracks() { tracks.removeAll(); for fileName in fileNames { tracks.append(SoundTrack(fileName: fileName)) } }
    private func updateRandomizerState() {
        volumeTask?.cancel(); oscillationTask?.cancel()
        guard isPlaying else { return }
        if isRandomVolumeEnabled { startRandomVolumeLoop() } else { for track in tracks { track.fadeRandomVolume(to: 1.0, duration: 1.0) } }
        if isRandomOscillationEnabled { startRandomOscillationLoop() } else { for track in tracks { track.fadePan(to: 0.0, duration: 1.0) } }
    }
    private func startRandomVolumeLoop() {
        volumeTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 3...45) * 1_000_000_000))
                if Task.isCancelled { break }
                let tgt = Float.random(in: 0.7...1.3), dur = Double.random(in: 2.0...4.0)
                await MainActor.run { for track in tracks { if track.fileName == "fireplace" { continue }; track.fadeRandomVolume(to: tgt, duration: dur) } }
            }
        }
    }
    private func startRandomOscillationLoop() {
        oscillationTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 3...45) * 1_000_000_000))
                if Task.isCancelled { break }
                let tgt = Float.random(in: -0.7...0.7), dur = Double.random(in: 2.0...5.0)
                await MainActor.run { for track in tracks { if track.fileName == "fireplace" { continue }; track.fadePan(to: tgt, duration: dur) } }
            }
        }
    }
    private func startUsageTracking() {
        stopUsageTracking()
        guard !PurchaseManager.shared.isPremium else { return }
        usageTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if PurchaseManager.shared.isPremium { self.stopUsageTracking(); return }
            self.continuousPlayTime += 1; if self.continuousPlayTime >= 60 { self.triggerUpsell() }
        }
    }
    private func stopUsageTracking() { usageTimer?.invalidate(); usageTimer = nil }
    private func triggerUpsell() { DispatchQueue.main.async { [weak self] in self?.stop(); self?.continuousPlayTime = 0; self?.showPremiumUpsell = true } }
    func setVolume(for index: Int, volume: Float) {
        guard index < individualVolumes.count else { return }
        individualVolumes[index] = volume
        if index < tracks.count { tracks[index].setVolumes(individual: volume, master: masterVolume) }
    }
    private func updateAllVolumes() { for (i, t) in tracks.enumerated() { t.setVolumes(individual: individualVolumes[i], master: masterVolume) } }
    func play() { configureAudioSession(); for track in tracks { track.play() }; isPlaying = true }
    func stop() { for track in tracks { track.pause() }; isPlaying = false }
}

struct SoundProfile: Identifiable, Codable { let id: UUID; let name: String; let bulbValues: [Double]; let bulbToggles: [Bool] }
class ProfileManager: ObservableObject {
    @Published var profiles: [SoundProfile] = [] {
        didSet { if let encoded = try? JSONEncoder().encode(profiles) { UserDefaults.standard.set(encoded, forKey: "saved_sound_profiles") } }
    }
    init() { if let data = UserDefaults.standard.data(forKey: "saved_sound_profiles"), let decoded = try? JSONDecoder().decode([SoundProfile].self, from: data) { profiles = decoded } }
    func saveProfile(name: String, values: [Double], toggles: [Bool]) { profiles.append(SoundProfile(id: UUID(), name: name, bulbValues: values, bulbToggles: toggles)) }
    func updateProfileByName(name: String, values: [Double], toggles: [Bool]) { if let index = profiles.firstIndex(where: { $0.name == name }) { profiles[index] = SoundProfile(id: profiles[index].id, name: name, bulbValues: values, bulbToggles: toggles) } }
    func updateProfileSettings(id: UUID, values: [Double], toggles: [Bool]) { if let index = profiles.firstIndex(where: { $0.id == id }) { profiles[index] = SoundProfile(id: id, name: profiles[index].name, bulbValues: values, bulbToggles: toggles) } }
    func deleteProfile(id: UUID) { if let index = profiles.firstIndex(where: { $0.id == id }) { profiles.remove(at: index) } }
    func updateProfile(id: UUID, newName: String) { if let index = profiles.firstIndex(where: { $0.id == id }) { let old = profiles[index]; profiles[index] = SoundProfile(id: id, name: newName, bulbValues: old.bulbValues, bulbToggles: old.bulbToggles) } }
}

struct RainParticle: Identifiable { let id = UUID(); var x: CGFloat; var y: CGFloat; var speed: Double; var opacity: Double; var scale: Double; var length: CGFloat }
struct RainEffectView: View {
    var intensity: Double
    @State private var particles = [RainParticle]()
    private var targetParticleCount: Int { return intensity > 0 ? Int(50 + (150 * intensity)) : 0 }
    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 0.016)) { timeline in
                Canvas { context, size in
                    for particle in particles {
                        var particleContext = context; particleContext.opacity = particle.opacity
                        let frame = CGRect(x: particle.x, y: particle.y, width: 2 * particle.scale, height: particle.length)
                        particleContext.fill(Capsule().path(in: frame), with: .color(.white.opacity(0.7)))
                    }
                }
                .rotationEffect(.degrees(10)).opacity(intensity > 0 ? 1.0 : 0.0).animation(.linear(duration: 0.3), value: intensity > 0)
                .onChange(of: timeline.date) {
                    let volumeSpeedMultiplier = 1.0 + (intensity * 0.3)
                    for i in particles.indices {
                        particles[i].y += particles[i].speed * (0.016 * 60) * 2.25 * volumeSpeedMultiplier * 0.3
                        if particles[i].y > geometry.size.height + 100 { particles[i] = createParticle(in: geometry.size, isInitial: false) }
                    }
                }
            }
            .onAppear { particles = (0..<targetParticleCount).map { _ in createParticle(in: geometry.size, isInitial: true) } }
            .onChange(of: intensity) {
                let diff = targetParticleCount - particles.count
                if diff > 0 { particles.append(contentsOf: (0..<diff).map { _ in createParticle(in: geometry.size, isInitial: false) }) }
                else if diff < 0 { particles.removeLast(abs(diff)) }
            }
        }.allowsHitTesting(false)
    }
    private func createParticle(in size: CGSize, isInitial: Bool) -> RainParticle {
        let scale = Double.random(in: 0.5...1.0)
        return RainParticle(x: .random(in: -50...size.width + 50), y: .random(in: isInitial ? -100...size.height : -150...(-50)), speed: .random(in: 15...25) * scale, opacity: .random(in: 0.1...0.5), scale: scale, length: .random(in: 20...50) * scale)
    }
}

struct FireParticle: Identifiable { let id = UUID(); var x: CGFloat; var y: CGFloat; var speed: Double; var opacity: Double; var scale: Double; var color: Color; var drift: Double; var shapeSeed: Double }
struct FireGlowView: View {
    let intensity: Double
    @State private var isAnimating1 = false
    @State private var isAnimating2 = false
    private var glowScale: CGFloat { 0.5 + (intensity * 0.5) }
    var body: some View {
        ZStack {
            Ellipse().fill(Color.orange.opacity(0.6)).frame(width: 300 * glowScale, height: 100 * glowScale).blur(radius: 60).scaleEffect(isAnimating1 ? 1.05 : 0.95, anchor: .bottom).opacity(isAnimating1 ? 0.7 : 0.5)
            Ellipse().fill(Color.yellow.opacity(0.5)).frame(width: 200 * glowScale, height: 80 * glowScale).blur(radius: 50).scaleEffect(isAnimating2 ? 0.95 : 1.05, anchor: .bottom).opacity(isAnimating2 ? 0.6 : 0.4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom).opacity(intensity > 0 ? 1.0 : 0.0).animation(.linear(duration: 0.5), value: intensity)
        .onAppear { withAnimation(.easeInOut(duration: 2.1).repeatForever(autoreverses: true)) { isAnimating1 = true }; withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) { isAnimating2 = true } }
        .allowsHitTesting(false)
    }
}
struct FireEffectView: View {
    var intensity: Double
    @State private var particles = [FireParticle]()
    private var targetParticleCount: Int { Int(10 + (60 * intensity)) }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                FireGlowView(intensity: intensity)
                TimelineView(.animation(minimumInterval: 0.016)) { timeline in
                    Canvas { context, size in
                        for particle in particles {
                            var particleContext = context; particleContext.opacity = particle.opacity
                            let frame = CGRect(x: particle.x, y: particle.y, width: 8 * particle.scale, height: 8 * particle.scale)
                            let shape = createEmberShape(in: frame, seed: particle.shapeSeed, time: timeline.date.timeIntervalSinceReferenceDate)
                            particleContext.addFilter(.shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)); particleContext.fill(shape, with: .color(particle.color))
                        }
                    }
                    .opacity(intensity > 0 ? 1.0 : 0.0).animation(.linear(duration: 0.3), value: intensity > 0)
                    .onChange(of: timeline.date) {
                        let volumeSpeedMultiplier = 1.0 + (intensity * 0.5)
                        for i in particles.indices {
                            particles[i].y -= particles[i].speed * (0.016 * 60) * volumeSpeedMultiplier; particles[i].x += sin(timeline.date.timeIntervalSinceReferenceDate * particles[i].drift) * 0.5; particles[i].opacity -= 0.008
                            if particles[i].y < geometry.size.height - 250 || particles[i].opacity <= 0 { particles[i] = createParticle(in: geometry.size) }
                        }
                    }
                }
            }
            .onAppear { particles = (0..<targetParticleCount).map { _ in createParticle(in: geometry.size) } }
            .onChange(of: intensity) {
                let diff = targetParticleCount - particles.count
                if diff > 0 { particles.append(contentsOf: (0..<diff).map { _ in createParticle(in: geometry.size) }) }
                else if diff < 0 { particles.removeLast(abs(diff)) }
            }
        }
    }
    private func createEmberShape(in rect: CGRect, seed: Double, time: TimeInterval) -> Path {
        var path = Path(); let wobble = sin(time * 3 + seed) * (rect.width / 3), wobble2 = cos(time * 2 + seed) * (rect.width / 3)
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control: CGPoint(x: rect.maxX + wobble, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY + wobble2))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY), control: CGPoint(x: rect.minX - wobble, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY - wobble2))
        return path
    }
    private func createParticle(in size: CGSize) -> FireParticle {
        let scale = Double.random(in: 0.4...1.0)
        return FireParticle(x: .random(in: 0...size.width), y: .random(in: size.height...size.height + 40), speed: .random(in: 0.3...1.0), opacity: .random(in: 0.6...0.9), scale: scale, color: [.orange, .yellow, .red].randomElement()!, drift: .random(in: 1...3), shapeSeed: .random(in: 0...100))
    }
}

struct ContentView: View {
    @StateObject private var audioManager = AudioEngineManager()
    @StateObject private var timerManager = TimerManager()
    @StateObject private var profileManager = ProfileManager()
    
    @State private var showCustomTimerSheet = false
    @State private var showTimerDetail = false
    @State private var showStopConfirmation = false
    @State private var showSettings = false
    @State private var showProfiles = false
    
    @State private var showSaveProfileOverlay = false
    @State private var showOverwriteAlert = false
    @State private var tempProfileName = ""
    
    @State private var profileToRename: SoundProfile? = nil
    @State private var showRenameAlert = false
    @State private var renameText = ""
    
    @State private var profileToDelete: SoundProfile? = nil
    @State private var showDeleteConfirmation = false
    
    @State private var bulbValues: [Double] = [0.0, 0.0, 0.0, 0.0, 0.0]
    @State private var bulbToggles: [Bool] = [false, false, false, false, false]
    @State private var isRandomizing = false
    @State private var shuffleRotation = 0.0
    
    private var currentProfileButtonText: String {
        if let match = profileManager.profiles.first(where: { $0.bulbValues == bulbValues && $0.bulbToggles == bulbToggles }) {
            let name = match.name
            if name.count > 15 { return String(name.prefix(15)) + "..." }
            return name
        }
        return "Profiles"
    }
    
    private var isCurrentMixSaved: Bool {
        profileManager.profiles.contains(where: { $0.bulbValues == bulbValues && $0.bulbToggles == bulbToggles })
    }
    
    let sliderIcons = ["cloud.rain.fill", "flame.fill", "drop.fill", "bolt.fill", "waveform"]
    let sliderColors: [[Color]] = [
        [Color(red: 0.4, green: 0.8, blue: 1.0), Color(red: 0.0, green: 0.2, blue: 0.8)],
        [Color.orange, Color.red],
        [Color.yellow, Color.teal],
        [Color.cyan, Color.mint],
        [Color(red: 0.0, green: 0.5, blue: 0.5), Color(red: 0.0, green: 0.0, blue: 0.3)]
    ]
    
    var isAnyBulbOn: Bool { bulbToggles.contains(true) }
    
    var body: some View {
        ZStack {
            ZStack {
                Image("background").resizable().scaledToFill().ignoresSafeArea().blur(radius: 10).onTapGesture { withAnimation { showProfiles = false } }
                RainEffectView(intensity: (audioManager.isParticleEffectsEnabled && bulbToggles.indices.contains(0) && bulbToggles[0]) ? bulbValues[0] : 0.0).edgesIgnoringSafeArea(.all).allowsHitTesting(false)
                FireEffectView(intensity: (audioManager.isParticleEffectsEnabled && bulbToggles.indices.contains(1) && bulbToggles[1]) ? bulbValues[1] : 0.0).edgesIgnoringSafeArea(.all).allowsHitTesting(false)
            }.ignoresSafeArea(.keyboard)
            
            GeometryReader { geo in
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
                            BulbSliderWithToggle(
                                value: $bulbValues[idx], isOn: $bulbToggles[idx],
                                activeIcon: sliderIcons[idx], activeColors: sliderColors[idx],
                                iconColorOverride: (idx == 3 || idx == 4) ? sliderColors[idx].first : nil,
                                onUpdate: { updateVolume(for: idx) }
                            )
                            .onChange(of: bulbValues[idx]) { _, _ in updateVolume(for: idx) }
                            .onChange(of: bulbToggles[idx]) { _, isOn in updateVolume(for: idx) }
                        }
                    }
                    
                    Button(action: { withAnimation { showProfiles.toggle() } }) {
                        Text(currentProfileButtonText).font(.caption).bold().foregroundColor(.white).textCase(.uppercase).tracking(2).padding(.top, 20)
                    }
                    
                    if showProfiles {
                        VStack (spacing: 0) {
                            if profileManager.profiles.isEmpty {
                                Text("No saved profiles").font(.caption).foregroundColor(.secondary)
                            } else {
                                ScrollView(.vertical, showsIndicators: false) {
                                    VStack(spacing: 0) {
                                        ForEach(profileManager.profiles) { profile in
                                            Button(action: {
                                                bulbValues = profile.bulbValues; bulbToggles = profile.bulbToggles
                                                for idx in 0..<bulbValues.count { updateVolume(for: idx) }
                                                let impact = UIImpactFeedbackGenerator(style: .light); impact.impactOccurred()
                                            }) {
                                                Text(profile.name).lineLimit(1).truncationMode(.tail).foregroundColor(.white).frame(width: 150).padding(.vertical, 5).glassEffect(.clear)
                                            }
                                            .padding(.vertical, 5).padding(.horizontal, 20)
                                            .contextMenu {
                                                Button { profileManager.updateProfileSettings(id: profile.id, values: bulbValues, toggles: bulbToggles); let impact = UIImpactFeedbackGenerator(style: .medium); impact.impactOccurred() } label: { Label("Overwrite", systemImage: "arrow.triangle.2.circlepath") }
                                                Button { profileToRename = profile; renameText = profile.name; showRenameAlert = true } label: { Label("Rename", systemImage: "pencil") }
                                                Button(role: .destructive) { profileToDelete = profile; showDeleteConfirmation = true } label: { Label("Delete", systemImage: "trash") }
                                            }
                                        }
                                    }
                                }
                                .frame(height: min(CGFloat(profileManager.profiles.count * 55), geo.size.height * 0.45))
                            }
                        }.padding(.vertical, 20).scaleEffect(showProfiles ? 1 : 0)
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
                .frame(width: geo.size.width, height: geo.size.height)
            }
            
            if showSaveProfileOverlay {
                SaveProfileOverlay(isPresented: $showSaveProfileOverlay) { name in
                    if profileManager.profiles.contains(where: { $0.name == name }) {
                        tempProfileName = name; showOverwriteAlert = true
                    } else {
                        profileManager.saveProfile(name: name, values: bulbValues, toggles: bulbToggles)
                    }
                }
            }
        }
        .onAppear {
            timerManager.setAudioManager(audioManager)
            for idx in 0..<bulbValues.count { updateVolume(for: idx) }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showCustomTimerSheet) { CustomTimerSheet(timerManager: timerManager, audioManager: audioManager) }
        .sheet(isPresented: $showTimerDetail) { FullScreenTimerView(timerManager: timerManager) }
        .fullScreenCover(isPresented: $showSettings) { SettingsView(audioManager: audioManager) }
        .alert(isPresented: $showStopConfirmation) {
            Alert(title: Text("Cancel Timer"), message: Text("Are you sure you want to cancel the timer?"), primaryButton: .destructive(Text("Cancel Timer")) { timerManager.stopTimer() }, secondaryButton: .cancel())
        }
        .alert(isPresented: $showOverwriteAlert) {
            Alert(title: Text("Profile Exists"), message: Text("Overwrite existing profile '\(tempProfileName)'?"), primaryButton: .destructive(Text("Overwrite")) { profileManager.updateProfileByName(name: tempProfileName, values: bulbValues, toggles: bulbToggles); showSaveProfileOverlay = false }, secondaryButton: .cancel { showSaveProfileOverlay = true })
        }
        .alert("Rename Profile", isPresented: $showRenameAlert) {
            TextField("New Name", text: $renameText)
            Button("Save") { if let profile = profileToRename { profileManager.updateProfile(id: profile.id, newName: renameText) } }
            Button("Cancel", role: .cancel) { }
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(title: Text("Delete Profile?"), message: Text("Are you sure you want to delete '\(profileToDelete?.name ?? "this profile")'? This action cannot be undone."), primaryButton: .destructive(Text("Delete")) { if let profile = profileToDelete { withAnimation { profileManager.deleteProfile(id: profile.id) } } }, secondaryButton: .cancel())
        }
        .onChange(of: isAnyBulbOn) { _, newValue in }
        .fullScreenCover(isPresented: $audioManager.showPremiumUpsell) { PremiumUpsellView(audioManager: audioManager) }
        .statusBarHidden(true)
    }
    
    private func randomizeMix() {
        let impact = UIImpactFeedbackGenerator(style: .medium); impact.impactOccurred()
        withAnimation(.easeOut(duration: 0.25)) { shuffleRotation = 15 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { isRandomizing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeIn(duration: 0.3)) { shuffleRotation = 0 }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { isRandomizing = false }
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            for i in 0..<bulbValues.count { bulbValues[i] = 0.0; bulbToggles[i] = false }
            let count = Int.random(in: 1...4)
            let indices = Array(0..<bulbValues.count).shuffled().prefix(count)
            for idx in indices { bulbToggles[idx] = true; bulbValues[idx] = Double.random(in: 0.3...0.9) }
        }
        for i in 0..<bulbValues.count { updateVolume(for: i) }
    }
    
    private func updateVolume(for index: Int) {
        let targetVolume: Float = bulbToggles[index] ? Float(bulbValues[index]) : 0.0
        audioManager.setVolume(for: index, volume: targetVolume)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View { ContentView().preferredColorScheme(.dark) }
}
