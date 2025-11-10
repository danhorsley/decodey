// GameModeSection.swift
// Decodey
//
// Game mode selection section for SettingsView integration

import SwiftUI

// Add this to your SettingsView.swift file, in the VStack with other sections:
extension SettingsView {
    
    // Add this computed property alongside your other sections (appearanceSection, gameplaySection, etc.)
    
}

// Game Mode Card Component (matches your existing design)
struct GameModeCard: View {
    let mode: GameMode
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Icon
                Image(systemName: mode.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(isSelected ? selectedTextColor : .primary)
                
                // Label
                Text(mode.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(isSelected ? selectedTextColor : .primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? selectedBackground : unselectedBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isSelected ? Color.accentColor : Color.gameBorder,
                                lineWidth: isSelected ? 1.5 : 0.5
                            )
                    )
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
    
    private var selectedTextColor: Color {
        colorScheme == .dark ? .white : .white
    }
    
    private var selectedBackground: Color {
        Color.accentColor
    }
    
    private var unselectedBackground: Color {
        Color.gameSurface
    }
}

// Alternative: Simpler inline toggle if you prefer a more compact option
struct GameModeInlineToggle: View {
    @Binding var gameMode: GameMode
    
    var body: some View {
        SettingRow(
            title: "Game Mode",
            subtitle: gameMode.description,
            icon: "gamecontroller.fill"
        ) {
            Menu {
                ForEach(GameMode.allCases, id: \.self) { mode in
                    Button(action: {
                        gameMode = mode
                        UserDefaults.standard.set(mode.rawValue, forKey: "selectedGameMode")
                        SoundManager.shared.play(.letterClick)
                    }) {
                        Label(mode.rawValue, systemImage: mode.icon)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(gameMode.rawValue)
                        .font(.body)
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gameSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gameBorder, lineWidth: 0.5)
                        )
                )
            }
        }
    }
}
