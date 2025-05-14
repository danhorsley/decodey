// loginboyApp.swift
import SwiftUI
import RealmSwift

@main
struct DecodeyApp: SwiftUI.App {
    // Access the states
    @StateObject private var userState = UserState.shared
    @StateObject private var gameState = GameState.shared
    @StateObject private var settingsState = SettingsState.shared
    
    // Initialize Realm and sound manager
    private let realmManager = RealmManager.shared
    private let soundManager = SoundManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(userState)
                .environmentObject(gameState)
                .environmentObject(settingsState)
                .onAppear {
                    print("App Started")
                }
        }
    }
}
