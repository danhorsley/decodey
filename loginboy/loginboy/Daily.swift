import Foundation
import SwiftUI
import Combine

struct DailyQuote: Codable {
    let id: Int
    let text: String
    let author: String
    let minor_attribution: String?
    let difficulty: Double
    let date: String
    let unique_letters: Int
    
    // Computed property for formatted date
    var formattedDate: String {
        if let date = ISO8601DateFormatter().date(from: date) {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            return formatter.string(from: date)
        }
        return date
    }
}

class DailyQuoteService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var dailyQuote: DailyQuote?
    
    private let authService: AuthService
    
    init(authService: AuthService) {
        self.authService = authService
    }
    
    func fetchDailyQuote() {
        guard let token = authService.getAccessToken() else {
            self.errorMessage = "You need to be logged in to view the daily challenge"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(authService.baseURL)/api/get_daily") else {
            self.isLoading = false
            self.errorMessage = "Invalid URL configuration"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.errorMessage = "Invalid response from server"
                    return
                }
                
                // Log response details for debugging
                print("Daily Quote API Response: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 401 {
                    self.errorMessage = "Authentication required. Please log in again."
                    self.authService.logout() // Token might be expired, log out
                    return
                }
                
                if httpResponse.statusCode == 404 {
                    self.errorMessage = "No daily challenge available today"
                    return
                }
                
                if httpResponse.statusCode != 200 {
                    // Try to parse error message
                    if let data = data, let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMsg = errorJson["error"] as? String {
                        self.errorMessage = errorMsg
                    } else {
                        self.errorMessage = "Error fetching daily challenge (Status \(httpResponse.statusCode))"
                    }
                    return
                }
                
                guard let data = data else {
                    self.errorMessage = "No data received from server"
                    return
                }
                
                // Log response data for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Daily Quote Response: \(responseString)")
                }
                
                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(DailyQuote.self, from: data)
                    self.dailyQuote = response
                } catch {
                    self.errorMessage = "Failed to parse daily quote data: \(error.localizedDescription)"
                    print("JSON parsing error: \(error)")
                    
                    // Log the JSON structure for debugging
                    if let json = try? JSONSerialization.jsonObject(with: data) {
                        print("Raw JSON: \(json)")
                    }
                }
            }
        }.resume()
    }
}

struct DailyView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var settings: UserSettings
    @StateObject private var gameController: GameController
    @State private var showInfoView = true  // Start with info view
    
    // Initialize with AuthService
    init(authService: AuthService) {
        // Create a GameController for daily challenge
        let controller = GameController(authService: authService)
        self._gameController = StateObject(wrappedValue: controller)
    }
    
    var body: some View {
        // Platform-specific navigation setup
        #if os(iOS)
        NavigationView {
            mainContent
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Force single column
        #else
        // macOS version
        NavigationView {
            mainContent
            
            // Add an empty view as a detail placeholder
            Color.clear.frame(width: 1)
        }
        #endif
    }
    
    // Extracted common content to avoid toolbar ambiguity
    private var mainContent: some View {
        Group {
            if showInfoView {
                dailyInfoView
            } else {
                GameView(gameController: gameController)
            }
        }
        .navigationTitle("Daily Challenge")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                if !showInfoView {
                    Button(action: {
                        showInfoView = true
                    }) {
                        Image(systemName: "info.circle")
                    }
                }
            }
            #else
            ToolbarItem(placement: .automatic) {
                if !showInfoView {
                    Button(action: {
                        showInfoView = true
                    }) {
                        Image(systemName: "info.circle")
                    }
                }
            }
            #endif
        }
        .onAppear {
            if !showInfoView {
                gameController.setupDailyChallenge()
            }
        }
    }
    
    // Daily Challenge Info View
    private var dailyInfoView: some View {
        VStack {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    Text("Daily Challenge")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    if gameController.isLoading {
                        // Loading state
                        ProgressView("Loading today's challenge...")
                            .padding()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let errorMessage = gameController.errorMessage {
                        // Error state
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)
                                .padding()
                            
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding()
                            
                            Button("Try Again") {
                                gameController.setupDailyChallenge()
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding()
                    } else if let date = gameController.quoteDate {
                        // Daily challenge info
                        VStack(spacing: 20) {
                            // Date
                            Text(date)
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.top)
                            
                            // Quote card with masked text
                            VStack(spacing: 16) {
                                // Quote text preview (masked for game)
                                Text(maskQuote(gameController.game.solution))
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(8)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(12)
                                
                                // Author (partially masked)
                                Text("— " + maskAuthor(gameController.quoteAuthor))
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                                
                                // Minor attribution
                                if let attribution = gameController.quoteAttribution {
                                    Text(attribution)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                            .padding(.horizontal)
                            
                            // Stats about the quote
                            VStack(spacing: 12) {
                                InfoRow(title: "Quote Length", value: "\(gameController.game.solution.count) characters")
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal)
                            
                            // Play button
                            Button(action: {
                                showInfoView = false
                                gameController.setupDailyChallenge()
                            }) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Play Today's Challenge")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .shadow(color: Color.green.opacity(0.3), radius: 5, x: 0, y: 3)
                            }
                            .padding(.horizontal)
                            .padding(.top, 10)
                        }
                    } else {
                        // No daily challenge found
                        VStack {
                            Image(systemName: "calendar")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                                .padding()
                            
                            Text("No daily challenge found")
                                .font(.title3)
                                .foregroundColor(.secondary)
                            
                            Button("Check for Today's Challenge") {
                                gameController.setupDailyChallenge()
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.top)
                        }
                        .padding()
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            gameController.setupDailyChallenge()
        }
        .refreshable {
            gameController.setupDailyChallenge()
        }
    }
    
    // Helper to mask quote text for preview
    private func maskQuote(_ text: String) -> String {
        // Show first and last characters of each word, mask the rest
        let words = text.components(separatedBy: " ")
        
        return words.map { word -> String in
            if word.count <= 3 {
                // Don't mask very short words
                return word
            } else {
                // For longer words, show first and last letter
                let firstChar = String(word.prefix(1))
                let lastChar = String(word.suffix(1))
                let middleLength = word.count - 2
                let mask = String(repeating: "•", count: middleLength)
                return "\(firstChar)\(mask)\(lastChar)"
            }
        }.joined(separator: " ")
    }
    
    // Helper to mask author name
    private func maskAuthor(_ author: String) -> String {
        // Show only initials and last name
        let components = author.components(separatedBy: " ")
        
        if components.count == 1 {
            // Single name, show as is
            return author
        } else if components.count == 2 {
            // First and last name
            let firstName = components[0]
            let firstInitial = String(firstName.prefix(1))
            return "\(firstInitial). \(components[1])"
        } else {
            // Multiple names
            var result = ""
            for (index, component) in components.enumerated() {
                if index == components.count - 1 {
                    // Last name
                    result += component
                } else {
                    // Initial for first/middle names
                    result += String(component.prefix(1)) + ". "
                }
            }
            return result
        }
    }
}

// Simple InfoRow structure for displaying key-value pairs
struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}
//
//  Daily.swift
//  loginboy
//
//  Created by Daniel Horsley on 12/05/2025.
//

