// SettingsView.swift
// Decodey
//
// Settings screen with game preferences - Migrated to use GameTheme

import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = SettingsState.shared
    @State private var showingDifficultyPicker = false
    @State private var showingAbout = false
    @State private var showingQuoteDisclaimer = false
    @State private var showingPrivacyPolicy = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Content
            ScrollView {
                VStack(spacing: 24) {
                    appearanceSection
                    gameplaySection
                    audioSection
                    aboutSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(Color.gameBackground)
        }
        .background(Color.gameBackground)
        .preferredColorScheme(settings.isDarkMode ? .dark : .light)
        .sheet(isPresented: $showingDifficultyPicker) {
            DifficultyPickerSheet(selectedDifficulty: $settings.gameDifficulty)
        }
        .sheet(isPresented: $showingAbout) {
            AboutSheet()
        }
        .sheet(isPresented: $showingQuoteDisclaimer) {
            QuoteDisclaimerView()
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            Text("Settings")
                .font(.title.bold())
                .foregroundStyle(Color.primary)
            
            Spacer()
            
            Button("Done") {
                dismiss()
            }
            .font(.body.weight(.medium))
            .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Color.gameBackground
                .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
        )
        .overlay(
            Rectangle()
                .fill(Color.gameBorder)
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
                        .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                        .scaleEffect(0.9)
                }
                
                Divider()
                    .background(Color.gameBorder)
                
                // Alternating Text Display
                SettingRow(
                    title: "Alternating Display",
                    subtitle: "Toggle between views while solving",
                    icon: "text.below.photo"
                ) {
                    Toggle("", isOn: $settings.useAlternatingTextDisplay)
                        .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                        .scaleEffect(0.9)
                }
            }
        }
    }
    
    private var gameplaySection: some View {
        SettingsSection(title: "Gameplay", icon: "gamecontroller.fill") {
            VStack(spacing: 12) {
                // Difficulty Picker
                SettingRow(
                    title: "Difficulty",
                    subtitle: "Number of mistakes allowed",
                    icon: "dial.medium"
                ) {
                    Button(action: { showingDifficultyPicker = true }) {
                        HStack(spacing: 4) {
                            Text(settings.gameDifficulty.capitalized)
                                .font(.body)
                                .foregroundStyle(Color.accentColor)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color.accentColor.opacity(0.6))
                        }
                    }
                }
                
                Divider()
                    .background(Color.gameBorder)
                
                // Text Helpers
                SettingRow(
                    title: "Show Text Helpers",
                    subtitle: "Display hints and assistance",
                    icon: "questionmark.circle.fill"
                ) {
                    Toggle("", isOn: $settings.showTextHelpers)
                        .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                        .scaleEffect(0.9)
                }
                
                Divider()
                    .background(Color.gameBorder)
                
                // Haptic Feedback
                SettingRow(
                    title: "Haptic Feedback",
                    subtitle: "Vibration feedback for actions",
                    icon: "iphone.radiowaves.left.and.right"
                ) {
                    Toggle("", isOn: $settings.hapticEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                        .scaleEffect(0.9)
                        .onChange(of: settings.hapticEnabled) { isEnabled in
                            if isEnabled {
                                // Give a sample haptic when turned on
                                SoundManager.shared.play(.letterClick)
                            }
                        }
                }
            }
        }
    }
    
    private var audioSection: some View {
        SettingsSection(title: "Audio", icon: "speaker.wave.2.fill") {
            VStack(spacing: 12) {
                // Sound Effects
                SettingRow(
                    title: "Sound Effects",
                    subtitle: "Play sounds during gameplay",
                    icon: "speaker.wave.1"
                ) {
                    Toggle("", isOn: $settings.soundEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                        .scaleEffect(0.9)
                }
                
                // Volume Slider
                if settings.soundEnabled {
                    Divider()
                        .background(Color.gameBorder)
                    
                    SettingRow(
                        title: "Volume",
                        subtitle: "Adjust sound effect volume",
                        icon: "speaker.wave.2"
                    ) {
                        HStack(spacing: 12) {
                            Image(systemName: "speaker.fill")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                            
                            Slider(value: $settings.soundVolume, in: 0...1)
                                .frame(width: 100)
                                .tint(Color.accentColor)
                            
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private var aboutSection: some View {
        SettingsSection(title: "About", icon: "info.circle.fill") {
            VStack(spacing: 0) {
                // Quote Information Button
                Button(action: { showingQuoteDisclaimer = true }) {
                    SettingRow(
                        title: "Quote Information",
                        subtitle: "Usage and removal requests",
                        icon: "quote.bubble"
                    ) {
                        Image(systemName: "chevron.right")
                            .font(.body)
                            .foregroundStyle(Color.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .background(Color.gameBorder)
                
                // Privacy Policy Button
                Button(action: { showingPrivacyPolicy = true }) {
                    SettingRow(
                        title: "Privacy Policy",
                        subtitle: "Your data stays on device",
                        icon: "lock.shield"
                    ) {
                        Image(systemName: "chevron.right")
                            .font(.body)
                            .foregroundStyle(Color.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .background(Color.gameBorder)
                
                // About Button
                Button(action: { showingAbout = true }) {
                    SettingRow(
                        title: "About Decodey",
                        subtitle: "Version 1.0",
                        icon: "questionmark.circle"
                    ) {
                        Image(systemName: "chevron.right")
                            .font(.body)
                            .foregroundStyle(Color.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                /* Commented out until App Store ID is available
                Divider()
                    .background(Color.gameBorder)
                
                // Rate App
                Button(action: openAppStore) {
                    SettingRow(
                        title: "Rate Decodey",
                        subtitle: "Share your feedback",
                        icon: "star"
                    ) {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.body)
                            .foregroundStyle(Color.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                */
            }
        }
    }
    
    // MARK: - Actions
    private func openAppStore() {
        // TODO: Replace YOUR_APP_ID with your actual App Store ID when available
        if let url = URL(string: "https://apps.apple.com/app/id_YOUR_APP_ID") {
            #if os(iOS)
            UIApplication.shared.open(url)
            #elseif os(macOS)
            NSWorkspace.shared.open(url)
            #endif
        }
    }
}

// MARK: - Section Container

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
                    .foregroundStyle(Color.accentColor)
                    .font(.body.weight(.medium))
                
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.primary)
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
                    .fill(Color.gameSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gameBorder, lineWidth: 0.5)
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
                .foregroundStyle(Color.accentColor)
                .font(.body)
                .frame(width: 24, height: 24)
            
            // Text Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.primary)
                
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
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
                .foregroundStyle(Color.accentColor)
                
                Spacer()
                
                Text("Difficulty")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .foregroundStyle(Color.accentColor)
                .font(.body.weight(.semibold))
            }
            .padding()
            
            Divider()
                .background(Color.gameBorder)
            
            // Options
            VStack(spacing: 0) {
                ForEach(difficulties, id: \.self) { difficulty in
                    Button(action: {
                        selectedDifficulty = difficulty
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(difficulty.capitalized)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Color.primary)
                                
                                Text(difficultyDescription(difficulty))
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedDifficulty == difficulty {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            selectedDifficulty == difficulty ?
                            Color.accentColor.opacity(0.1) :
                            Color.clear
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if difficulty != difficulties.last {
                        Divider()
                            .background(Color.gameBorder)
                            .padding(.leading, 20)
                    }
                }
            }
            .background(Color.gameSurface)
            
            Spacer()
        }
        .background(Color.gameBackground)
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
                .foregroundStyle(Color.accentColor)
                .font(.body.weight(.semibold))
                
                Spacer()
                
                Text("About")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                
                Spacer()
                
                // Invisible button for balance
                Button("") { }
                    .disabled(true)
                    .opacity(0)
            }
            .padding()
            
            Divider()
                .background(Color.gameBorder)
            
            // Content
            ScrollView {
                VStack(alignment: .center, spacing: 24) {
                    // App Icon
                    Image(systemName: "square.text.square.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.top, 32)
                    
                    // App Name & Version
                    VStack(spacing: 4) {
                        Text("Decodey")
                            .font(.title.weight(.bold))
                            .foregroundStyle(Color.primary)
                        
                        Text("Version 1.0 (Build 1)")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                    
                    // Developer Info
                    VStack(spacing: 8) {
                        Text("Developed with ❤️")
                            .font(.body)
                            .foregroundStyle(Color.secondary)
                        
                        Text("© 2024 Decodey")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                    
                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Features")
                            .font(.headline)
                            .foregroundStyle(Color.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
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
        .background(Color.gameBackground)
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
                .foregroundStyle(Color.accentColor)
                .font(.title3)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
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
