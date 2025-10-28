// SettingsView.swift
// Decodey
//
// Settings screen with game preferences - Migrated to use GameTheme
// Updated: Removed Done button as tab navigation handles dismissal

import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = SettingsState.shared
    @State private var showingDifficultyPicker = false
    @State private var showingAbout = false
    @State private var showingQuoteDisclaimer = false
    @State private var showingPrivacyPolicy = false
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
                    packSelectionSection  
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
            
            // Done button removed - tab navigation handles dismissal
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
                
                Divider()
                    .background(Color.gameBorder)
                
                // Text Size Setting
                SettingRow(
                    title: "Accessibility Text Size",
                    subtitle: "Larger text for better readability",
                    icon: "textformat.size"
                ) {
                    Toggle("", isOn: $settings.useAccessibilityTextSize)
                        .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                        .scaleEffect(0.9)
                }
            }
        }
    }
    
    private var gameplaySection: some View {
        SettingsSection(title: "Gameplay", icon: "gamecontroller.fill") {
            VStack(spacing: 12) {
                // Difficulty Selector
                Button(action: { showingDifficultyPicker = true }) {
                    SettingRow(
                        title: "Difficulty",
                        subtitle: "Choose your challenge level",
                        icon: "speedometer"
                    ) {
                        HStack(spacing: 4) {
                            Text(settings.gameDifficulty.capitalized)
                                .foregroundStyle(Color.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .background(Color.gameBorder)
                
                // Text Helpers Toggle
                SettingRow(
                    title: "Show Text Helpers",
                    subtitle: "Display word length indicators",
                    icon: "questionmark.circle"
                ) {
                    Toggle("", isOn: $settings.showTextHelpers)
                        .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                        .scaleEffect(0.9)
                }
            }
        }
    }
    
    private var audioSection: some View {
        SettingsSection(title: "Audio & Feedback", icon: "speaker.wave.2.fill") {
            VStack(spacing: 12) {
                // Sound Effects Toggle
                SettingRow(
                    title: "Sound Effects",
                    subtitle: "Play sounds for game events",
                    icon: "speaker.fill"
                ) {
                    Toggle("", isOn: $settings.soundEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                        .scaleEffect(0.9)
                }
                
                Divider()
                    .background(Color.gameBorder)
                
                // Haptic Feedback Toggle (iOS only)
                #if os(iOS)
                SettingRow(
                    title: "Haptic Feedback",
                    subtitle: "Vibration for button presses",
                    icon: "hand.tap"
                ) {
                    Toggle("", isOn: $settings.hapticFeedback)
                        .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                        .scaleEffect(0.9)
                }
                #endif
            }
        }
    }
    
    private var packSelectionSection: some View {
        SettingsSection(title: "Quote Packs", icon: "books.vertical.fill") {
            VStack(spacing: 12) {
                Text("Select packs for random games")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                    .background(Color.gameBorder)
                
                // Free pack toggle
                HStack {
                    Image(systemName: settings.isPackEnabledForRandom("free") ? "checkmark.square.fill" : "square")
                        .foregroundStyle(Color.accentColor)
                        .font(.body)
                    
                    Text("Free Quotes")
                        .font(.body)
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { settings.isPackEnabledForRandom("free") },
                        set: { _ in
                            // Only toggle if user has other packs
                            if settings.enabledPacksForRandom.count > 1 {
                                settings.togglePackForRandom("free")
                            }
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                    .scaleEffect(0.9)
                    .disabled(settings.enabledPacksForRandom.count <= 1)
                }
                
                // Add toggles for each purchased pack
                ForEach(StoreManager.ProductID.allCases, id: \.self) { productID in
                    if StoreManager.shared.isPackPurchased(productID) {
                        Divider()
                            .background(Color.gameBorder)
                        
                        HStack {
                            Image(systemName: settings.isPackEnabledForRandom(productID.rawValue) ? "checkmark.square.fill" : "square")
                                .foregroundStyle(Color.accentColor)
                                .font(.body)
                            
                            Text(productID.displayName)
                                .font(.body)
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { settings.isPackEnabledForRandom(productID.rawValue) },
                                set: { _ in settings.togglePackForRandom(productID.rawValue) }
                            ))
                            .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                            .scaleEffect(0.9)
                        }
                    }
                }
            }
        }
    }
    
    private var aboutSection: some View {
        SettingsSection(title: "Information", icon: "info.circle.fill") {
            VStack(spacing: 12) {
                // Quote Disclaimer Button
                Button(action: { showingQuoteDisclaimer = true }) {
                    SettingRow(
                        title: "Quotes Disclaimer",
                        subtitle: "About quotes and attributions",
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
                VStack(spacing: 24) {
                    // App Icon and Name
                    VStack(spacing: 12) {
                        Image(systemName: "text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.accentColor)
                        
                        Text("Decodey")
                            .font(.title.bold())
                            .foregroundStyle(Color.primary)
                        
                        Text("Version 1.0")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Description
                    Text("A daily cryptogram puzzle game where you decode famous quotes one letter at a time.")
                        .font(.body)
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Credits
                    VStack(spacing: 16) {
                        VStack(spacing: 4) {
                            Text("Created by")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                            Text("Your Name")
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color.primary)
                        }
                        
                        VStack(spacing: 4) {
                            Text("Contact")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                            Link("support@decodey.com", destination: URL(string: "mailto:support@decodey.com")!)
                                .font(.body)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .padding(.top, 8)
                    
                    Spacer(minLength: 40)
                }
            }
            .background(Color.gameBackground)
        }
        .background(Color.gameBackground)
    }
}

