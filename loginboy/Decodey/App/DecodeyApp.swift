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
        // Load quotes
        await LocalQuoteManager.shared.loadQuotesIfNeeded()
        
        // Check Apple Sign In status
        authManager.checkAuthenticationStatus()
        
        // Initialize Game Center (this sets up the handler)
        await MainActor.run {
            gameCenterManager.setupAuthentication()
        }
        
        // Brief delay for smooth transition
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await MainActor.run {
            isInitializing = false
        }
    }
}

struct LoadingView: View {
    @StateObject private var quoteManager = LocalQuoteManager.shared
    // REMOVED: ColorSystem reference
    // @Environment(\.colorScheme) private var colorScheme
    
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
        .background(Color("GameBackground"))  // CHANGED: Using color asset instead of ColorSystem
    }
}
