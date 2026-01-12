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
