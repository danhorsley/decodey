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
    @StateObject private var quoteService: DailyQuoteService
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var settings: UserSettings
    @State private var showGameView = false
    
    // Initialize with AuthService
    init(authService: AuthService) {
        _quoteService = StateObject(wrappedValue: DailyQuoteService(authService: authService))
    }
    
    var body: some View {
        VStack {
            // Header
            Text("Daily Challenge")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            if quoteService.isLoading {
                // Loading state
                ProgressView("Loading today's challenge...")
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = quoteService.errorMessage {
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
                        quoteService.fetchDailyQuote()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let quote = quoteService.dailyQuote {
                // Quote content
                ScrollView {
                    VStack(spacing: 30) {
                        // Date
                        Text(quote.formattedDate)
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.top)
                        
                        // Difficulty indicator
                        DifficultyIndicator(difficulty: quote.difficulty)
                        
                        // Quote card
                        VStack(spacing: 16) {
                            // Quote text preview (masked for game)
                            Text(maskQuote(quote.text))
                                .font(.title3)
                                .fontWeight(.medium)
                                .multilineTextAlignment(.center)
                                .lineSpacing(8)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                            
                            // Author (partially masked)
                            Text("— " + maskAuthor(quote.author))
                                .font(.callout)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                            
                            // Minor attribution
                            if let attribution = quote.minor_attribution {
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
                            InfoRow(title: "Unique Letters", value: "\(quote.unique_letters)")
                            InfoRow(title: "Quote Length", value: "\(quote.text.count) characters")
                            InfoRow(title: "Difficulty", value: difficultyText(quote.difficulty))
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // Play button
                        Button(action: {
                            showGameView = true
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
                    .padding(.bottom, 30)
                }
                .sheet(isPresented: $showGameView) {
                    // Use our unified GameView with daily parameters
                    NavigationView {
                        GameView(
                            isDailyChallenge: true,
                            dailyQuote: quote,
                            onGameComplete: {
                                showGameView = false
                            }
                        )
                        .environmentObject(settings)
                        .environmentObject(authService)
                        // For macOS, don't include the navigationBarTitleDisplayMode modifier
                    }
                }
            } else {
                // Empty state
                VStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                        .padding()
                    
                    Text("No daily challenge found")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Button("Check for Today's Challenge") {
                        quoteService.fetchDailyQuote()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.top)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.bottom)
        .onAppear {
            quoteService.fetchDailyQuote()
        }
        .refreshable {
            quoteService.fetchDailyQuote()
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
    
    // Helper to convert difficulty to text
    private func difficultyText(_ difficulty: Double) -> String {
        switch difficulty {
        case 0..<1:
            return "Very Easy"
        case 1..<2:
            return "Easy"
        case 2..<3:
            return "Medium"
        case 3..<4:
            return "Hard"
        default:
            return "Very Hard"
        }
    }
}
//
//  Daily.swift
//  loginboy
//
//  Created by Daniel Horsley on 12/05/2025.
//

