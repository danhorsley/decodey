import SwiftUI
import CoreData

@main
struct loginboyApp: App {
    let coreDataStack = CoreDataStack.shared
    @StateObject private var settingsState = SettingsState.shared  // ADD THIS
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(\.managedObjectContext, coreDataStack.mainContext)
                .environmentObject(settingsState)  // ADD THIS
                .preferredColorScheme(settingsState.isDarkMode ? .dark : .light)  // ADD THIS
        }
    }
}
