import AVFoundation
import SwiftUI

/// SoundManager provides a centralized system for playing game sounds with Apple best practices
class SoundManager: ObservableObject {
    // MARK: - Singleton
    static let shared = SoundManager()
    
    // MARK: - Published Properties
    @Published var isSoundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isSoundEnabled, forKey: "isSoundEnabled")
        }
    }
    
    @Published var volume: Float {
        didSet {
            UserDefaults.standard.set(volume, forKey: "soundVolume")
            updateVolume()
        }
    }
    
    // MARK: - Sound Types
    enum SoundType: String, CaseIterable {
        case letterClick = "letter_click"
        case correctGuess = "correct_guess"
        case incorrectGuess = "incorrect_guess"
        case hint = "hint"
        case win = "win"
        case lose = "lose"
        
        var filename: String {
            return "\(rawValue).wav"
        }
    }
    
    // MARK: - Private Properties
    
    // Audio engine for high performance sound playback
    private var audioEngine: AVAudioEngine?
    private var audioPlayers: [SoundType: AVAudioPlayer] = [:]
    private var audioFiles: [SoundType: AVAudioFile] = [:]
    private var audioPlayerNodes: [SoundType: AVAudioPlayerNode] = [:]
    
    // Sound file status tracking
    private var soundsLoaded = false
    
    // Simple queue system to prevent sound overlaps
    private var isPlaying: [SoundType: Bool] = [:]
    private var shouldPlay: Bool {
        // Check system conditions
        #if os(iOS)
        return isSoundEnabled
        #else
        return isSoundEnabled
        #endif
    }
    
    // Debug flag
    private let debugMode = true
    
    // MARK: - Initialization
    
    private init() {
        // Load user preferences
        self.isSoundEnabled = UserDefaults.standard.bool(forKey: "isSoundEnabled")
        if UserDefaults.standard.object(forKey: "isSoundEnabled") == nil {
            // Default to enabled if preference doesn't exist
            self.isSoundEnabled = true
            UserDefaults.standard.set(true, forKey: "isSoundEnabled")
        }
        
        // Load volume settings
        self.volume = UserDefaults.standard.float(forKey: "soundVolume")
        if UserDefaults.standard.object(forKey: "soundVolume") == nil {
            // Default volume
            self.volume = 0.5
            UserDefaults.standard.set(0.5, forKey: "soundVolume")
        }
        
        // Setup audio session first
        setupAudioSession()
        
        // Initialize audio engine (but don't start it yet)
        initializeAudioEngine()
        
        // Preload sound files if available
        preloadSounds()
        
        // Start the audio engine only if we have loaded sounds
        if soundsLoaded {
            startAudioEngine()
        }
        
        // Register for interruptions
        registerForNotifications()
        
        if debugMode {
            printSoundSetupInfo()
        }
    }
    
    // MARK: - Public Methods
    
    /// Play a sound effect
    /// - Parameter type: The type of sound to play
    func play(_ type: SoundType) {
        // Debug
        if debugMode {
            print("Attempting to play sound: \(type.rawValue)")
            print("Sound enabled: \(shouldPlay), Already playing: \(isPlaying[type] ?? false)")
        }
        
        // Check if sound is enabled and if we're not already playing this sound
        guard shouldPlay, !(isPlaying[type] ?? false) else {
            if debugMode {
                if !shouldPlay {
                    print("Sound not played because sounds are disabled")
                } else {
                    print("Sound not played because it's already playing")
                }
            }
            return
        }
        
        // Use queue to safely access audio APIs
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            
            // Mark sound as playing
            self.isPlaying[type] = true
            
            // Debug
            if self.debugMode {
                print("Playing sound: \(type.rawValue)")
            }
            
            // Use simplified method until sound files are available
            if !self.soundsLoaded {
                // If no sounds are loaded, just log and handle completion
                if self.debugMode {
                    print("No sound files loaded - skipping playback for \(type.rawValue)")
                }
                
                // Simulate sound duration then mark as complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isPlaying[type] = false
                }
                return
            }
            
            // Determine which approach to use based on sound type
            if type == .win || type == .lose {
                // For longer sounds, use AVAudioPlayer
                self.playWithAudioPlayer(type)
            } else {
                // For short effects, use AVAudioPlayer for now
                self.playWithAudioPlayer(type)
            }
        }
    }
    
    /// Stop all sounds
    func stopAllSounds() {
        // Stop all audio players
        for player in audioPlayers.values {
            player.stop()
        }
        
        // Stop all player nodes
        for playerNode in audioPlayerNodes.values {
            playerNode.stop()
        }
        
        // Reset playing state
        for type in SoundType.allCases {
            isPlaying[type] = false
        }
    }
    
    /// Test all sounds - useful for debugging
    func testAllSounds() {
        print("Testing all sounds...")
        play(.letterClick)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.play(.correctGuess)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.play(.incorrectGuess)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.play(.hint)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            self.play(.win)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            self.play(.lose)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        #if os(iOS)
        do {
            // Configure audio session for game sounds
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            if debugMode {
                print("Audio session setup successful")
            }
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
        #endif
    }
    
    private func initializeAudioEngine() {
        // Initialize the audio engine
        audioEngine = AVAudioEngine()
        if debugMode {
            print("Audio engine initialized")
        }
    }
    
    private func preloadSounds() {
        var foundAnySound = false
        
        // Preload using AVAudioPlayer for simplicity
        for type in SoundType.allCases {
            if let player = createAudioPlayer(for: type) {
                audioPlayers[type] = player
                foundAnySound = true
            }
        }
        
        // Only if we found at least one sound, try to configure the audio engine
        if foundAnySound {
            soundsLoaded = true
            configureAudioEngine()
        } else {
            // Print clear message that no sounds are loaded
            print("WARNING: No sound files found. Add .wav files to the project with names matching: \(SoundType.allCases.map { $0.rawValue }.joined(separator: ", "))")
        }
    }
    
    private func createAudioPlayer(for type: SoundType) -> AVAudioPlayer? {
        // Try multiple paths to find the sound
        var url: URL?
        
        // First try with path directly
        if let path = Bundle.main.path(forResource: type.rawValue, ofType: "wav") {
            url = URL(fileURLWithPath: path)
            if debugMode {
                print("Found sound directly: \(type.rawValue).wav")
            }
        }
        // Then try in Sounds directory
        else if let path = Bundle.main.path(forResource: type.rawValue, ofType: "wav", inDirectory: "Sounds") {
            url = URL(fileURLWithPath: path)
            if debugMode {
                print("Found sound from Sounds directory: \(type.rawValue).wav")
            }
        }
        // Finally check if there's a lowercase version
        else if let path = Bundle.main.path(forResource: type.rawValue.lowercased(), ofType: "wav") {
            url = URL(fileURLWithPath: path)
            if debugMode {
                print("Found sound with lowercase name: \(type.rawValue.lowercased()).wav")
            }
        } else {
            if debugMode {
                print("Sound file not found: \(type.rawValue).wav")
            }
            return nil
        }
        
        // Create player if we found a URL
        if let url = url {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                player.volume = volume
                return player
            } catch {
                print("Failed to create audio player for \(type.rawValue): \(error.localizedDescription)")
                return nil
            }
        }
        
        return nil
    }
    
    private func configureAudioEngine() {
        guard let engine = audioEngine else {
            print("Audio engine not initialized")
            return
        }
        
        // Try to set up audio files for engine
        for type in SoundType.allCases {
            var url: URL?
            
            // Try multiple paths
            if let foundUrl = Bundle.main.url(forResource: type.rawValue, withExtension: "wav") {
                url = foundUrl
            } else if let foundUrl = Bundle.main.url(forResource: type.rawValue, withExtension: "wav", subdirectory: "Sounds") {
                url = foundUrl
            } else if let foundUrl = Bundle.main.url(forResource: type.rawValue.lowercased(), withExtension: "wav") {
                url = foundUrl
            }
            
            if let url = url {
                do {
                    let file = try AVAudioFile(forReading: url)
                    audioFiles[type] = file
                    
                    // Create player node
                    let playerNode = AVAudioPlayerNode()
                    engine.attach(playerNode)
                    
                    // Connect to main mixer
                    engine.connect(playerNode, to: engine.mainMixerNode, format: file.processingFormat)
                    
                    // Store player node
                    audioPlayerNodes[type] = playerNode
                    
                    if debugMode {
                        print("Added audio file to engine: \(type.rawValue)")
                    }
                } catch {
                    print("Failed to preload audio file \(type.rawValue): \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func startAudioEngine() {
        guard let engine = audioEngine, !audioPlayerNodes.isEmpty else {
            if debugMode {
                print("Audio engine not started - no player nodes configured")
            }
            return
        }
        
        // Start the audio engine
        do {
            try engine.start()
            if debugMode {
                print("Audio engine started successfully")
            }
        } catch {
            print("Failed to start audio engine: \(error.localizedDescription)")
        }
    }
    
    private func playWithAudioPlayer(_ type: SoundType) {
        if let player = audioPlayers[type] {
            // Debug
            if debugMode {
                print("Playing sound with AVAudioPlayer: \(type.rawValue)")
            }
            
            // Reset player
            player.currentTime = 0
            player.volume = volume
            
            // Play sound
            player.play()
            
            // Use delayed execution to simulate completion handler
            // This is a simple approach since AVAudioPlayer uses delegate methods instead
            let duration = player.duration
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) { [weak self] in
                if self?.debugMode == true {
                    print("Sound completed: \(type.rawValue)")
                }
                self?.isPlaying[type] = false
            }
        } else {
            print("⚠️ No audio player found for: \(type.rawValue)")
            self.isPlaying[type] = false
        }
    }
    
    private func playWithAudioEngine(_ type: SoundType) {
        guard let engine = audioEngine, let playerNode = audioPlayerNodes[type],
              let file = audioFiles[type] else {
            // Fallback to AVAudioPlayer if engine setup failed
            if debugMode {
                print("Falling back to AVAudioPlayer for: \(type.rawValue)")
            }
            playWithAudioPlayer(type)
            return
        }
        
        if debugMode {
            print("Playing sound with AVAudioEngine: \(type.rawValue)")
        }
        
        // Set volume
        playerNode.volume = volume
        
        // Schedule file to play from beginning
        do {
            // Schedule buffer to play
            try playerNode.scheduleFile(file, at: nil) { [weak self] in
                // Mark as no longer playing when complete
                DispatchQueue.main.async {
                    if self?.debugMode == true {
                        print("Sound completed in audio engine: \(type.rawValue)")
                    }
                    self?.isPlaying[type] = false
                }
            }
            
            // Start player node if needed
            if !playerNode.isPlaying {
                playerNode.play()
            }
        } catch {
            print("Failed to schedule audio file: \(error)")
            isPlaying[type] = false
        }
    }
    
    private func updateVolume() {
        // Update volume for all players
        for player in audioPlayers.values {
            player.volume = volume
        }
        
        // Update volume for all player nodes
        for playerNode in audioPlayerNodes.values {
            playerNode.volume = volume
        }
    }
    
    private func registerForNotifications() {
        #if os(iOS)
        // Register for interruptions (calls, Siri, etc.)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        // Register for route changes (headphones, bluetooth)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        #endif
    }
    
    // Print debug info
    private func printSoundSetupInfo() {
        print("=== Sound Manager Initialization ===")
        print("Sound enabled: \(isSoundEnabled)")
        print("Volume: \(volume)")
        print("Sounds loaded: \(soundsLoaded)")
        
        print("\nPreloaded Audio Players:")
        if audioPlayers.isEmpty {
            print("No audio players loaded")
        } else {
            for (type, _) in audioPlayers {
                print("- \(type.rawValue): loaded")
            }
        }
        
        print("\nPreloaded Audio Files:")
        if audioFiles.isEmpty {
            print("No audio files loaded")
        } else {
            for (type, _) in audioFiles {
                print("- \(type.rawValue): loaded")
            }
        }
        
        print("\nAvailable Sound Types:")
        for type in SoundType.allCases {
            print("- \(type.rawValue)")
        }
        
        print("==================================")
    }
    
    #if os(iOS)
    @objc private func handleInterruption(notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        if type == .began {
            // Interruption began - pause all sounds
            stopAllSounds()
        } else if type == .ended {
            // Interruption ended - check if we should resume
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt,
               AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                // Resume audio engine
                do {
                    try AVAudioSession.sharedInstance().setActive(true)
                    startAudioEngine()
                } catch {
                    print("Failed to restart audio after interruption: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        // Restart engine on route changes to handle Bluetooth switches
        startAudioEngine()
    }
    #endif
}


