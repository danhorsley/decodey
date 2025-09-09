import SwiftUI
import GameKit

@main
struct decodeyApp: App {
    let coreData = CoreDataStack.shared
    
    @State private var isInitializing = true
    @StateObject private var settingsState = SettingsState.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var gameCenterManager = GameCenterManager.shared
    
    var body: some Scene {
        WindowGroup {
            if isInitializing {
                LoadingView()
                    .task {
                        await initializeApp()
                    }
            } else {
                MainView()
                    .environment(\.managedObjectContext, coreData.mainContext)
                    .environmentObject(settingsState)
                    .environmentObject(authManager)  // Add this
                    .environmentObject(gameCenterManager)  // Add this
                    .preferredColorScheme(settingsState.isDarkMode ? .dark : .light)
            }
        }
    }
    
    private func initializeApp() async {
        print("🚀 Starting app...")
        
        // Load quotes
        await LocalQuoteManager.shared.loadQuotesIfNeeded()
        
        // Check Apple Sign In status
        authManager.checkAuthenticationStatus()
        
        // Initialize Game Center (this sets up the handler)
        await MainActor.run {
            gameCenterManager.setupAuthentication()
        }
        
        // Debug what happened
        LocalQuoteManager.shared.debugPrint()
        
        // Wait a second so you can see the loading screen
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            isInitializing = false
        }
        
        print("✅ App ready")
        print("📱 Apple Sign In: \(authManager.isAuthenticated ? "Yes" : "No")")
        print("🎮 Game Center Available: \(gameCenterManager.isGameCenterAvailable ? "Yes" : "No")")
    }
}

struct LoadingView: View {
    @StateObject private var quoteManager = LocalQuoteManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            Text("🧩")
                .font(.system(size: 60))
            
            Text("Decodey")
                .font(.largeTitle.bold())
            
            if let error = quoteManager.loadingError {
                Text("❌ \(error)")
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            } else if quoteManager.isLoaded {
                Text("✅ Quotes loaded")
                    .foregroundColor(.green)
            } else {
                ProgressView("Loading quotes...")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorSystem.shared.primaryBackground(for: colorScheme))
    }
}
