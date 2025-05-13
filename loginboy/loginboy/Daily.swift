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


struct DailyView: View {
    @EnvironmentObject var auth: AuthenticationCoordinator
    @EnvironmentObject var settings: UserSettings
    @StateObject private var gameController: GameController
    @State private var showInfoView = true
    
    init(auth: AuthenticationCoordinator) {
        let controller = GameController(auth: auth)
        self._gameController = StateObject(wrappedValue: controller)
    }
    
    var body: some View {
        // Platform-specific navigation setup
        #if os(iOS)
        NavigationView {
            mainContent
                .navigationTitle("Daily Challenge")
        }
        .navigationViewStyle(StackNavigationViewStyle())
        #else
        // macOS version - no NavigationView
        VStack(spacing: 0) {
            // Custom header for macOS
            HStack {
                Text("Daily Challenge")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding()
                Spacer()
            }
            .background(Color.secondary.opacity(0.1))
            
            // Main content without navigation
            mainContent
        }
        .frame(minWidth: 600, idealWidth: 800, maxWidth: .infinity,
               minHeight: 500, idealHeight: 700, maxHeight: .infinity)
        #endif
    }
    
    // Extracted common content to avoid toolbar ambiguity
    private var mainContent: some View {
        Group {
            if showInfoView {
                dailyInfoView
            } else {
                GameView()
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

