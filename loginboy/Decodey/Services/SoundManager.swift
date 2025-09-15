import AVFoundation
import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Sound Manager with Full Haptic Support
/// Manages all sound effects and haptic feedback for the game
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
        
        // Map to sensory feedback for iOS 17+ (keeping as backup)
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
            print("🔊 Sound enabled: \(isSoundEnabled)")
        }
    }
    
    @Published var isHapticEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isHapticEnabled, forKey: "hapticEnabled")
            print("📳 Haptic enabled: \(isHapticEnabled)")
        }
    }
    
    @Published var volume: Float = 0.7 {
        didSet {
            UserDefaults.standard.set(volume, forKey: "soundVolume")
            updateVolume()
        }
    }
    
    // Track haptic triggers for SwiftUI's sensoryFeedback (backup method)
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
    
    // Haptic generators (iOS only) - pre-initialized for better performance
    #if os(iOS)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    #endif
    
    // Debug mode - set to true for troubleshooting
    private let debugMode = true
    
    // Load state
    private var soundsLoaded = false
    private var audioSessionConfigured = false
    
    private init() {
        // Load preferences
        isSoundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        isHapticEnabled = UserDefaults.standard.object(forKey: "hapticEnabled") as? Bool ?? true
        volume = UserDefaults.standard.object(forKey: "soundVolume") as? Float ?? 0.7
        
        print("🎮 SoundManager initializing...")
        print("   Sound: \(isSoundEnabled), Haptic: \(isHapticEnabled), Volume: \(volume)")
        
        // Set up the audio
        setupAudio()
        
        // Prepare haptic generators
        prepareHapticGenerators()
    }
    
    // MARK: - Audio Setup
    
    private func setupAudio() {
        print("\n🎵 Setting up audio system...")
        
        // First, verify audio files exist
        if !verifyAudioFiles() {
            print("❌ Critical: Audio files missing! Check bundle resources.")
        }
        
        #if os(iOS)
        // Configure audio session for iOS
        configureAudioSession()
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
    
    #if os(iOS)
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            
            // Use .playback to ignore silent switch, with mixWithOthers to be polite to other apps
            // This is KEY for iPhone - .ambient respects the silent switch!
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            
            // Activate the session
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            
            audioSessionConfigured = true
            
            print("✅ iOS Audio Session configured successfully")
            print("   Category: \(session.category.rawValue)")
            print("   Mode: \(session.mode.rawValue)")
            print("   Output Volume: \(session.outputVolume)")
            print("   Output Port: \(session.currentRoute.outputs.first?.portType.rawValue ?? "none")")
            print("   Other audio playing: \(session.isOtherAudioPlaying)")
            
        } catch {
            print("❌ Failed to configure audio session: \(error.localizedDescription)")
            print("   Error details: \(error)")
            audioSessionConfigured = false
        }
    }
    #endif
    
    private func verifyAudioFiles() -> Bool {
        print("\n📁 Verifying audio files in bundle...")
        var allFound = true
        
        for soundType in SoundType.allCases {
            if let url = Bundle.main.url(forResource: soundType.rawValue, withExtension: "m4a") {
                do {
                    let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
                    let fileSize = resourceValues.fileSize ?? 0
                    print("   ✅ \(soundType.rawValue).m4a - \(fileSize) bytes")
                } catch {
                    print("   ⚠️ \(soundType.rawValue).m4a - found but can't read size")
                }
            } else {
                print("   ❌ \(soundType.rawValue).m4a - MISSING!")
                allFound = false
            }
        }
        
        return allFound
    }
    
    private func preloadSound(_ type: SoundType) {
        guard let soundUrl = Bundle.main.url(forResource: type.rawValue, withExtension: "m4a") else {
            print("❌ Cannot find sound file: \(type.rawValue).m4a")
            return
        }
        
        // Prepare AVAudioPlayer (fallback)
        do {
            let player = try AVAudioPlayer(contentsOf: soundUrl)
            player.prepareToPlay()
            player.volume = volume
            audioPlayers[type] = player
            
            if debugMode {
                print("   ✅ Loaded \(type.rawValue) into AVAudioPlayer (duration: \(player.duration)s)")
            }
        } catch {
            print("   ❌ Failed to load \(type.rawValue): \(error.localizedDescription)")
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
                    print("   ✅ Added \(type.rawValue) to audio engine")
                }
            } catch {
                print("   ⚠️ Failed to add \(type.rawValue) to engine: \(error.localizedDescription)")
            }
        }
    }
    
    private func startAudioEngine() {
        guard let engine = audioEngine else {
            print("⚠️ No audio engine to start")
            return
        }
        
        guard !audioPlayerNodes.isEmpty else {
            print("⚠️ Audio engine has no player nodes attached")
            return
        }
        
        do {
            try engine.start()
            print("✅ Audio engine started with \(audioPlayerNodes.count) nodes")
        } catch {
            print("❌ Failed to start audio engine: \(error.localizedDescription)")
            print("   Will fall back to AVAudioPlayer for playback")
        }
    }
    
    // MARK: - Haptic Setup
    
    private func prepareHapticGenerators() {
        #if os(iOS)
        // Prepare all generators for immediate use
        selectionGenerator.prepare()
        notificationGenerator.prepare()
        lightImpactGenerator.prepare()
        mediumImpactGenerator.prepare()
        heavyImpactGenerator.prepare()
        
        print("📳 Haptic generators prepared")
        #endif
    }
    
    // MARK: - Playback with Haptic Support
    
    func play(_ type: SoundType) {
        if debugMode {
            print("\n🎮 Play requested: \(type.rawValue)")
            print("   Sound enabled: \(isSoundEnabled), Haptic enabled: \(isHapticEnabled)")
        }
        
        // Trigger haptic feedback first (even if sound is disabled)
        if isHapticEnabled {
            triggerHaptic(for: type)
        }
        
        guard isSoundEnabled else {
            if debugMode {
                print("   Sound disabled by user preference")
            }
            return
        }
        
        // Don't play the same sound if it's already playing (prevents overlap)
        if isPlaying[type] == true && type != .letterClick {
            if debugMode {
                print("   Already playing, skipping")
            }
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
    
    private func triggerHaptic(for type: SoundType) {
        #if os(iOS)
        // Use UIKit haptics directly for reliability
        DispatchQueue.main.async { [weak self] in
            guard self?.isHapticEnabled == true else { return }
            
            switch type {
            case .letterClick:
                self?.selectionGenerator.selectionChanged()
                if self?.debugMode == true {
                    print("   📳 Haptic: selection")
                }
                
            case .correctGuess:
                self?.notificationGenerator.notificationOccurred(.success)
                if self?.debugMode == true {
                    print("   📳 Haptic: success")
                }
                
            case .incorrectGuess:
                self?.notificationGenerator.notificationOccurred(.warning)
                if self?.debugMode == true {
                    print("   📳 Haptic: warning")
                }
                
            case .win:
                self?.notificationGenerator.notificationOccurred(.success)
                if self?.debugMode == true {
                    print("   📳 Haptic: win (success)")
                }
                
            case .lose:
                self?.notificationGenerator.notificationOccurred(.error)
                if self?.debugMode == true {
                    print("   📳 Haptic: error")
                }
                
            case .hint:
                self?.lightImpactGenerator.impactOccurred(intensity: 0.7)
                if self?.debugMode == true {
                    print("   📳 Haptic: light impact")
                }
            }
            
            // Re-prepare the generator for next use
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
        
        // Also update SwiftUI state for any sensoryFeedback modifiers (backup)
        DispatchQueue.main.async { [weak self] in
            self?.lastTriggeredSound = type
            self?.hapticTriggerID = UUID()
        }
    }
    
    private func playWithEngine(playerNode: AVAudioPlayerNode, file: AVAudioFile, type: SoundType) {
        if debugMode {
            print("   🔊 Playing with AVAudioEngine: \(type.rawValue)")
        }
        
        // Schedule the buffer
        playerNode.scheduleFile(file, at: nil) { [weak self] in
            DispatchQueue.main.async {
                self?.isPlaying[type] = false
            }
        }
        
        // Play
        playerNode.play()
    }
    
    private func playWithAudioPlayer(_ type: SoundType) {
        guard let player = audioPlayers[type] else {
            if debugMode {
                print("   ⚠️ No audio player for: \(type.rawValue)")
            }
            isPlaying[type] = false
            return
        }
        
        if debugMode {
            print("   🔊 Playing with AVAudioPlayer: \(type.rawValue)")
        }
        
        // Reset to beginning and play
        player.currentTime = 0
        player.volume = volume
        let success = player.play()
        
        if debugMode {
            print("   Play result: \(success ? "✅" : "❌")")
        }
        
        // Mark as not playing after estimated duration
        DispatchQueue.main.asyncAfter(deadline: .now() + player.duration + 0.1) { [weak self] in
            self?.isPlaying[type] = false
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
        
        print("🔇 All sounds stopped")
    }
    
    private func updateVolume() {
        // Update all player volumes
        for player in audioPlayers.values {
            player.volume = volume
        }
        
        // Update engine main mixer volume
        audioEngine?.mainMixerNode.outputVolume = volume
        
        print("🔊 Volume updated to: \(volume)")
    }
    
    // MARK: - Notification Handlers
    
    private func registerForNotifications() {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
        print("📡 Registered for iOS audio notifications")
        #endif
    }
    
    #if os(iOS)
    @objc private func handleInterruption(notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        print("🔔 Audio interruption: \(type == .began ? "began" : "ended")")
        
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
                    print("   ✅ Resumed after interruption")
                } catch {
                    print("   ❌ Failed to resume: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        print("🔔 Audio route changed: \(reason)")
        
        // Restart engine on significant route changes
        if reason == .newDeviceAvailable || reason == .oldDeviceUnavailable {
            startAudioEngine()
        }
    }
    #endif
    
    // MARK: - Testing & Debugging
    
    func testAudioAndHaptics() {
        print("\n" + String(repeating: "=", count: 50))
        print("🧪 AUDIO & HAPTIC SYSTEM TEST")
        print(String(repeating: "=", count: 50))
        
        #if os(iOS)
        // Test 1: Check iOS audio session
        print("\n📱 iOS Audio Session:")
        let session = AVAudioSession.sharedInstance()
        print("   Category: \(session.category.rawValue)")
        print("   Mode: \(session.mode.rawValue)")
        print("   Is Active: \(audioSessionConfigured)")
        print("   Output Volume: \(session.outputVolume)")
        print("   Route: \(session.currentRoute.outputs.first?.portName ?? "none")")
        print("   Port Type: \(session.currentRoute.outputs.first?.portType.rawValue ?? "none")")
        
        // Test 2: Settings check
        print("\n⚙️ Settings:")
        print("   Sound Enabled: \(isSoundEnabled)")
        print("   Haptic Enabled: \(isHapticEnabled)")
        print("   Volume: \(volume)")
        
        // Test 3: File check
        print("\n📁 Audio Files:")
        for soundType in SoundType.allCases {
            if Bundle.main.url(forResource: soundType.rawValue, withExtension: "m4a") != nil {
                print("   ✅ \(soundType.rawValue).m4a")
            } else {
                print("   ❌ \(soundType.rawValue).m4a MISSING!")
            }
        }
        
        // Test 4: Try direct playback
        print("\n🔊 Direct Playback Test:")
        if let url = Bundle.main.url(forResource: SoundType.letterClick.rawValue, withExtension: "m4a") {
            do {
                let testPlayer = try AVAudioPlayer(contentsOf: url)
                testPlayer.prepareToPlay()
                testPlayer.volume = 1.0
                let played = testPlayer.play()
                print("   AVAudioPlayer test: \(played ? "✅ Playing" : "❌ Failed")")
                if played {
                    print("   Duration: \(testPlayer.duration) seconds")
                }
            } catch {
                print("   ❌ Error: \(error)")
            }
        }
        
        // Test 5: Test haptics
        print("\n📳 Haptic Test:")
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
        print("   Heavy impact triggered ✅")
        
        #else
        print("\n💻 macOS Audio Test:")
        print("   Audio Engine: \(audioEngine?.isRunning == true ? "✅ Running" : "❌ Not running")")
        print("   Players loaded: \(audioPlayers.count)")
        print("   Engine nodes: \(audioPlayerNodes.count)")
        #endif
        
        // Test 6: Try the actual play method
        print("\n🎮 Full System Test:")
        print("   Playing letterClick sound with haptics...")
        play(.letterClick)
        
        print("\n" + String(repeating: "=", count: 50))
        print("🧪 TEST COMPLETE - Check above for any ❌ marks")
        print(String(repeating: "=", count: 50) + "\n")
    }
    
    private func printSoundSetupInfo() {
        print("\n=== Sound Manager Setup Info ===")
        print("Sound enabled: \(isSoundEnabled)")
        print("Haptic enabled: \(isHapticEnabled)")
        print("Volume: \(volume)")
        print("Sounds loaded: \(soundsLoaded)")
        
        print("\nAudio Players: \(audioPlayers.count)")
        for (type, player) in audioPlayers {
            print("  ✅ \(type.rawValue) - duration: \(player.duration)s")
        }
        
        print("\nAudio Engine Nodes: \(audioPlayerNodes.count)")
        for (type, _) in audioPlayerNodes {
            print("  ✅ \(type.rawValue)")
        }
        
        if let engine = audioEngine {
            print("\nEngine running: \(engine.isRunning)")
            print("Engine output volume: \(engine.mainMixerNode.outputVolume)")
        }
        
        print("================================\n")
    }
}

// MARK: - SwiftUI View Modifier (keeping for compatibility)
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

extension View {
    func withSoundAndHaptics() -> some View {
        self.modifier(SoundAndHapticModifier())
    }
}

// Make SoundType Identifiable for SwiftUI
extension SoundManager.SoundType: Identifiable {
    var id: String {
        return self.rawValue
    }
}
