struct QuoteModel: Codable {
    let id: Int
    let text: String
    let author: String
    let minorAttribution: String?
    let difficulty: Double
    let dailyDate: String?
    let timesUsed: Int
    let uniqueLetters: Int
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case text
        case author
        case minorAttribution = "minor_attribution"
        case difficulty
        case dailyDate = "daily_date"
        case timesUsed = "times_used"
        case uniqueLetters = "unique_letters"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct QuotesResponse: Codable {
    let success: Bool
    let quotesCount: Int
    let quotes: [QuoteModel]
    
    enum CodingKeys: String, CodingKey {
        case success
        case quotesCount = "quotes_count"
        case quotes
    }
}

//
//  QuoteModel.swift
//  loginboy
//
//  Created by Daniel Horsley on 12/05/2025.
//

