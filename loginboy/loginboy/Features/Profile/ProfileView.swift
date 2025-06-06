import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var settingsState: SettingsState
    @State private var showSyncDetails = false
    @State private var isQuickSyncing = false
    @State private var isFullSyncing = false
    @State private var syncStatusMessage: String?
    @State private var syncWasSuccessful = false
    @State private var lastSyncDate: Date?
    @State private var showFullSyncAlert = false
    
    var body: some View {
        Form {
            // User section
            Section(header: Text("Account")) {
                HStack {
                    Text("Logged in as")
                    Spacer()
                    Text(userState.username)
                        .foregroundColor(.secondary)
                }
                
                if userState.isSubadmin {
                    Label("Admin privileges", systemImage: "checkmark.shield")
                        .foregroundColor(.blue)
                }
            }
            
            // Appearance section
            Section(header: Text("Appearance")) {
                Toggle("Dark Mode", isOn: $settingsState.isDarkMode)
                Toggle("Show Text Helpers", isOn: $settingsState.showTextHelpers)
                Toggle("Accessibility Text Size", isOn: $settingsState.useAccessibilityTextSize)
                
                Picker("Game Difficulty", selection: $settingsState.gameDifficulty) {
                    Text("Easy").tag("easy")
                    Text("Medium").tag("medium")
                    Text("Hard").tag("hard")
                }
            }
            // Security section
            Section(header: Text("Security")) {
                Toggle("Use Biometric Auth", isOn: $settingsState.useBiometricAuth)
            }
            
            // Reset section
            Section {
                Button(action: settingsState.resetToDefaults) {
                    Text("Reset All Settings")
                        .foregroundColor(.red)
                }
            }
            
            // About section
            Section(header: Text("About")) {
                HStack {
                    Text("App Version")
                    Spacer()
                    Text(settingsState.appVersion)
                        .foregroundColor(.secondary)
                }
            }
            // Logout section
            Section {
                Button(action: userState.logout) {
                    HStack {
                        Spacer()
                        Text("Logout")
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Profile & Settings")
    }
}


//
//  ProfileView.swift
//  loginboy
//
//  Created by Daniel Horsley on 13/05/2025.
//

