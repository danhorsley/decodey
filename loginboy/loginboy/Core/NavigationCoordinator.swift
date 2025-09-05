//
//  NavigationCoordinator.swift - Local Navigation Management
//  loginboy
//

import SwiftUI
import Combine

// Main navigation coordinator
class NavigationCoordinator: ObservableObject {
    // Define all possible app routes
    enum AppRoute: Equatable {
        case welcome    // First-time setup
        case main(TabRoute)
        
        // Main tab routes
        enum TabRoute: Int, Equatable {
            case daily = 0
            case game = 1
            case stats = 2
            case profile = 3
        }
    }
    
    // Current route
    @Published var currentRoute: AppRoute = .welcome
    
    // Selected tab
    @Published var selectedTab: AppRoute.TabRoute = .daily
    
    // Sheet presentation
    @Published var activeSheet: SheetType?
    
    // Sheet types
    enum SheetType: Identifiable {
        case settings
        case playerSetup
        case continueGame
        
        var id: Int {
            switch self {
            case .settings: return 1
            case .playerSetup: return 2
            case .continueGame: return 3
            }
        }
    }
    
    // User manager dependency
    private let userManager: SimpleUserManager
    private var cancellables = Set<AnyCancellable>()
    
    init(userManager: SimpleUserManager = SimpleUserManager.shared) {
        self.userManager = userManager
        
        // Set initial route based on user state
        setupInitialRoute()
        
        // Subscribe to user state changes
        userManager.$isSignedIn
            .sink { [weak self] isSignedIn in
                if isSignedIn {
                    // When player is set up, go to main view
                    if self?.currentRoute == .welcome {
                        self?.navigate(to: .main(.daily))
                    }
                } else {
                    // When player is not set up, go to welcome
                    if case .main = self?.currentRoute {
                        self?.navigate(to: .welcome)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Navigation Methods
    
    func navigate(to route: AppRoute) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentRoute = route
        }
        
        // Update selected tab if navigating to main
        if case let .main(tab) = route {
            selectedTab = tab
        }
    }
    
    func selectTab(_ tab: AppRoute.TabRoute) {
        selectedTab = tab
        navigate(to: .main(tab))
    }
    
    func presentSheet(_ sheet: SheetType) {
        activeSheet = sheet
    }
    
    func dismissSheet() {
        activeSheet = nil
    }
    
    // MARK: - Quick Actions
    
    func showPlayerSetup() {
        presentSheet(.playerSetup)
    }
    
    func showSettings() {
        presentSheet(.settings)
    }
    
    func showContinueGame() {
        presentSheet(.continueGame)
    }
    
    func goToDaily() {
        navigate(to: .main(.daily))
    }
    
    func goToGame() {
        navigate(to: .main(.game))
    }
    
    func goToStats() {
        navigate(to: .main(.stats))
    }
    
    func goToProfile() {
        navigate(to: .main(.profile))
    }
    
    // MARK: - Private Methods
    
    private func setupInitialRoute() {
        if userManager.isSignedIn {
            currentRoute = .main(.daily)
        } else {
            currentRoute = .welcome
        }
    }
}

// MARK: - Navigation View Extensions

extension NavigationCoordinator {
    
    /// Get the appropriate view for the current route
    @ViewBuilder
    func rootView() -> some View {
        switch currentRoute {
        case .welcome:
            WelcomeView()
                .environmentObject(self)
        case .main:
            MainTabView()
                .environmentObject(self)
        }
    }
    
    /// Get the appropriate sheet content
    @ViewBuilder
    func sheetContent(for sheet: SheetType) -> some View {
        switch sheet {
        case .settings:
            SettingsView()
                .environmentObject(self)
        case .playerSetup:
            PlayerSetupView()
                .environmentObject(self)
        case .continueGame:
            ContinueGameView()
                .environmentObject(self)
        }
    }
}

// MARK: - Supporting Views (Placeholder implementations)

struct WelcomeView: View {
    @EnvironmentObject var navigation: NavigationCoordinator
    @EnvironmentObject var userManager: SimpleUserManager
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("🔤")
                    .font(.system(size: 80))
                
                Text("Welcome to Cryptogram")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                
                Text("Decode famous quotes and track your progress")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            Button("Get Started") {
                navigation.showPlayerSetup()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .padding()
    }
}

struct PlayerSetupView: View {
    @EnvironmentObject var navigation: NavigationCoordinator
    @EnvironmentObject var userManager: SimpleUserManager
    @State private var playerName = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Choose Your Player Name")
                .font(.title2.bold())
            
            TextField("Enter your name", text: $playerName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            
            Button("Start Playing") {
                if !playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    userManager.setupLocalPlayer(name: playerName)
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
    }
}

struct MainTabView: View {
    @EnvironmentObject var navigation: NavigationCoordinator
    
    var body: some View {
        TabView(selection: $navigation.selectedTab) {
            DailyView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Daily")
                }
                .tag(NavigationCoordinator.AppRoute.TabRoute.daily)
            
            GameView()
                .tabItem {
                    Image(systemName: "gamecontroller")
                    Text("Game")
                }
                .tag(NavigationCoordinator.AppRoute.TabRoute.game)
            
            StatsView()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Stats")
                }
                .tag(NavigationCoordinator.AppRoute.TabRoute.stats)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person")
                    Text("Profile")
                }
                .tag(NavigationCoordinator.AppRoute.TabRoute.profile)
        }
        .onChange(of: navigation.selectedTab) { newTab in
            navigation.selectTab(newTab)
        }
    }
}

// Placeholder views - these will be your actual game views


//struct SettingsView: View {
//    var body: some View {
//        Text("Settings View")
//    }
//}

struct ContinueGameView: View {
    var body: some View {
        Text("Continue Game View")
    }
}
