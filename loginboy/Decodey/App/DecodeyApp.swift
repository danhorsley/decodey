import SwiftUI

@main
struct decodeyApp: App {
    let coreData = CoreDataStack.shared
    
    @State private var isInitializing = true
    @StateObject private var settingsState = SettingsState.shared
    
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
                               .environmentObject(settingsState)  // ADD THIS
                               .preferredColorScheme(settingsState.isDarkMode ? .dark : .light)
            }
        }
    }
    
    private func initializeApp() async {
        print("🚀 Starting app...")
        
        await LocalQuoteManager.shared.loadQuotesIfNeeded()
        
        // Debug what happened
        LocalQuoteManager.shared.debugPrint()
        
        // Wait a second so you can see the loading screen
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            isInitializing = false
        }
        
        print("✅ App ready")
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
