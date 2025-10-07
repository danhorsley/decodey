// SoundManager.swift
// Decodey
//
// Manages all sound effects and haptic feedback for the game

import AVFoundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Sound Manager with Full Cross-Platform Support
class SoundManager: ObservableObject {
    // Singleton
    static let shared = SoundManager()
    
    // Sound types matching M4A file names
    enum SoundType: String, CaseIterable {
        case letterClick = "letter_click"
        case correctGuess = "correct_guess"
        case incorrectGuess = "incorrect_guess"
        case win = "win"
        case lose = "lose"
        case hint = "hint"
        
        // Minimum delay between plays (in seconds)
        var minimumDelay: TimeInterval {
            switch self {
            case .letterClick:
                return 0.05
            case .hint:
                return 0.5
            case .correctGuess, .incorrectGuess:
                return 0.2
            case .win, .lose:
                return 1.0
            }
        }
        
        #if os(iOS)
        @available(iOS 17.0, *)
        var sensoryFeedback: SensoryFeedback {
            switch self {
            case .letterClick:
                return .selection
            case .correctGuess:
                return .success
            case .incorrectGuess:
                return .warning
            case .win:
                return .levelChange
            case .lose:
                return .error
            case .hint:
                return .impact(weight: .light, intensity: 0.7)
            }
        }
        #endif
    }
    
    // MARK: - Properties
    
    @Published var isSoundEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isSoundEnabled, forKey: "soundEnabled")
            if !isSoundEnabled {
                stopAllSounds()
            }
        }
    }
    
    @Published var isHapticEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isHapticEnabled, forKey: "hapticEnabled")
        }
    }
    
    @Published var volume: Float = 0.7 {
        didSet {
            UserDefaults.standard.set(volume, forKey: "soundVolume")
            updateVolume()
        }
    }
    
    // Track haptic triggers for SwiftUI's sensoryFeedback
    @Published var hapticTriggerID = UUID()
    @Published var lastTriggeredSound: SoundType? = nil
    
    // AVPlayer-based sound system (cross-platform)
    private var audioPlayers: [SoundType: AVPlayer] = [:]
    private var audioAssets: [SoundType: AVAsset] = [:]
    
    // Track playing state and debouncing
    private var isPlaying: [SoundType: Bool] = [:]
    private var lastPlayTime: [SoundType: TimeInterval] = [:]
    
    // Rate limiting for letter clicks
    private var letterClickCount = 0
    private var letterClickResetTimer: Timer?
    private let maxLetterClicksPerSecond = 5
    
    // Platform-specific haptic support
    #if canImport(UIKit)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    #endif
    
    // MARK: - Initialization
    
    private init() {
        // Load preferences
        self.isSoundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        self.isHapticEnabled = UserDefaults.standard.object(forKey: "hapticEnabled") as? Bool ?? true
        self.volume = UserDefaults.standard.object(forKey: "soundVolume") as? Float ?? 0.7
        
        // Setup audio and haptics
        setupCrossPlatformAudio()
        loadSounds()
        prepareHapticGenerators()
    }
    
    // MARK: - Cross-Platform Audio Setup
    
    private func setupCrossPlatformAudio() {
        #if canImport(AVAudioSession)
        do {
            // iOS: Configure audio session for game audio
            try AVAudioSession.sharedInstance().setCategory(
                .ambient,  // Respects silent switch
                mode: .default,
                options: [.mixWithOthers]  // Play nicely with other apps
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Audio session setup failed - sounds will still work but may not respect silent switch
        }
        #endif
    }
    
    // MARK: - Sound Loading
    
    private func loadSounds() {
        for soundType in SoundType.allCases {
            guard let soundURL = Bundle.main.url(forResource: soundType.rawValue, withExtension: "m4a") else {
                continue
            }
            
            // Create AVAsset for loading
            let asset = AVAsset(url: soundURL)
            audioAssets[soundType] = asset
            
            // Create AVPlayer for each sound
            let playerItem = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: playerItem)
            player.volume = volume
            
            // Pre-load the asset asynchronously
            Task {
                do {
                    _ = try await asset.load(.duration, .tracks)
                } catch {
                    // Asset loading failed but player will still attempt playback
                }
            }
            
            audioPlayers[soundType] = player
            isPlaying[soundType] = false
        }
    }
    
    // MARK: - Haptic Generator Preparation
    
    private func prepareHapticGenerators() {
        #if canImport(UIKit)
        selectionGenerator.prepare()
        notificationGenerator.prepare()
        lightImpactGenerator.prepare()
        #endif
    }
    
    // MARK: - Public Play Methods
    
    func play(_ type: SoundType) {
        guard isSoundEnabled else { return }
        
        // Debouncing: Check minimum delay
        let currentTime = Date().timeIntervalSince1970
        if let lastTime = lastPlayTime[type],
           currentTime - lastTime < type.minimumDelay {
            return
        }
        
        // Special rate limiting for letter clicks
        if type == .letterClick {
            letterClickCount += 1
            if letterClickCount > maxLetterClicksPerSecond {
                return
            }
            
            // Reset counter after 1 second
            letterClickResetTimer?.invalidate()
            letterClickResetTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                self?.letterClickCount = 0
            }
        }
        
        lastPlayTime[type] = currentTime
        
        // Play the actual sound
        playSoundWithAVPlayer(type)
        
        // Trigger haptic feedback
        triggerHaptic(for: type)
    }
    
    // MARK: - AVPlayer Playback
    
    private func playSoundWithAVPlayer(_ type: SoundType) {
        guard let player = audioPlayers[type] else { return }
        
        // Create a new player item for concurrent plays
        if let asset = audioAssets[type] {
            let newItem = AVPlayerItem(asset: asset)
            player.replaceCurrentItem(with: newItem)
        }
        
        player.seek(to: .zero) { [weak self] _ in
            player.play()
            self?.isPlaying[type] = true
            
            // Auto-stop tracking after estimated duration
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self?.isPlaying[type] = false
            }
        }
    }
    
    // MARK: - Haptic Feedback
    
    private func triggerHaptic(for type: SoundType) {
        guard isHapticEnabled else { return }
        
        // SwiftUI sensory feedback trigger (iOS 17+)
        lastTriggeredSound = type
        hapticTriggerID = UUID()
        
        // UIKit haptic feedback (legacy support)
        #if canImport(UIKit)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch type {
            case .letterClick:
                self.selectionGenerator.selectionChanged()
            case .correctGuess:
                self.notificationGenerator.notificationOccurred(.success)
            case .incorrectGuess:
                self.notificationGenerator.notificationOccurred(.warning)
            case .win:
                self.notificationGenerator.notificationOccurred(.success)
            case .lose:
                self.notificationGenerator.notificationOccurred(.error)
            case .hint:
                self.lightImpactGenerator.impactOccurred(intensity: 0.7)
            }
            
            // Re-prepare for next use
            switch type {
            case .letterClick:
                self.selectionGenerator.prepare()
            case .correctGuess, .incorrectGuess, .win, .lose:
                self.notificationGenerator.prepare()
            case .hint:
                self.lightImpactGenerator.prepare()
            }
        }
        #endif
    }
    
    // MARK: - Volume Control
    
    func updateVolume() {
        for (_, player) in audioPlayers {
            player.volume = volume
        }
    }
    
    // MARK: - Stop Functions
    
    func stopAllSounds() {
        for (_, player) in audioPlayers {
            player.pause()
            player.seek(to: .zero)
        }
        
        for key in isPlaying.keys {
            isPlaying[key] = false
        }
    }
    
    func stop(_ type: SoundType) {
        audioPlayers[type]?.pause()
        audioPlayers[type]?.seek(to: .zero)
        isPlaying[type] = false
    }
    
    // MARK: - Preference Updates
    
    func updateSoundEnabled(_ enabled: Bool) {
        isSoundEnabled = enabled
    }
    
    func updateHapticEnabled(_ enabled: Bool) {
        isHapticEnabled = enabled
    }
}
