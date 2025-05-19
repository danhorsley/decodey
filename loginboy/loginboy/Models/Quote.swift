//// Quote.swift - Simplified for Realm
//import Foundation
//
//struct Quote {
//    let text: String
//    let author: String
//    let attribution: String?
//    let difficulty: Double
//    
//    // Convert difficulty value to string representation
//    var difficultyLevel: String {
//        switch difficulty {
//        case 0..<1: return "easy"
//        case 1..<3: return "medium"
//        default: return "hard"
//        }
//    }
//    
//    // Convert difficulty to max mistakes
//    var maxMistakes: Int {
//        switch difficultyLevel {
//        case "easy": return 8
//        case "hard": return 3
//        default: return 5
//        }
//    }
//}
//
//// Daily quote model
//struct DailyQuote: Codable {
//    let id: Int
//    let text: String
//    let author: String
//    let minor_attribution: String?
//    let difficulty: Double
//    let date: String
//    let unique_letters: Int
//    
//    // Computed property for formatted date
//    var formattedDate: String {
//        if let date = ISO8601DateFormatter().date(from: date) {
//            let formatter = DateFormatter()
//            formatter.dateStyle = .long
//            return formatter.string(from: date)
//        }
//        return date
//    }
//}
//
////
////  Quote.swift
////  loginboy
////
////  Created by Daniel Horsley on 14/05/2025.
////
//
