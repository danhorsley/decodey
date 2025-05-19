import SwiftUI
import CoreData

@main
struct DecodeyApp: SwiftUI.App {
    // Initialize Core Data stack and sound manager
    private let coreData = CoreDataStack.shared
    private let soundManager = SoundManager.shared
    
    // Environment state objects to be shared with the view hierarchy
    @StateObject private var migrationController = MigrationController()
    
    init() {
        // Print database path during initialization
        printDatabasePath()
        
        // Perform one-time setup tasks
        performFirstLaunchSetup()
    }
    
    var body: some Scene {
        WindowGroup {
            // Show main view or migration screen based on migration state
            Group {
                if migrationController.isMigrationNeeded {
                    MigrationView()
                        .environmentObject(migrationController)
                } else {
                    MainView()
                        .environmentObject(UserState.shared)
                        .environmentObject(GameState.shared)
                        .environmentObject(SettingsState.shared)
                }
            }
            .onAppear {
                print("App Started")
                
                // Print database info again when UI appears
                CoreDataStack.shared.printDatabaseInfo()
            }
            .environment(\.managedObjectContext, coreData.mainContext)
        }
    }
    
    // Helper function to print database path
    private func printDatabasePath() {
        // Print the Database path with formatting for console visibility
        print("==================================")
        print("📂 CORE DATA DATABASE PATH:")
        
        // Get persistent store URL
        if let storeURL = CoreDataStack.shared.persistentContainer.persistentStoreCoordinator.persistentStores.first?.url {
            print(storeURL.path)
        } else {
            print("No persistent store found")
        }
        
        print("==================================")
        
        // Also print the Documents directory for reference
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path {
            print("📁 Documents Directory:")
            print(documentsPath)
            print("==================================")
        }
    }
    
    // Perform first launch setup tasks
    private func performFirstLaunchSetup() {
        // Check if this is the first launch of this version
        let defaults = UserDefaults.standard
        let lastVersionKey = "lastInstalledVersion"
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        
        // Get the last installed version if any
        let lastVersion = defaults.string(forKey: lastVersionKey)
        
        // If this is first launch or a new version
        if lastVersion == nil || lastVersion != currentVersion {
            print("First launch of version \(currentVersion)")
            
            // Create initial data in Core Data
            CoreDataStack.shared.createInitialData()
            
            // Save the current version
            defaults.set(currentVersion, forKey: lastVersionKey)
        }
    }
}

// MARK: - Migration Controller and View
class MigrationController: ObservableObject {
    @Published var isMigrationNeeded: Bool = false
    @Published var isMigrating: Bool = false
    @Published var progress: Float = 0.0
    @Published var message: String = "Preparing data migration..."
    @Published var error: String? = nil
    
    private let coreData = CoreDataStack.shared
    
    init() {
        // Check if migration is needed - for now, we could use a flag in UserDefaults
        let defaults = UserDefaults.standard
        isMigrationNeeded = defaults.bool(forKey: "needsDataMigration")
        
        // For testing, you might want to force migration
        // isMigrationNeeded = true
    }
    
    func startMigration() {
        guard isMigrationNeeded, !isMigrating else { return }
        
        isMigrating = true
        progress = 0.0
        message = "Starting migration from Realm to Core Data..."
        
        // Simulate progress updates
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self, self.isMigrating else {
                timer.invalidate()
                return
            }
            
            self.progress = min(self.progress + 0.1, 0.9)
            
            switch Int(self.progress * 10) {
            case 0...2:
                self.message = "Reading Realm database..."
            case 3...5:
                self.message = "Converting data models..."
            case 6...8:
                self.message = "Writing to Core Data..."
            default:
                self.message = "Finalizing migration..."
            }
        }
        
        // Perform actual migration
        coreData.migrateFromRealm { [weak self] success in
            timer.invalidate()
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if success {
                    self.progress = 1.0
                    self.message = "Migration completed successfully!"
                    
                    // Mark migration as complete
                    UserDefaults.standard.set(false, forKey: "needsDataMigration")
                    
                    // Short delay and then hide migration screen
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.isMigrationNeeded = false
                        self.isMigrating = false
                    }
                } else {
                    self.error = "Migration failed. Please contact support."
                    self.isMigrating = false
                }
            }
        }
    }
}

// Migration View
struct MigrationView: View {
    @EnvironmentObject var migrationController: MigrationController
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 70))
                .foregroundColor(.blue)
                .padding()
            
            Text("Data Migration Required")
                .font(.title)
                .fontWeight(.bold)
            
            Text("We need to update your data to a new format. This will only happen once.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if migrationController.isMigrating {
                VStack(spacing: 15) {
                    Text(migrationController.message)
                        .foregroundColor(.secondary)
                    
                    ProgressView(value: migrationController.progress)
                        .padding(.horizontal)
                    
                    Text("\(Int(migrationController.progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
            } else if let error = migrationController.error {
                VStack {
                    Text("Error")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(10)
                .padding()
            }
            
            Button(action: {
                migrationController.startMigration()
            }) {
                Text(migrationController.isMigrating ? "Migrating..." : "Start Migration")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 220)
                    .background(migrationController.isMigrating ? Color.gray : Color.blue)
                    .cornerRadius(10)
            }
            .disabled(migrationController.isMigrating)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}
