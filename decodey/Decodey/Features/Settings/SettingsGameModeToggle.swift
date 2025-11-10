// SettingsGameModeToggle.swift
// Decodey
//
// Game mode selection toggle for Settings view

import SwiftUI

// Game Mode enum to add to your SettingsState class
enum GameMode: String, CaseIterable {
    case classic = "Classic"
    case timePressure = "Time Pressure"
    
    var description: String {
        switch self {
        case .classic:
            return "Traditional gameplay with hints"
        case .timePressure:
            return "Fast-paced with auto-revealing letters"
        }
    }
    
    var icon: String {
        switch self {
        case .classic:
            return "puzzlepiece.fill"
        case .timePressure:
            return "timer"
        }
    }
}

// NOTE: Add this property to your actual SettingsState class:
// @Published var gameMode: GameMode = .classic

// Settings View Component for Game Mode Selection
struct GameModeSettingsView: View {
    @EnvironmentObject var settingsState: SettingsState
    @Namespace private var animation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            Label("Game Mode", systemImage: "gamecontroller.fill")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Mode selector
            HStack(spacing: 12) {
                ForEach(GameMode.allCases, id: \.self) { mode in
                    GameModeButton(
                        mode: mode,
                        isSelected: settingsState.gameMode == mode,
                        namespace: animation
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            settingsState.gameMode = mode
                            saveGameModePreference(mode)
                        }
                    }
                }
            }
            
            // Description of selected mode
            Text(settingsState.gameMode.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
                .animation(.easeInOut, value: settingsState.gameMode)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("GameSurface"))
        )
        .onAppear {
            loadGameModePreference()
        }
    }
    
    private func saveGameModePreference(_ mode: GameMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: "selectedGameMode")
    }
    
    private func loadGameModePreference() {
        if let savedMode = UserDefaults.standard.string(forKey: "selectedGameMode"),
           let mode = GameMode(rawValue: savedMode) {
            settingsState.gameMode = mode
        }
    }
}

// Individual Game Mode Button
struct GameModeButton: View {
    let mode: GameMode
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: mode.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(mode.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.accentColor)
                            .matchedGeometryEffect(id: "selection", in: namespace)
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
}

// Compact Game Mode Toggle for inline settings
struct CompactGameModeToggle: View {
    @EnvironmentObject var settingsState: SettingsState
    
    var body: some View {
        HStack {
            Label("Game Mode", systemImage: "gamecontroller.fill")
                .font(.body)
            
            Spacer()
            
            Picker("Game Mode", selection: $settingsState.gameMode) {
                ForEach(GameMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .onChange(of: settingsState.gameMode) { newMode in
                UserDefaults.standard.set(newMode.rawValue, forKey: "selectedGameMode")
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Integration with Home View
struct GameModeAwarePlayButton: View {
    @EnvironmentObject var settingsState: SettingsState
    @EnvironmentObject var gameState: GameState
    @State private var showingGame = false
    
    var body: some View {
        Button(action: {
            startGame()
            showingGame = true
        }) {
            HStack {
                Image(systemName: settingsState.gameMode.icon)
                    .font(.system(size: 20, weight: .medium))
                
                Text("PLAY \(settingsState.gameMode.rawValue.uppercased())")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .tracking(1.0)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: Color.accentColor.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingGame) {
            Group {
                switch settingsState.gameMode {
                case .timePressure:
                    TimedGameView()
                        .environmentObject(gameState)
                        .environmentObject(settingsState)
                case .classic:
                    GameView()
                        .environmentObject(gameState)
                        .environmentObject(settingsState)
                }
            }
        }
    }
    
    private func startGame() {
        // Initialize a new custom game
        gameState.resetGame()
        gameState.isDailyChallenge = false
        // The actual game setup will happen in the view's onAppear
    }
}

// MARK: - Preview Provider
struct GameModeSettings_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            GameModeSettingsView()
                .environmentObject(SettingsState.shared)
            
            CompactGameModeToggle()
                .environmentObject(SettingsState.shared)
                .padding(.horizontal)
            
            GameModeAwarePlayButton()
                .environmentObject(SettingsState.shared)
                .environmentObject(GameState.shared)
        }
        .padding()
        .background(Color("GameBackground"))
    }
}
