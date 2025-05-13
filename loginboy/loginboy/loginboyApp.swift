//
//  loginboyApp.swift
//  loginboy
//
//  Created by Daniel Horsley on 12/05/2025.
//

import SwiftUI

@main
struct AuthTestApp: App {
    // Access the shared AppState
    let appState = AppState.shared
    
    // Add this line to initialize SoundManager
    private let soundManager = SoundManager.shared
    
    var body: some Scene {
        WindowGroup {
            // Use MainView with all required environment objects
            MainView()
                // Inject all required environment objects
                .environmentObject(appState.userState)
                .environmentObject(appState.gameState)
                .environmentObject(appState.settingsState)
                .onAppear {
                    print("App Started")
                }
        }
    }
}
    

