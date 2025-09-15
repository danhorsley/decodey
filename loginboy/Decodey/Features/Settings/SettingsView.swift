//
//  SettingsView.swift
//  loginboy
//
//  Modern Apple-compliant Settings UI following project guidelines
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    // Settings state - adjust based on your actual settings manager
    @StateObject private var settings = SettingsState.shared
    @StateObject private var tutorialManager = TutorialManager.shared  // <-- ADD THIS
    
    // Local state for UI
    @State private var showingDifficultyPicker = false
    @State private var showingAbout = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom header (following your guidelines - avoid NavigationView)
            headerView
            
            // Main settings content
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Appearance Section
                    appearanceSection
                    
                    // Game Settings Section
                    gameSettingsSection
                    
                    // Audio Settings Section
                    audioSettingsSection
                    
                    // Accessibility Section
                    accessibilitySection
                    
                    // About Section
                    aboutSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .background(ColorSystem.shared.primaryBackground(for: colorScheme))
        .preferredColorScheme(settings.isDarkMode ? .dark : .light)
        .sheet(isPresented: $showingDifficultyPicker) {
            DifficultyPickerSheet(selectedDifficulty: $settings.gameDifficulty)
        }
        .sheet(isPresented: $showingAbout) {
            AboutSheet()
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            Text("Settings")
                .font(.title.bold())
                .foregroundStyle(ColorSystem.shared.primaryText(for: colorScheme))
            
            Spacer()
            
            Button("Done") {
                dismiss()
            }
            .font(.body.weight(.medium))
            .foregroundStyle(ColorSystem.shared.accent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            ColorSystem.shared.primaryBackground(for: colorScheme)
                .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
        )
        .overlay(
            Rectangle()
                .fill(ColorSystem.shared.border(for: colorScheme))
                .frame(height: 0.5)
                .opacity(0.6),
            alignment: .bottom
        )
    }
    
    // MARK: - Section Views
    
    private var appearanceSection: some View {
        SettingsSection(title: "Appearance", icon: "paintbrush.fill") {
            VStack(spacing: 12) {
                // Dark Mode Toggle
                SettingRow(
                    title: "Dark Mode",
                    subtitle: "Choose your preferred appearance",
                    icon: "moon.fill"
                ) {
                    Toggle("", isOn: $settings.isDarkMode)
                        .toggleStyle(SwitchToggleStyle(tint: ColorSystem.shared.accent))
                        .scaleEffect(0.9)
                }
                
                Divider()
                    .background(ColorSystem.shared.border(for: colorScheme))
                
                // Enhanced Letter Cells
                SettingRow(
                    title: "Enhanced Letter Cells",
                    subtitle: "Visual improvements for game cells",
                    icon: "sparkles"
                ) {
                    Toggle("", isOn: $settings.useEnhancedLetterCells)
                        .toggleStyle(SwitchToggleStyle(tint: ColorSystem.shared.accent))
                        .scaleEffect(0.9)
                }
            }
        }
    }
    
    private var tutorialSection: some View {
          SettingsSection(title: "Help & Tutorial", icon: "questionmark.circle.fill") {
              VStack(spacing: 12) {
                  // Show Tutorial Button
                  SettingRow(
                      title: "Show Tutorial",
                      subtitle: "Learn how to play Decodey",
                      icon: "book.fill"
                  ) {
                      Button(action: {
                          // Dismiss settings first so tutorial shows properly
                          dismiss()
                          
                          // Small delay to ensure settings is dismissed
                          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                              tutorialManager.resetTutorial()
                              tutorialManager.startTutorial()
                          }
                      }) {
                          HStack(spacing: 4) {
                              Image(systemName: "play.fill")
                              Text("Start")
                          }
                          .font(.subheadline.weight(.medium))
                          .foregroundStyle(ColorSystem.shared.accent)
                      }
                  }
                  
                  Divider()
                      .background(ColorSystem.shared.border(for: colorScheme))
                  
                  // Tutorial Status
                  SettingRow(
                      title: "Tutorial Status",
                      subtitle: tutorialManager.hasCompletedTutorial ? "Completed" : "Not completed",
                      icon: "checkmark.circle.fill"
                  ) {
                      if tutorialManager.hasCompletedTutorial {
                          Image(systemName: "checkmark.circle.fill")
                              .foregroundStyle(ColorSystem.shared.success)
                              .font(.body)
                      } else {
                          Image(systemName: "circle")
                              .foregroundStyle(ColorSystem.shared.secondaryText(for: colorScheme))
                              .font(.body)
                      }
                  }
                  
                  if tutorialManager.hasCompletedTutorial {
                      Divider()
                          .background(ColorSystem.shared.border(for: colorScheme))
                      
                      // Reset Tutorial Button
                      SettingRow(
                          title: "Reset Tutorial",
                          subtitle: "Show tutorial on next app launch",
                          icon: "arrow.counterclockwise"
                      ) {
                          Button(action: {
                              tutorialManager.resetTutorial()
                              // Tutorial will show on next app launch
                          }) {
                              Text("Reset")
                                  .font(.subheadline.weight(.medium))
                                  .foregroundStyle(ColorSystem.shared.accent)
                                  .padding(.horizontal, 12)
                                  .padding(.vertical, 6)
                                  .background(
                                      Capsule()
                                          .stroke(ColorSystem.shared.accent, lineWidth: 1)
                                  )
                          }
                      }
                  }
              }
          }
      }
    
    
    private var gameSettingsSection: some View {
        SettingsSection(title: "Game Settings", icon: "gamecontroller.fill") {
            VStack(spacing: 12) {
                // Difficulty Setting
                SettingRow(
                    title: "Difficulty",
                    subtitle: difficultySubtitle,
                    icon: "target"
                ) {
                    Button(action: {
                        showingDifficultyPicker = true
                    }) {
                        HStack(spacing: 8) {
                            Text(settings.gameDifficulty.capitalized)
                                .foregroundStyle(ColorSystem.shared.primaryText(for: colorScheme))
                            
                            Image(systemName: "chevron.right")
                                .foregroundStyle(ColorSystem.shared.secondaryText(for: colorScheme))
                                .font(.caption.weight(.semibold))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Divider()
                    .background(ColorSystem.shared.border(for: colorScheme))
                
                // Text Helpers
                SettingRow(
                    title: "Show Text Helpers",
                    subtitle: "Display hints and assistance",
                    icon: "questionmark.circle.fill"
                ) {
                    Toggle("", isOn: $settings.showTextHelpers)
                        .toggleStyle(SwitchToggleStyle(tint: ColorSystem.shared.accent))
                        .scaleEffect(0.9)
                }
            }
        }
    }
    
    private var audioSettingsSection: some View {
        SettingsSection(title: "Audio", icon: "speaker.wave.2.fill") {
            VStack(spacing: 12) {
                // Sound Enabled
                SettingRow(
                    title: "Sound Effects",
                    subtitle: "Play audio feedback",
                    icon: "speaker.fill"
                ) {
                    Toggle("", isOn: $settings.soundEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: ColorSystem.shared.accent))
                        .scaleEffect(0.9)
                }
                
                if settings.soundEnabled {
                    Divider()
                        .background(ColorSystem.shared.border(for: colorScheme))
                    
                    // Volume Slider
                    VStack(alignment: .leading, spacing: 8) {
                        SettingRow(
                            title: "Volume",
                            subtitle: "\(Int(settings.soundVolume * 100))%",
                            icon: "volume.2.fill"
                        ) {
                            EmptyView()
                        }
                        
                        HStack(spacing: 12) {
                            Image(systemName: "speaker.fill")
                                .foregroundStyle(ColorSystem.shared.secondaryText(for: colorScheme))
                                .font(.caption)
                            
                            Slider(
                                value: $settings.soundVolume,
                                in: 0...1,
                                step: 0.1
                            )
                            .tint(ColorSystem.shared.accent)
                            
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundStyle(ColorSystem.shared.secondaryText(for: colorScheme))
                                .font(.caption)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                    }
                }
            }
        }
    }
    
    private var accessibilitySection: some View {
        SettingsSection(title: "Accessibility", icon: "accessibility") {
            VStack(spacing: 12) {
                // Accessibility Text Size
                SettingRow(
                    title: "Use Accessibility Text Size",
                    subtitle: "Respect system text size settings",
                    icon: "textformat.size"
                ) {
                    Toggle("", isOn: $settings.useAccessibilityTextSize)
                        .toggleStyle(SwitchToggleStyle(tint: ColorSystem.shared.accent))
                        .scaleEffect(0.9)
                }
                
                // Biometric Authentication
                Divider()
                    .background(ColorSystem.shared.border(for: colorScheme))
                
                SettingRow(
                    title: "Biometric Authentication",
                    subtitle: "Use Face ID or Touch ID",
                    icon: "faceid"
                ) {
                    Toggle("", isOn: $settings.useBiometricAuth)
                        .toggleStyle(SwitchToggleStyle(tint: ColorSystem.shared.accent))
                        .scaleEffect(0.9)
                }
            }
        }
    }
    
    private var aboutSection: some View {
        SettingsSection(title: "About", icon: "info.circle.fill") {
            VStack(spacing: 12) {
                // App Version
                SettingRow(
                    title: "Version",
                    subtitle: settings.appVersion,
                    icon: "app.badge"
                ) {
                    EmptyView()
                }
                
                Divider()
                    .background(ColorSystem.shared.border(for: colorScheme))
                
                // More Info Button
                Button(action: {
                    showingAbout = true
                }) {
                    SettingRow(
                        title: "About LoginBoy",
                        subtitle: "App information and credits",
                        icon: "heart.fill"
                    ) {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(ColorSystem.shared.secondaryText(for: colorScheme))
                            .font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var difficultySubtitle: String {
        switch settings.gameDifficulty.lowercased() {
        case "easy": return "8 mistakes allowed"
        case "hard": return "3 mistakes allowed"
        default: return "5 mistakes allowed"
        }
    }
}

// MARK: - Supporting Views

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(ColorSystem.shared.accent)
                    .font(.body.weight(.medium))
                
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ColorSystem.shared.primaryText(for: colorScheme))
            }
            .padding(.horizontal, 4)
            
            // Section Content
            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ColorSystem.shared.secondaryBackground(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ColorSystem.shared.border(for: colorScheme), lineWidth: 0.5)
            )
        }
    }
}

struct SettingRow<Accessory: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    @ViewBuilder let accessory: Accessory
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .foregroundStyle(ColorSystem.shared.accent)
                .font(.body)
                .frame(width: 24, height: 24)
            
            // Text Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(ColorSystem.shared.primaryText(for: colorScheme))
                
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(ColorSystem.shared.secondaryText(for: colorScheme))
                }
            }
            
            Spacer()
            
            // Accessory View
            accessory
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Sheet Views

struct DifficultyPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedDifficulty: String
    
    private let difficulties = ["easy", "medium", "hard"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundStyle(ColorSystem.shared.accent)
                
                Spacer()
                
                Text("Difficulty")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(ColorSystem.shared.primaryText(for: colorScheme))
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .foregroundStyle(ColorSystem.shared.accent)
                .fontWeight(.semibold)
            }
            .padding()
            
            Divider()
                .background(ColorSystem.shared.border(for: colorScheme))
            
            // Difficulty Options
            VStack(spacing: 0) {
                ForEach(difficulties, id: \.self) { difficulty in
                    Button(action: {
                        selectedDifficulty = difficulty
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(difficulty.capitalized)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(ColorSystem.shared.primaryText(for: colorScheme))
                                
                                Text(difficultyDescription(difficulty))
                                    .font(.caption)
                                    .foregroundStyle(ColorSystem.shared.secondaryText(for: colorScheme))
                            }
                            
                            Spacer()
                            
                            if selectedDifficulty == difficulty {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(ColorSystem.shared.accent)
                                    .font(.body.weight(.semibold))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            selectedDifficulty == difficulty ?
                            ColorSystem.shared.accent.opacity(0.1) :
                            Color.clear
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if difficulty != difficulties.last {
                        Divider()
                            .background(ColorSystem.shared.border(for: colorScheme))
                            .padding(.leading, 20)
                    }
                }
            }
            .background(ColorSystem.shared.secondaryBackground(for: colorScheme))
            
            Spacer()
        }
        .background(ColorSystem.shared.primaryBackground(for: colorScheme))
    }
    
    private func difficultyDescription(_ difficulty: String) -> String {
        switch difficulty {
        case "easy": return "8 mistakes allowed • Perfect for beginners"
        case "hard": return "3 mistakes allowed • For experienced players"
        default: return "5 mistakes allowed • Balanced challenge"
        }
    }
}

struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Done") {
                    dismiss()
                }
                .foregroundStyle(ColorSystem.shared.accent)
                .fontWeight(.semibold)
                
                Spacer()
                
                Text("About")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(ColorSystem.shared.primaryText(for: colorScheme))
                
                Spacer()
                
                // Invisible button for balance
                Button("") { }
                    .disabled(true)
                    .opacity(0)
            }
            .padding()
            
            Divider()
                .background(ColorSystem.shared.border(for: colorScheme))
            
            ScrollView {
                VStack(spacing: 32) {
                    // App Icon and Info
                    VStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(ColorSystem.shared.accent.gradient)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text("LB")
                                    .font(.title.bold())
                                    .foregroundStyle(.white)
                            )
                        
                        VStack(spacing: 8) {
                            Text("LoginBoy")
                                .font(.title2.bold())
                                .foregroundStyle(ColorSystem.shared.primaryText(for: colorScheme))
                            
                            Text("A word puzzle game")
                                .font(.body)
                                .foregroundStyle(ColorSystem.shared.secondaryText(for: colorScheme))
                        }
                    }
                    
                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Features")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(ColorSystem.shared.primaryText(for: colorScheme))
                        
                        VStack(spacing: 12) {
                            FeatureRow(icon: "quote.bubble.fill", title: "Classic Quotes", description: "Solve puzzles from famous quotes")
                            FeatureRow(icon: "calendar.badge.clock", title: "Daily Challenges", description: "New puzzle every day")
                            FeatureRow(icon: "airplane", title: "Offline Play", description: "No internet required")
                            FeatureRow(icon: "lock.shield", title: "Privacy First", description: "Your data stays on your device")
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)
            }
        }
        .background(ColorSystem.shared.primaryBackground(for: colorScheme))
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(ColorSystem.shared.accent)
                .font(.title3)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(ColorSystem.shared.primaryText(for: colorScheme))
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(ColorSystem.shared.secondaryText(for: colorScheme))
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    SettingsView()
        .preferredColorScheme(.dark)
}
