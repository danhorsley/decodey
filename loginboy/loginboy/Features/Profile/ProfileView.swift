import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var settingsState: SettingsState
    @State private var showLogoutConfirmation = false
    @State private var showResetConfirmation = false
    @State private var showPromoCodeView = false
    @ObservedObject private var promoManager = PromoManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                // Account Section
                Section {
                    ThemedListRow {
                        ThemedInfoRow(
                            title: "Username",
                            value: userState.username,
                            icon: "person.circle.fill"
                        )
                    }
                    
                    if userState.isSubadmin {
                        ThemedListRow {
                            Label {
                                Text("Admin Privileges")
                                    .foregroundColor(.primary)
                            } icon: {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                } header: {
                    ThemedSectionHeader("ACCOUNT", icon: "person.crop.circle")
                }
                
                // Rewards Section - NEW
                Section {
                    // Promo Code Row
                    ThemedListRow(isButton: true) {
                        Button(action: { showPromoCodeView = true }) {
                            HStack {
                                Label {
                                    Text("Redeem Promo Code")
                                        .foregroundColor(.primary)
                                } icon: {
                                    Image(systemName: "gift.fill")
                                        .foregroundColor(.orange)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Active Boost Display
                    if let boost = promoManager.activeXPBoost, boost.isActive {
                        ThemedListRow {
                            HStack {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(Int(boost.multiplier))x XP Boost Active")
                                        .font(.system(size: 15, weight: .semibold))
                                    Text("Expires in \(boost.remainingTimeString)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                } header: {
                    ThemedSectionHeader("REWARDS", icon: "star.circle")
                }
                
                // Appearance Section
                Section {
                    ThemedListRow {
                        Toggle("Dark Mode", isOn: $settingsState.isDarkMode)
                            .toggleStyle(ThemedToggleStyle())
                    }
                    
                    ThemedListRow {
                        Toggle("Show Text Helpers", isOn: $settingsState.showTextHelpers)
                            .toggleStyle(ThemedToggleStyle())
                    }
                    
                    ThemedListRow {
                        Toggle("Large Text", isOn: $settingsState.useAccessibilityTextSize)
                            .toggleStyle(ThemedToggleStyle())
                    }
                } header: {
                    ThemedSectionHeader("APPEARANCE", icon: "paintbrush")
                } footer: {
                    ThemedSectionFooter(text: "Text helpers show labels above game grids")
                }
                
                // Game Settings Section
                Section {
                    ThemedListRow {
                        ThemedPickerRow(
                            title: "Difficulty",
                            selection: $settingsState.gameDifficulty,
                            options: [
                                (value: "easy", label: "Easy"),
                                (value: "medium", label: "Medium"),
                                (value: "hard", label: "Hard")
                            ]
                        )
                    }
                    
                    ThemedListRow {
                        Toggle("Sound Effects", isOn: $settingsState.soundEnabled)
                            .toggleStyle(ThemedToggleStyle())
                    }
                    
                    if settingsState.soundEnabled {
                        ThemedListRow {
                            VolumeSlider(volume: $settingsState.soundVolume)
                        }
                    }
                } header: {
                    ThemedSectionHeader("GAME SETTINGS", icon: "gamecontroller")
                }
                
                // Security Section
                Section {
                    ThemedListRow {
                        Toggle("Biometric Auth", isOn: $settingsState.useBiometricAuth)
                            .toggleStyle(ThemedToggleStyle())
                    }
                } header: {
                    ThemedSectionHeader("SECURITY", icon: "lock.shield")
                } footer: {
                    ThemedSectionFooter(text: "Use Face ID or Touch ID to unlock the app")
                }
                
                // Data Management Section
                Section {
                    ThemedListRow(isButton: true) {
                        Button(action: { showResetConfirmation = true }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset All Settings")
                            }
                            .foregroundColor(.orange)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                } header: {
                    ThemedSectionHeader("DATA", icon: "externaldrive")
                }
                
                // About Section
                Section {
                    ThemedListRow {
                        ThemedInfoRow(
                            title: "Version",
                            value: settingsState.appVersion,
                            icon: "info.circle"
                        )
                    }
                    
                    ThemedListRow {
                        ThemedInfoRow(
                            title: "Build",
                            value: "2025.06.06",
                            icon: "hammer"
                        )
                    }
                } header: {
                    ThemedSectionHeader("ABOUT", icon: "questionmark.circle")
                }
                
                // Account Actions Section
                Section {
                    ThemedListRow(isButton: true) {
                        Button(action: { showLogoutConfirmation = true }) {
                            HStack {
                                Spacer()
                                HStack(spacing: 8) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                    Text("Sign Out")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .themedFormStyle()
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showPromoCodeView) {
            PromoCodeView()
        }
        .alert("Sign Out?", isPresented: $showLogoutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                userState.logout()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Reset Settings?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                settingsState.resetToDefaults()
            }
        } message: {
            Text("This will reset all settings to their default values.")
        }
    }
}

// MARK: - Volume Slider Component
struct VolumeSlider: View {
    @Binding var volume: Float
    @Environment(\.colorScheme) var colorScheme
    
    private let terminalGreen = Color(hex: "4cc9f0")
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 14))
                .foregroundColor(iconColor)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(trackColor)
                        .frame(height: 8)
                    
                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(fillColor)
                        .frame(width: geometry.size.width * CGFloat(volume), height: 8)
                    
                    // Thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                        .offset(x: geometry.size.width * CGFloat(volume) - 10)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newValue = Float(value.location.x / geometry.size.width)
                                    volume = max(0, min(1, newValue))
                                }
                        )
                }
            }
            .frame(height: 20)
            
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 14))
                .foregroundColor(iconColor)
        }
    }
    
    private var iconColor: Color {
        colorScheme == .dark ? terminalGreen.opacity(0.7) : Color.black.opacity(0.5)
    }
    
    private var trackColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }
    
    private var fillColor: Color {
        colorScheme == .dark ? terminalGreen : Color.blue
    }
}
