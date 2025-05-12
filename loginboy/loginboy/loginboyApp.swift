//
//  loginboyApp.swift
//  loginboy
//
//  Created by Daniel Horsley on 12/05/2025.
//

import SwiftUI

@main
struct AuthTestApp: App {
    // Create services at the app level
    @StateObject private var authService = AuthService()
    @StateObject private var userSettings: UserSettings
    
    // Database manager as a singleton
    private let databaseManager = DatabaseManager.shared
    
    // Initialize any state objects that need dependencies
    init() {
        // Create UserSettings with the authService
        let settings = UserSettings(authService: AuthService())
        self._userSettings = StateObject(wrappedValue: settings)
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(authService)
                .environmentObject(userSettings)
                .onAppear {
                    setupApp()
                    
                    // Add observer for login success notification
                    NotificationCenter.default.addObserver(forName: .userDidLogin, object: nil, queue: .main) { _ in
                        print("DEBUG: Login notification received, syncing data...")
                        syncDataAfterLogin()
                    }
                }
                .onChange(of: authService.isAuthenticated) { newValue in
                    if newValue {
                        print("DEBUG: isAuthenticated changed to true, syncing data...")
                        syncDataAfterLogin()
                    }
                }
        }
    }
    
    private func setupApp() {
        // Initialize anything needed at app launch
        if authService.isAuthenticated {
            // Check and sync quotes if needed on app start
            databaseManager.checkAndSyncQuotesIfNeeded(authService: authService)
        }
    }
    
    private func syncDataAfterLogin() {
        // Sync data after successful login
        databaseManager.syncQuotesFromServer(authService: authService) { success, message in
            if success {
                print("Quotes synced successfully after login")
            } else {
                print("Failed to sync quotes: \(message ?? "Unknown error")")
            }
        }
    }
}
