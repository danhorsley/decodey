import AVFoundation
import SwiftUI

// MARK: - Sound Manager with Haptic Support
/// Manages all sound effects and music for the game using AVAudioEngine for low latency
class SoundManager: ObservableObject {
    // Singleton
    static let shared = SoundManager()
    
    // Sound types matching your M4A file names (with underscores)
    enum SoundType: String, CaseIterable {
        case letterClick = "letter_click"        // UI feedback
        case correctGuess = "correct_guess"      // Correct guess
        case incorrectGuess = "incorrect_guess"  // Wrong guess
        case win = "win"                         // Game won
        case lose = "lose"                       // Game lost
        case hint = "hint"                       // Hint used
        
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
    
    // NEW: Haptic feedback setting
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
    
    // NEW: Track haptic triggers for SwiftUI's sensoryFeedback
    @Published var hapticTriggerID = UUID()
    @Published var lastTriggeredSound: SoundType? = nil
    
    // AVAudioEngine for low-latency playback
    private var audioEngine: AVAudioEngine?
    private var audioPlayerNodes: [SoundType: AVAudioPlayerNode] = [:]
    private var audioFiles: [SoundType: AVAudioFile] = [:]
    
    // Fallback to AVAudioPlayer if engine fails
    private var audioPlayers: [SoundType: AVAudioPlayer] = [:]
    
    // Track what's playing
    private var isPlaying: [SoundType: Bool] = [:]
    
    // Debug mode
    private let debugMode = false
    
    // Load state
    private var soundsLoaded = false
    
    private init() {
        // Load preferences
        isSoundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        isHapticEnabled = UserDefaults.standard.object(forKey: "hapticEnabled") as? Bool ?? true
        volume = UserDefaults.standard.object(forKey: "soundVolume") as? Float ?? 0.7
        
        // Set up the audio
        setupAudio()
    }
    
    // MARK: - Audio Setup (keeping your existing implementation)
    
    private func setupAudio() {
        #if os(iOS)
        // Configure audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Failed to configure audio session: \(error.localizedDescription)")
        }
        #endif
        
        // Initialize audio engine
        audioEngine = AVAudioEngine()
        
        // Preload all sounds
        for soundType in SoundType.allCases {
            preloadSound(soundType)
        }
        
        // Mark as loaded
        soundsLoaded = true
        
        // Start the audio engine
        startAudioEngine()
        
        // Register for notifications
        registerForNotifications()
        
        if debugMode {
            printSoundSetupInfo()
        }
    }
    
    // MARK: - Playback with Haptic Support
    
    func play(_ type: SoundType) {
        guard isSoundEnabled else {
            // Even if sound is disabled, we might still want haptics
            if isHapticEnabled {
                triggerHaptic(for: type)
            }
            return
        }
        
        // Trigger haptic feedback
        if isHapticEnabled {
            triggerHaptic(for: type)
        }
        
        // Don't play the same sound if it's already playing (prevents overlap)
        if isPlaying[type] == true && type != .letterClick {
            return
        }
        
        isPlaying[type] = true
        
        // Try AVAudioEngine first for lowest latency
        if let engine = audioEngine, engine.isRunning,
           let playerNode = audioPlayerNodes[type],
           let file = audioFiles[type] {
            playWithEngine(playerNode: playerNode, file: file, type: type)
        } else {
            // Fallback to AVAudioPlayer
            playWithAudioPlayer(type)
        }
    }
    
    // NEW: Trigger haptic feedback
    private func triggerHaptic(for type: SoundType) {
        DispatchQueue.main.async { [weak self] in
            self?.lastTriggeredSound = type
            self?.hapticTriggerID = UUID() // Force update for sensoryFeedback
        }
    }
    
    // Keep all your existing methods unchanged...
    private func playWithAudioPlayer(_ type: SoundType) {
        guard let player = audioPlayers[type] else {
            if debugMode {
                print("⚠️ No audio player for: \(type.rawValue)")
            }
            isPlaying[type] = false
            return
        }
        
        if debugMode {
            print("🔊 Playing with AVAudioPlayer: \(type.rawValue)")
        }
        
        // Reset to beginning and play
        player.currentTime = 0
        player.volume = volume
        player.play()
        
        // Mark as not playing after estimated duration
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.isPlaying[type] = false
        }
    }
    
    private func playWithEngine(playerNode: AVAudioPlayerNode, file: AVAudioFile, type: SoundType) {
        guard let engine = audioEngine, engine.isRunning else {
            if debugMode {
                print("⚠️ Engine not running, falling back to AVAudioPlayer")
            }
            playWithAudioPlayer(type)
            return
        }
        
        if debugMode {
            print("🔊 Playing with AVAudioEngine: \(type.rawValue)")
        }
        
        // Stop if already playing
        if playerNode.isPlaying {
            playerNode.stop()
        }
        
        // Set volume
        playerNode.volume = volume
        
        // Schedule file to play
        do {
            playerNode.scheduleFile(file, at: nil) { [weak self] in
                DispatchQueue.main.async {
                    self?.isPlaying[type] = false
                    if self?.debugMode == true {
                        print("✅ Finished playing: \(type.rawValue)")
                    }
                }
            }
            
            // Start playing
            if !playerNode.isPlaying {
                playerNode.play()
            }
        } catch {
            print("❌ Failed to schedule audio file: \(error)")
            isPlaying[type] = false
            // Fallback
            playWithAudioPlayer(type)
        }
    }
    
    // Keep all other existing methods unchanged...
    private func preloadSound(_ type: SoundType) {
        // Finding sound file with multiple attempts
        var url: URL? = nil
        
        // Try multiple paths and extensions
        let extensions = ["m4a", "wav", "mp3", "caf"] // M4A first, then fallbacks
        let names = [type.rawValue, type.rawValue.lowercased()]
        
        for ext in extensions {
            for name in names {
                if url == nil {
                    url = Bundle.main.url(forResource: name, withExtension: ext)
                }
                if url == nil {
                    url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Sounds")
                }
            }
        }
        
        guard let soundUrl = url else {
            print("⚠️ Sound file not found: \(type.rawValue)")
            return
        }
        
        // Preload for AVAudioPlayer (fallback)
        do {
            let player = try AVAudioPlayer(contentsOf: soundUrl)
            player.prepareToPlay()
            player.volume = volume
            audioPlayers[type] = player
            
            if debugMode {
                print("✅ Loaded sound: \(type.rawValue) from \(soundUrl.lastPathComponent)")
            }
        } catch {
            print("❌ Failed to load sound \(type.rawValue): \(error.localizedDescription)")
        }
        
        // Also prepare for AVAudioEngine
        if let engine = audioEngine {
            do {
                let file = try AVAudioFile(forReading: soundUrl)
                audioFiles[type] = file
                
                // Create player node
                let playerNode = AVAudioPlayerNode()
                engine.attach(playerNode)
                
                // Connect to main mixer
                engine.connect(playerNode, to: engine.mainMixerNode, format: file.processingFormat)
                
                // Store player node
                audioPlayerNodes[type] = playerNode
                
                if debugMode {
                    print("✅ Added to audio engine: \(type.rawValue)")
                }
            } catch {
                print("⚠️ Failed to add \(type.rawValue) to audio engine: \(error.localizedDescription)")
            }
        }
    }
    
    private func startAudioEngine() {
        guard let engine = audioEngine, !audioPlayerNodes.isEmpty else {
            if debugMode {
                print("⚠️ Audio engine not started - no player nodes attached")
            }
            return
        }
        
        do {
            try engine.start()
            if debugMode {
                print("✅ Audio engine started with \(audioPlayerNodes.count) nodes")
            }
        } catch {
            print("❌ Failed to start audio engine: \(error.localizedDescription)")
            // Will fall back to AVAudioPlayer
        }
    }
    
    func stopAllSounds() {
        // Stop all AVAudioPlayers
        for player in audioPlayers.values {
            player.stop()
        }
        
        // Stop all engine nodes
        for node in audioPlayerNodes.values {
            node.stop()
        }
        
        // Clear playing states
        isPlaying.removeAll()
        
        if debugMode {
            print("🔇 All sounds stopped")
        }
    }
    
    private func updateVolume() {
        // Update all player volumes
        for player in audioPlayers.values {
            player.volume = volume
        }
        
        // Update all node volumes
        for node in audioPlayerNodes.values {
            node.volume = volume
        }
    }
    
    // Keep all notification handling unchanged...
    private func registerForNotifications() {
        #if os(iOS)
        // Handle interruptions (phone calls, etc.)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        // Handle route changes (headphones, bluetooth)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        #endif
    }
    
    #if os(iOS)
    @objc private func handleInterruption(notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        if type == .began {
            // Pause during interruption
            stopAllSounds()
        } else if type == .ended {
            // Resume after interruption
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt,
               AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                do {
                    try AVAudioSession.sharedInstance().setActive(true)
                    startAudioEngine()
                } catch {
                    print("❌ Failed to restart audio after interruption: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        // Restart engine on route changes
        startAudioEngine()
    }
    #endif
    
    // Debug info method unchanged...
    private func printSoundSetupInfo() {
        print("=== Sound Manager Debug Info ===")
        print("Sound enabled: \(isSoundEnabled)")
        print("Haptic enabled: \(isHapticEnabled)")
        print("Volume: \(volume)")
        print("Sounds loaded: \(soundsLoaded)")
        
        print("\nAudio Players:")
        for (type, _) in audioPlayers {
            print("  ✅ \(type.rawValue)")
        }
        
        print("\nAudio Engine Nodes:")
        for (type, _) in audioPlayerNodes {
            print("  ✅ \(type.rawValue)")
        }
        
        print("\nAudio Files:")
        for (type, _) in audioFiles {
            print("  ✅ \(type.rawValue)")
        }
        
        if let engine = audioEngine {
            print("\nEngine running: \(engine.isRunning)")
        }
        
        print("================================")
    }
}

// Make SoundType Identifiable for SwiftUI
extension SoundManager.SoundType: Identifiable {
    var id: String {
        return self.rawValue
    }
}

// MARK: - SwiftUI View Modifier for Haptic Integration
struct SoundAndHapticModifier: ViewModifier {
    @EnvironmentObject var soundManager: SoundManager
    
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .sensoryFeedback(
                    trigger: soundManager.hapticTriggerID
                ) { _, _ in
                    guard let soundType = soundManager.lastTriggeredSound,
                          soundManager.isHapticEnabled else {
                        return .none
                    }
                    return soundType.sensoryFeedback
                }
        } else {
            content
        }
    }
}

// Extension to apply the modifier easily
extension View {
    func withSoundAndHaptics() -> some View {
        self.modifier(SoundAndHapticModifier())
    }
}
