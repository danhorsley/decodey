import SwiftUI
import GameKit

@main
struct decodeyApp: App {
    let coreData = CoreDataStack.shared
    
    @State private var isInitializing = true
    @State private var showLaunchScreen = true  // Added for launch screen
    @StateObject private var settingsState = SettingsState.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var gameCenterManager = GameCenterManager.shared
    @Environment(\.scenePhase) private var scenePhase //save games on quit
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main app content
                Group {
                    if isInitializing {
                        LoadingView()
                            .task {
                                await initializeApp()
                            }
                    } else {
                        MainView()
                            .environment(\.managedObjectContext, coreData.mainContext)
                            .environmentObject(settingsState)
                            .environmentObject(authManager)
                            .environmentObject(gameCenterManager)
                            .preferredColorScheme(settingsState.isDarkMode ? .dark : .light)
                    }
                }
                .opacity(showLaunchScreen ? 0 : 1)
                .scaleEffect(showLaunchScreen ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.5), value: showLaunchScreen)
                
                // Launch screen overlay
                if showLaunchScreen {
                    LaunchScreen()
                        .transition(.opacity.combined(with: .scale))
                        .zIndex(1)
                }
            }
            .onAppear {
                // Dismiss launch screen after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation {
                        showLaunchScreen = false
                    }
                }
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
            
            Text("decodey")
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

