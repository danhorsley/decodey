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
            //sync game score
            Section(header: Text("Advanced")) {
                // Sync status info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Game Sync Status")
                            .fontWeight(.medium)
                        Spacer()
                        Button(action: { showSyncDetails.toggle() }) {
                            Image(systemName: showSyncDetails ? "chevron.up" : "chevron.down")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if showSyncDetails {
                        VStack(alignment: .leading, spacing: 12) {
                            // Last sync info
                            if let lastSync = lastSyncDate {
                                HStack {
                                    Text("Last sync:")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(formatRelativeDate(lastSync))
                                        .fontWeight(.medium)
                                }
                            } else {
                                Text("Never synced")
                                    .foregroundColor(.secondary)
                            }
                            
                            // Sync buttons
                            VStack(spacing: 8) {
                                // Quick sync button
                                Button(action: performQuickSync) {
                                    HStack {
                                        if isQuickSyncing {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        } else {
                                            Image(systemName: "arrow.clockwise")
                                        }
                                        Text("Quick Sync")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(isQuickSyncing ? Color.gray : Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                .disabled(isQuickSyncing || isFullSyncing || !userState.isAuthenticated)
                                
                                // Full reconciliation button (warning style)
                                Button(action: { showFullSyncAlert = true }) {
                                    HStack {
                                        if isFullSyncing {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        } else {
                                            Image(systemName: "exclamationmark.triangle")
                                        }
                                        Text("Full Reconciliation")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(isFullSyncing ? Color.gray : Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                .disabled(isQuickSyncing || isFullSyncing || !userState.isAuthenticated)
                            }
                            
                            // Status message
                            if let statusMessage = syncStatusMessage {
                                HStack {
                                    Image(systemName: syncWasSuccessful ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .foregroundColor(syncWasSuccessful ? .green : .red)
                                    Text(statusMessage)
                                        .font(.caption)
                                }
                                .padding(.top, 4)
                            }
                            
                            // Warning text
                            Text("Full reconciliation will compare all local and server games. Use only if you're experiencing sync issues.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                        .padding(.top, 8)
                    }
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
        .alert("Full Reconciliation", isPresented: $showFullSyncAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Continue", role: .destructive) {
                performFullReconciliation()
            }
        } message: {
            Text("This will perform a complete comparison of all local and server games. This may take a while and should only be used if you're experiencing sync issues. Continue?")
        }

    }
    
    private func loadSyncStatus() {
        lastSyncDate = UserDefaults.standard.object(forKey: "lastGameSyncTimestamp") as? Date
    }

    private func performQuickSync() {
        guard userState.isAuthenticated else { return }
        
        isQuickSyncing = true
        syncStatusMessage = nil
        
        GameReconciliationManager.shared.smartReconcileGames(trigger: .manual) { success, error in
            DispatchQueue.main.async {
                isQuickSyncing = false
                syncWasSuccessful = success
                
                if success {
                    userState.recalculateStatsFromGames()
                    syncStatusMessage = "Quick sync completed"
                    loadSyncStatus()
                } else {
                    syncStatusMessage = "Quick sync failed: \(error ?? "Unknown error")"
                }
                
                // Clear message after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    syncStatusMessage = nil
                }
            }
        }
    }

    private func performFullReconciliation() {
        guard userState.isAuthenticated else { return }
        
        isFullSyncing = true
        syncStatusMessage = nil
        
        // Force a full reconciliation by clearing the last sync timestamp temporarily
        let lastSyncKey = "lastGameSyncTimestamp"
        let lastSuccessfulSyncKey = "lastSuccessfulGameSync"
        let backupLastSync = UserDefaults.standard.object(forKey: lastSyncKey) as? Date
        let backupLastSuccessful = UserDefaults.standard.object(forKey: lastSuccessfulSyncKey) as? Date
        
        // Temporarily clear sync history to force full reconciliation
        UserDefaults.standard.removeObject(forKey: lastSyncKey)
        UserDefaults.standard.removeObject(forKey: lastSuccessfulSyncKey)
        
        GameReconciliationManager.shared.reconcileGames { success, error in
            DispatchQueue.main.async {
                isFullSyncing = false
                syncWasSuccessful = success
                
                if success {
                    userState.recalculateStatsFromGames()
                    syncStatusMessage = "Full reconciliation completed"
                    loadSyncStatus()
                } else {
                    syncStatusMessage = "Full reconciliation failed: \(error ?? "Unknown error")"
                    
                    // Restore backup timestamps on failure
                    if let backup = backupLastSync {
                        UserDefaults.standard.set(backup, forKey: lastSyncKey)
                    }
                    if let backup = backupLastSuccessful {
                        UserDefaults.standard.set(backup, forKey: lastSuccessfulSyncKey)
                    }
                }
                
                // Clear message after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    syncStatusMessage = nil
                }
            }
        }
    }


    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // Add this alert to the ProfileView body
    
    // Add this to ProfileView's onAppear
    
}


//
//  ProfileView.swift
//  loginboy
//
//  Created by Daniel Horsley on 13/05/2025.
//

