import SwiftUI
import CoreData

@main
struct loginboyApp: App {
    let coreDataStack = CoreDataStack.shared
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(\.managedObjectContext, coreDataStack.mainContext)
        }
    }
}
