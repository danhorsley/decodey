// loginboyApp.swift
import SwiftUI
import RealmSwift

@main
struct DecodeyApp: SwiftUI.App {
    // Initialize Realm and sound manager
    private let realmManager = RealmManager.shared
    private let soundManager = SoundManager.shared
    
    init() {
        // Print database path during initialization
        printDatabasePath()
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(UserState.shared)
                .environmentObject(GameState.shared)
                .environmentObject(SettingsState.shared)
                .onAppear {
                    print("App Started")
                    
                    // Print database info again when UI appears
                    RealmManager.shared.printDatabaseInfo()
                }
        }
    }
    
    // Helper function to print database path
    private func printDatabasePath() {
        // Get the default Realm path
        let defaultRealmPath = Realm.Configuration.defaultConfiguration.fileURL?.path ?? "unknown"
        
        // Print with formatting for console visibility
        print("==================================")
        print("📂 DATABASE PATH:")
        print(defaultRealmPath)
        print("==================================")
        
        // Also print the Documents directory for reference
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path {
            print("📁 Documents Directory:")
            print(documentsPath)
            print("==================================")
        }
    }
}
