import SwiftUI
import Combine

// Main navigation coordinator
class NavigationCoordinator: ObservableObject {
    // Define all possible app routes
    enum AppRoute: Equatable {
        case home
        case login
        case main(TabRoute)
        
        // Main tab routes
        enum TabRoute: Int, Equatable {
            case daily = 0
            case game = 1
            case leaderboard = 2
            case stats = 3
            case profile = 4
        }
    }
    
    // Current route
    @Published var currentRoute: AppRoute = .home
    
    // Selected tab
    @Published var selectedTab: AppRoute.TabRoute = .daily
    
    // Sheet presentation
    @Published var activeSheet: SheetType?
    
    // Sheet types
    enum SheetType: Identifiable {
        case settings
        case login
        case continueGame // Changed from gameOptions to continueGame to match your actual use case
        
        var id: Int {
            switch self {
            case .settings: return 1
            case .login: return 2
            case .continueGame: return 3
            }
        }
    }
    
    // Auth dependency
    private let auth: AuthenticationCoordinator
    private var cancellables = Set<AnyCancellable>()
    
    init(auth: AuthenticationCoordinator) {
        self.auth = auth
        
        // Subscribe to auth changes
        auth.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    // When authenticated, go to main view if currently in login
                    if self?.currentRoute == .login {
                        self?.navigate(to: .main(.daily))
                    }
                } else {
                    // When logged out, go to home if in main view
                    if case .main = self?.currentRoute {
                        self?.navigate(to: .home)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // Navigation methods
    func navigate(to route: AppRoute) {
        withAnimation {
            currentRoute = route
            
            // Update selected tab if navigating to main
            if case .main(let tab) = route {
                selectedTab = tab
            }
        }
    }
    
    func navigateToTab(_ tab: AppRoute.TabRoute) {
        withAnimation {
            selectedTab = tab
            currentRoute = .main(tab)
        }
    }
    
    // Sheet presentation methods
    func presentSheet(_ sheet: SheetType) {
        activeSheet = sheet
    }
    
    func dismissSheet() {
        activeSheet = nil
    }
    
    // Common navigation actions
    func showLogin() {
        navigate(to: .login)
    }
    
    func showHome() {
        navigate(to: .home)
    }
    
    func showMain() {
        navigate(to: .main(selectedTab))
    }
    
    func logout() {
        auth.logout()
        navigate(to: .home)
    }
}

// View modifier for coordinated navigation
struct CoordinatedNavigationViewModifier: ViewModifier {
    @ObservedObject var coordinator: NavigationCoordinator
    @ObservedObject var gameState: GameState // Add this parameter
    
    func body(content: Content) -> some View {
        content
            .sheet(item: $coordinator.activeSheet) { sheetType in
                switch sheetType {
                case .settings:
                    NavigationView {
                        ProfileView()
                            .environmentObject(coordinator)
                    }
                case .login:
                    NavigationView {
                        LoginView()
                            .environmentObject(coordinator)
                    }
                case .continueGame:
                    ContinueGameSheet(isDailyChallenge: gameState.isDailyChallenge)
                        .presentationDetents([.medium])
                }
            }
    }
}


// Extension for View
extension View {
    func withCoordinatedNavigation(_ coordinator: NavigationCoordinator, gameState: GameState) -> some View {
        self.modifier(CoordinatedNavigationViewModifier(coordinator: coordinator, gameState: gameState))
    }
}

//
//  NavigationCoordinator.swift
//  loginboy
//
//  Created by Daniel Horsley on 13/05/2025.
//

