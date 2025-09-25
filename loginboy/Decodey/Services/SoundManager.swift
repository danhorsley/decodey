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
    
    // Sound types matching your M4A file names (with underscores)
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
        
        // Map to sensory feedback for iOS 17+
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
    }
    
    // Properties
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
    private let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    #endif
    
    // Track if sounds have been loaded
    private var soundsLoaded = false
    
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
            // Silent failure in production
            #if DEBUG
            print("Audio session setup failed: \(error)")
            #endif
        }
        #endif
    }
    
    // MARK: - Sound Loading
    
    private func loadSounds() {
        for soundType in SoundType.allCases {
            if let soundURL = Bundle.main.url(forResource: soundType.rawValue, withExtension: "m4a") {
                // Create AVAsset for loading
                let asset = AVAsset(url: soundURL)
                audioAssets[soundType] = asset
                
                // Create AVPlayer for each sound
                let playerItem = AVPlayerItem(asset: asset)
                let player = AVPlayer(playerItem: playerItem)
                player.volume = volume
                
                // Pre-load the asset
                Task {
                    do {
                        _ = try await asset.load(.duration, .tracks)
                    } catch {
                        // Silent failure in production
                        #if DEBUG
                        print("Failed to preload \(soundType.rawValue): \(error)")
                        #endif
                    }
                }
                
                audioPlayers[soundType] = player
            }
        }
        
        soundsLoaded = true
    }
    
    // MARK: - Haptic Setup
    
    private func prepareHapticGenerators() {
        #if canImport(UIKit)
        // Prepare all generators for immediate use
        selectionGenerator.prepare()
        notificationGenerator.prepare()
        lightImpactGenerator.prepare()
        mediumImpactGenerator.prepare()
        heavyImpactGenerator.prepare()
        #endif
    }
    
    // MARK: - Playback with Debouncing and Rate Limiting
    
    func play(_ type: SoundType) {
        // Check debouncing
        let now = Date().timeIntervalSince1970
        if let lastTime = lastPlayTime[type] {
            let timeSinceLastPlay = now - lastTime
            if timeSinceLastPlay < type.minimumDelay {
                return
            }
        }
        
        // Special rate limiting for letter clicks
        if type == .letterClick {
            letterClickCount += 1
            
            // Reset counter after 1 second
            letterClickResetTimer?.invalidate()
            letterClickResetTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                self?.letterClickCount = 0
            }
            
            // Skip if we've hit the rate limit
            if letterClickCount > maxLetterClicksPerSecond {
                return
            }
        }
        
        // Update last play time
        lastPlayTime[type] = now
        
        // Trigger haptic feedback first (even if sound is disabled)
        if isHapticEnabled {
            triggerHaptic(for: type)
        }
        
        guard isSoundEnabled else { return }
        
        // Don't play the same sound if it's already playing (except letterClick)
        if isPlaying[type] == true && type != .letterClick {
            return
        }
        
        // Play the sound using AVPlayer
        playWithAVPlayer(type)
    }
    
    private func playWithAVPlayer(_ type: SoundType) {
        guard let player = audioPlayers[type],
              let asset = audioAssets[type] else {
            return
        }
        
        isPlaying[type] = true
        
        // Create new player item and replace current one
        let playerItem = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: playerItem)
        player.volume = volume
        
        // Seek to beginning and play
        player.seek(to: .zero) { [weak self] _ in
            player.play()
            
            // Mark as not playing after expected duration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.isPlaying[type] = false
            }
        }
    }
    
    private func triggerHaptic(for type: SoundType) {
        // iOS 17+ SwiftUI approach
        if #available(iOS 17.0, *) {
            // Update published properties to trigger SwiftUI sensoryFeedback
            DispatchQueue.main.async { [weak self] in
                self?.lastTriggeredSound = type
                self?.hapticTriggerID = UUID()
            }
        }
        
        // iOS 16 and below - direct UIKit approach
        #if canImport(UIKit)
        DispatchQueue.main.async { [weak self] in
            guard self?.isHapticEnabled == true else { return }
            
            switch type {
            case .letterClick:
                self?.selectionGenerator.selectionChanged()
            case .correctGuess:
                self?.notificationGenerator.notificationOccurred(.success)
            case .incorrectGuess:
                self?.notificationGenerator.notificationOccurred(.warning)
            case .win:
                self?.notificationGenerator.notificationOccurred(.success)
            case .lose:
                self?.notificationGenerator.notificationOccurred(.error)
            case .hint:
                self?.lightImpactGenerator.impactOccurred(intensity: 0.7)
            }
            
            // Re-prepare for next use
            switch type {
            case .letterClick:
                self?.selectionGenerator.prepare()
            case .correctGuess, .incorrectGuess, .win, .lose:
                self?.notificationGenerator.prepare()
            case .hint:
                self?.lightImpactGenerator.prepare()
            }
        }
        #endif
    }
    
    // MARK: - Volume Control
    
    func updateVolume() {
        // Update all AVPlayer volumes
        for (_, player) in audioPlayers {
            player.volume = volume
        }
    }
    
    // MARK: - Stop Functions
    
    func stopAllSounds() {
        // Pause all AVPlayers
        for (_, player) in audioPlayers {
            player.pause()
            player.seek(to: .zero)
        }
        
        // Clear playing states
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
