import Foundation

/// Centralized date formatting for API communication
struct APIDateFormatter {
    static let shared = APIDateFormatter()
    
    private let iso8601Formatter: ISO8601DateFormatter
    private let fallbackFormatters: [DateFormatter]
    
    private init() {
        // Primary formatter - handles most ISO8601 formats
        iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Fallback formatters for various server formats
        fallbackFormatters = [
            // Standard ISO8601 without fractional seconds
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                formatter.timeZone = TimeZone(abbreviation: "UTC")
                return formatter
            }(),
            // ISO8601 with milliseconds
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                formatter.timeZone = TimeZone(abbreviation: "UTC")
                return formatter
            }(),
            // ISO8601 with microseconds
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
                formatter.timeZone = TimeZone(abbreviation: "UTC")
                return formatter
            }(),
            // Without Z suffix
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                formatter.timeZone = TimeZone(abbreviation: "UTC")
                return formatter
            }()
        ]
    }
    
    /// Parse a date string from the API
    func date(from string: String) -> Date? {
        // Try the primary ISO8601 formatter first
        if let date = iso8601Formatter.date(from: string) {
            return date
        }
        
        // Try fallback formatters
        for formatter in fallbackFormatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        
        print("⚠️ [APIDateFormatter] Failed to parse date: \(string)")
        return nil
    }
    
    /// Format a date for API communication
    func string(from date: Date) -> String {
        return iso8601Formatter.string(from: date)
    }
    
    /// Parse date with error information
    func dateWithError(from string: String) throws -> Date {
        if let date = self.date(from: string) {
            return date
        }
        
        throw APIDateError.invalidFormat(string)
    }
}

/// Errors related to date parsing
enum APIDateError: LocalizedError {
    case invalidFormat(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat(let dateString):
            return "Invalid date format: \(dateString)"
        }
    }
}

// MARK: - JSONDecoder Extension

extension JSONDecoder {
    /// Pre-configured decoder for API responses
    static var apiDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            guard let date = APIDateFormatter.shared.date(from: dateString) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Cannot decode date from: \(dateString)"
                )
            }
            
            return date
        }
        return decoder
    }
}

// MARK: - JSONEncoder Extension

extension JSONEncoder {
    /// Pre-configured encoder for API requests
    static var apiEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let dateString = APIDateFormatter.shared.string(from: date)
            try container.encode(dateString)
        }
        return encoder
    }
}
