import SwiftUI
import Combine
import AVFoundation
import MediaPlayer
import UIKit

class TimerManager: ObservableObject {
    @Published var timeRemaining: TimeInterval = 0
    @Published var totalDuration: TimeInterval = 0
    @Published var isTimerActive = false
    @Published var isPaused = false
    private var timer: Timer?
    private var audioManager: AudioEngineManager?
    
    func setAudioManager(_ manager: AudioEngineManager) { self.audioManager = manager }
    
    func startTimer(duration: TimeInterval) {
        withAnimation {
            stopTimer()
            totalDuration = duration
            timeRemaining = duration
            isTimerActive = true
            isPaused = false
            audioManager?.timerFadeVolume = 1.0 // Reset fade volume
            audioManager?.play()
            createTimer()
        }
    }
    
    func pauseTimer() {
        withAnimation {
            guard isTimerActive else { return }
            timer?.invalidate()
            timer = nil
            isPaused = true
        }
    }
    
    func resumeTimer() {
        withAnimation {
            guard isTimerActive, isPaused, timeRemaining > 0 else { return }
            isPaused = false
            createTimer()
        }
    }
    
    private func createTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.applyFadeLogic()
            
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.timerFinished()
            }
        }
    }
    
    private func applyFadeLogic() {
        guard let audioManager = audioManager else { return }
        
        var fadeDuration: TimeInterval = 0
        if totalDuration >= 3600 { // 60 Minutes or more
            fadeDuration = 60
        } else if totalDuration >= 300 { // 5 Minutes to 59 Minutes
            fadeDuration = 30
        }
        
        if fadeDuration > 0 && timeRemaining <= fadeDuration {
            let volume = Float(timeRemaining) / Float(fadeDuration)
            audioManager.timerFadeVolume = max(0, min(1, volume))
        } else {
            // Ensure full volume if not in fade window
            if audioManager.timerFadeVolume != 1.0 {
                audioManager.timerFadeVolume = 1.0
            }
        }
    }
    
    func stopTimer() {
        withAnimation {
            timer?.invalidate()
            timer = nil
            isTimerActive = false
            isPaused = false
            timeRemaining = 0
            totalDuration = 0
            audioManager?.timerFadeVolume = 1.0 // Reset fade volume
        }
    }
    
    private func timerFinished() {
        // Stop audio first to prevent volume blip when resetting fade volume in stopTimer
        audioManager?.stop()
        stopTimer()
    }
    
    var progress: Double { guard totalDuration > 0 else { return 0 }; return timeRemaining / totalDuration }
    var formattedTime: String {
        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        let seconds = Int(timeRemaining) % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, seconds) : String(format: "%02d:%02d", minutes, seconds)
    }
}

class SoundTrack: NSObject {
    private var engine: AVAudioEngine
    private var playerNodes: [AVAudioPlayerNode] = [AVAudioPlayerNode(), AVAudioPlayerNode()]
    private var trackMixer = AVAudioMixerNode()
    private var nodeFadeMultipliers: [Float] = [1.0, 1.0]
    private var activeNodeIndex = 0
    private var eqNode = AVAudioUnitEQ(numberOfBands: 2)
    private var buffer: AVAudioPCMBuffer?
    
    var individualVolume: Float = 0.5, masterVolume: Float = 1.0, randomVolumeMultiplier: Float = 1.0
    var volumeScale: Float = 1.0
    var fileName: String
    var onLoop: (() -> Void)?
    private var isPlaying: Bool = false
    
    private var volumeFadeTimer: Timer?
    private var bassFadeTimer: Timer?
    private var trebleFadeTimer: Timer?
    private var loopTimer: Timer?
    
    var loopingEnabled: Bool = true
    private let crossfadeDuration: TimeInterval = 5.0
    
    init(fileName: String, engine: AVAudioEngine) {
        self.fileName = fileName
        self.engine = engine
        super.init()
        
        let extensions = ["mp3", "wav", "m4a", "aac", "caf", "aiff", "flac"]
        if let url = extensions.compactMap({ Bundle.main.url(forResource: fileName, withExtension: $0) }).first {
            if let file = try? AVAudioFile(forReading: url) {
                let format = file.processingFormat
                buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length))
                try? file.read(into: buffer!)
            }
        }
        
        setupNodes()
    }
    
    private func setupNodes() {
        for node in playerNodes { engine.attach(node) }
        engine.attach(trackMixer)
        engine.attach(eqNode)
        
        let bassBand = eqNode.bands[0]
        bassBand.filterType = .lowShelf
        bassBand.frequency = 150
        bassBand.bypass = false
        
        let trebleBand = eqNode.bands[1]
        trebleBand.filterType = .highShelf
        trebleBand.frequency = 3500
        trebleBand.bypass = false
        
        let format = buffer?.format ?? AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: format.sampleRate, channels: 2)!
        
        for node in playerNodes {
            engine.connect(node, to: trackMixer, format: format)
        }
        
        engine.connect(trackMixer, to: eqNode, format: stereoFormat)
        engine.connect(eqNode, to: engine.mainMixerNode, format: stereoFormat)
    }
    
    func play() {
        guard let buffer = buffer else { return }
        isPlaying = true
        
        loopTimer?.invalidate()
        let node = playerNodes[activeNodeIndex]
        node.stop()
        node.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        
        nodeFadeMultipliers = [0.0, 0.0]
        nodeFadeMultipliers[activeNodeIndex] = 1.0
        
        updateNodeVolumes()
        if !engine.isRunning { try? engine.start() }
        node.play()
        
        if loopingEnabled { scheduleNextLoop() }
        onLoop?()
    }
    
    private func scheduleNextLoop() {
        loopTimer?.invalidate()
        let dur = self.duration
        guard dur > crossfadeDuration else {
            loopTimer = Timer.scheduledTimer(withTimeInterval: max(0.1, dur), repeats: false) { [weak self] _ in self?.play() }
            return
        }
        
        loopTimer = Timer.scheduledTimer(withTimeInterval: dur - crossfadeDuration, repeats: false) { [weak self] _ in
            self?.performCrossfade()
        }
    }
    
    private func performCrossfade() {
        guard isPlaying, loopingEnabled, let buffer = buffer else { return }
        
        let outgoingIndex = activeNodeIndex
        let incomingIndex = (activeNodeIndex + 1) % playerNodes.count
        activeNodeIndex = incomingIndex
        
        let incomingNode = playerNodes[incomingIndex]
        incomingNode.stop()
        incomingNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        
        nodeFadeMultipliers[incomingIndex] = 0.0
        incomingNode.volume = 0
        incomingNode.play()
        
        let steps = Int(crossfadeDuration * 20)
        let stepAmount: Float = 1.0 / Float(steps)
        var currentStep = 0
        
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            currentStep += 1
            
            self.nodeFadeMultipliers[outgoingIndex] = max(0, self.nodeFadeMultipliers[outgoingIndex] - stepAmount)
            self.nodeFadeMultipliers[incomingIndex] = min(1, self.nodeFadeMultipliers[incomingIndex] + stepAmount)
            
            self.updateNodeVolumes()
            
            if currentStep >= steps {
                timer.invalidate()
                self.playerNodes[outgoingIndex].stop()
            }
        }
        
        scheduleNextLoop()
        onLoop?()
    }
    
    func pause() {
        isPlaying = false
        loopTimer?.invalidate()
        for node in playerNodes {
            node.volume = 0
            node.pause()
        }
    }
    
    func setVolumes(individual: Float, master: Float) {
        self.individualVolume = individual; self.masterVolume = master
        updateNodeVolumes()
    }
    
    private func updateNodeVolumes() {
        for (i, node) in playerNodes.enumerated() {
            node.volume = currentVolume * nodeFadeMultipliers[i]
        }
    }
    
    func fadeRandomVolume(to target: Float, duration: TimeInterval) {
        volumeFadeTimer?.invalidate()
        let start = randomVolumeMultiplier, steps = Int(duration * 20), stepAmount = (target - start) / Float(steps)
        var currentStep = 0
        volumeFadeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            currentStep += 1
            self.randomVolumeMultiplier = start + (stepAmount * Float(currentStep))
            self.updateNodeVolumes()
            if currentStep >= steps { timer.invalidate() }
        }
    }
    
    func fadeBass(to multiplier: Float, duration: TimeInterval) {
        bassFadeTimer?.invalidate()
        let targetGain = (multiplier - 1.0) * 50.0
        let startGain = eqNode.bands[0].gain
        let steps = Int(duration * 20), stepAmount = (targetGain - startGain) / Float(steps)
        var currentStep = 0
        bassFadeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            currentStep += 1
            self.eqNode.bands[0].gain = startGain + (stepAmount * Float(currentStep))
            if currentStep >= steps { timer.invalidate() }
        }
    }
    
    func fadeTreble(to multiplier: Float, duration: TimeInterval) {
        trebleFadeTimer?.invalidate()
        let targetGain = (multiplier - 1.0) * 50.0
        let startGain = eqNode.bands[1].gain
        let steps = Int(duration * 20), stepAmount = (targetGain - startGain) / Float(steps)
        var currentStep = 0
        trebleFadeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            currentStep += 1
            self.eqNode.bands[1].gain = startGain + (stepAmount * Float(currentStep))
            if currentStep >= steps { timer.invalidate() }
        }
    }
    
    var currentVolume: Float { return individualVolume * masterVolume * randomVolumeMultiplier * volumeScale }
    var duration: TimeInterval {
        guard let buffer = buffer else { return 0 }
        return Double(buffer.frameLength) / buffer.format.sampleRate
    }
}

class AudioEngineManager: ObservableObject {
    private let engine = AVAudioEngine()
    private var tracks: [SoundTrack] = []
    private var thunderTracks: [SoundTrack] = []
    private let fileNames = ["Rain", "Fire", "Splash", "Thunder", "Rumbling"]
    private let thunderFileNames = ["Thunder", "Thunder1"]
    private var individualVolumes: [Float] = []
    private var wasPlayingWhenBackgrounded = false, usageTimer: Timer?
    @Published var continuousPlayTime: TimeInterval = 0
    @Published var showPremiumUpsell = false
    @Published var triggerFlash = false
    private var ambienceTasks: [Task<Void, Never>] = []
    private var thunderLoopTask: Task<Void, Never>?
    
    @Published var isBackgroundAudioEnabled: Bool { didSet { UserDefaults.standard.set(isBackgroundAudioEnabled, forKey: "isBackgroundAudioEnabled"); configureAudioSession() } }
    @Published var isMixerModeEnabled: Bool { didSet { UserDefaults.standard.set(isMixerModeEnabled, forKey: "isMixerModeEnabled"); configureAudioSession() } }
    @Published var isAmbienceEnabled: Bool { didSet { UserDefaults.standard.set(isAmbienceEnabled, forKey: "isAmbienceEnabled"); updateAmbienceState() } }
    @Published var isParticleEffectsEnabled: Bool { didSet { UserDefaults.standard.set(isParticleEffectsEnabled, forKey: "isParticleEffectsEnabled") } }
    @Published var isPlaying: Bool = false {
        didSet {
            var info = [String: Any](); info[MPMediaItemPropertyTitle] = "In Rain"; info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            if isPlaying {
                startUsageTracking()
                updateAmbienceState()
                startThunderLoop()
            } else {
                stopUsageTracking()
                stopAmbienceTasks()
                thunderLoopTask?.cancel()
            }
        }
    }
    @Published var masterVolume: Float = 1.0 { didSet { updateAllVolumes() } }
    
    // New property to handle timer fade
    var timerFadeVolume: Float = 1.0 { didSet { updateAllVolumes() } }
    
    init() {
        self.isBackgroundAudioEnabled = UserDefaults.standard.object(forKey: "isBackgroundAudioEnabled") as? Bool ?? true
        self.isMixerModeEnabled = UserDefaults.standard.object(forKey: "isMixerModeEnabled") as? Bool ?? false
        self.isAmbienceEnabled = UserDefaults.standard.object(forKey: "isAmbienceEnabled") as? Bool ?? true
        self.isParticleEffectsEnabled = UserDefaults.standard.object(forKey: "isParticleEffectsEnabled") as? Bool ?? true
        individualVolumes = Array(repeating: 0.5, count: fileNames.count)
        configureAudioSession(); setupTracks(); setupInterruptionObserver(); setupRemoteTransportControls(); setupLifecycleObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopAmbienceTasks()
        thunderLoopTask?.cancel()
        usageTimer?.invalidate()
    }
    
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
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo, let type = (userInfo[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init) else { return }
        if type == .began { DispatchQueue.main.async { self.isPlaying = false } }
        else if type == .ended, let options = (userInfo[AVAudioSessionInterruptionOptionKey] as? UInt).map(AVAudioSession.InterruptionOptions.init), options.contains(.shouldResume) { self.play() }
    }
    
    private func setupTracks() {
        tracks.removeAll()
        thunderTracks.removeAll()
        for (i, fileName) in fileNames.enumerated() {
            if fileName == "Thunder" {
                for tName in thunderFileNames {
                    let track = SoundTrack(fileName: tName, engine: engine)
                    track.loopingEnabled = false
                    track.setVolumes(individual: individualVolumes[i], master: masterVolume * timerFadeVolume)
                    thunderTracks.append(track)
                }
            } else {
                let track = SoundTrack(fileName: fileName, engine: engine)
                track.setVolumes(individual: individualVolumes[i], master: masterVolume * timerFadeVolume)
                tracks.append(track)
            }
        }
    }
    
    private func stopAmbienceTasks() {
        for task in ambienceTasks { task.cancel() }
        ambienceTasks.removeAll()
    }

    private func updateAmbienceState() {
        stopAmbienceTasks()
        guard isPlaying else { return }
        
        if isAmbienceEnabled {
            startAmbienceSimulation()
        } else {
            for track in tracks {
                track.fadeRandomVolume(to: 1.0, duration: 2.0)
                track.fadeBass(to: 1.0, duration: 2.0)
                track.fadeTreble(to: 1.0, duration: 2.0)
            }
            for track in thunderTracks {
                track.volumeScale = 1.0
            }
        }
    }
    
    private func startAmbienceSimulation() {
        for track in tracks {
            if track.fileName == "Fire" { continue }
            
            let vTask = Task {
                while !Task.isCancelled && isPlaying && isAmbienceEnabled {
                    let sleepSecs = Double.random(in: 20...60)
                    let tgt = Float.random(in: 0.6...1.0)
                    await MainActor.run { track.fadeRandomVolume(to: tgt, duration: sleepSecs) }
                    try? await Task.sleep(nanoseconds: UInt64(sleepSecs * 1_000_000_000))
                }
            }
            
            let bTask = Task {
                while !Task.isCancelled && isPlaying && isAmbienceEnabled {
                    let sleepSecs = Double.random(in: 20...60)
                    let tgt = Float.random(in: 0.8...1.2)
                    await MainActor.run { track.fadeBass(to: tgt, duration: sleepSecs) }
                    try? await Task.sleep(nanoseconds: UInt64(sleepSecs * 1_000_000_000))
                }
            }
            
            let tTask = Task {
                while !Task.isCancelled && isPlaying && isAmbienceEnabled {
                    let sleepSecs = Double.random(in: 20...60)
                    let tgt = Float.random(in: 0.8...1.2)
                    await MainActor.run { track.fadeTreble(to: tgt, duration: sleepSecs) }
                    try? await Task.sleep(nanoseconds: UInt64(sleepSecs * 1_000_000_000))
                }
            }
            
            ambienceTasks.append(contentsOf: [vTask, bTask, tTask])
        }
    }

    private func startThunderLoop() {
        thunderLoopTask?.cancel()
        thunderLoopTask = Task {
            while !Task.isCancelled && isPlaying {
                guard let track = thunderTracks.randomElement() else { break }
                
                await MainActor.run {
                    if isAmbienceEnabled {
                        track.volumeScale = Float.random(in: 0.8...1.1)
                    } else {
                        track.volumeScale = 1.0
                    }
                    track.play()
                    triggerFlash.toggle()
                }
                
                let trackDuration = track.duration
                try? await Task.sleep(nanoseconds: UInt64(trackDuration * 1_000_000_000))
                
                let gap = isAmbienceEnabled ? Double.random(in: (5.0 - Double(individualVolumes[3]) * 5.0)...(30.0 - Double(individualVolumes[3]) * 25.0)) : (30.0 - Double(individualVolumes[3]) * 25.0)
//                let gap = isAmbienceEnabled ? Double.random(in: 5...45) : 5.0
                try? await Task.sleep(nanoseconds: UInt64(gap * 1_000_000_000))
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
        let fileName = fileNames[index]
        if fileName == "Thunder" {
            for t in thunderTracks { t.setVolumes(individual: volume, master: masterVolume * timerFadeVolume) }
        } else {
            if let track = tracks.first(where: { $0.fileName == fileName }) {
                track.setVolumes(individual: volume, master: masterVolume * timerFadeVolume)
            }
        }
    }
    
    private func updateAllVolumes() {
        for (i, fileName) in fileNames.enumerated() {
            if fileName == "Thunder" {
                for t in thunderTracks { t.setVolumes(individual: individualVolumes[i], master: masterVolume * timerFadeVolume) }
            } else {
                if let track = tracks.first(where: { $0.fileName == fileName }) {
                    track.setVolumes(individual: individualVolumes[i], master: masterVolume * timerFadeVolume)
                }
            }
        }
    }
    
    func play() {
        configureAudioSession()
        engine.prepare()
        if !engine.isRunning { try? engine.start() }
        for track in tracks { track.play() }
        isPlaying = true
    }
    
    func stop() {
        for track in tracks { track.pause() }
        for track in thunderTracks { track.pause() }
        engine.stop()
        isPlaying = false
    }
}

struct SoundProfile: Identifiable, Codable { let id: UUID; let name: String; let bulbValues: [Double] }
class ProfileManager: ObservableObject {
    @Published var profiles: [SoundProfile] = [] {
        didSet { if let encoded = try? JSONEncoder().encode(profiles) { UserDefaults.standard.set(encoded, forKey: "saved_sound_profiles") } }
    }
    init() { if let data = UserDefaults.standard.data(forKey: "saved_sound_profiles"), let decoded = try? JSONDecoder().decode([SoundProfile].self, from: data) { profiles = decoded } }
    func saveProfile(name: String, values: [Double]) { profiles.append(SoundProfile(id: UUID(), name: name, bulbValues: values)) }
    func updateProfileByName(name: String, values: [Double]) { if let index = profiles.firstIndex(where: { $0.name == name }) { profiles[index] = SoundProfile(id: profiles[index].id, name: name, bulbValues: values) } }
    func updateProfileSettings(id: UUID, values: [Double]) { if let index = profiles.firstIndex(where: { $0.id == id }) { profiles[index] = SoundProfile(id: id, name: profiles[index].name, bulbValues: values) } }
    func deleteProfile(id: UUID) { if let index = profiles.firstIndex(where: { $0.id == id }) { profiles.remove(at: index) } }
    func updateProfile(id: UUID, newName: String) { if let index = profiles.firstIndex(where: { $0.id == id }) { let old = profiles[index]; profiles[index] = SoundProfile(id: id, name: newName, bulbValues: old.bulbValues) } }
}
