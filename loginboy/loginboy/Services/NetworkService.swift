import Foundation
import Combine

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case badRequest
    case unauthorized
    case forbidden
    case notFound
    case serverError(Int)
    case decodingError(Error)
    case connectionError(Error)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .badRequest: return "Bad request"
        case .unauthorized: return "Unauthorized - please log in again"
        case .forbidden: return "Access denied"
        case .notFound: return "Resource not found"
        case .serverError(let code): return "Server error (\(code))"
        case .decodingError: return "Failed to process the response"
        case .connectionError(let error): return "Connection error: \(error.localizedDescription)"
        case .unknown(let error): return "Unknown error: \(error.localizedDescription)"
        }
    }
}

class NetworkService {
    static let shared = NetworkService()
    
    private init() {}
    
    // MARK: - Request Building
    
    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }
    
    struct RequestBuilder {
        var baseURL: String
        var path: String
        var method: HTTPMethod = .get
        var queryItems: [URLQueryItem]?
        var headers: [String: String] = [:]
        var body: Data?
        var timeoutInterval: TimeInterval = 30.0
        
        init(baseURL: String, path: String) {
            self.baseURL = baseURL
            self.path = path
        }
        
        mutating func addHeader(key: String, value: String) {
            headers[key] = value
        }
        
        mutating func setAuthToken(_ token: String) {
            headers["Authorization"] = "Bearer \(token)"
        }
        
        mutating func setJSONBody<T: Encodable>(_ body: T) throws {
            let encoder = JSONEncoder()
            self.body = try encoder.encode(body)
            headers["Content-Type"] = "application/json"
        }
        
        func build() throws -> URLRequest {
            var components = URLComponents(string: baseURL)
            
            // Add path
            components?.path += path.hasPrefix("/") ? path : "/\(path)"
            
            // Add query items
            if let queryItems = queryItems, !queryItems.isEmpty {
                components?.queryItems = queryItems
            }
            
            guard let url = components?.url else {
                throw NetworkError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = method.rawValue
            request.timeoutInterval = timeoutInterval
            
            // Set headers
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
            
            // Set body
            request.httpBody = body
            
            return request
        }
    }
    
    // MARK: - Network Requests
    
    func request<T: Decodable>(
        _ builder: RequestBuilder,
        responseType: T.Type
    ) async throws -> T {
        do {
            let request = try builder.build()
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.unknown(NSError(domain: "NetworkService", code: -1))
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch {
                    print("Decoding error: \(error)")
                    throw NetworkError.decodingError(error)
                }
            case 400:
                throw NetworkError.badRequest
            case 401:
                throw NetworkError.unauthorized
            case 403:
                throw NetworkError.forbidden
            case 404:
                throw NetworkError.notFound
            case 500...599:
                throw NetworkError.serverError(httpResponse.statusCode)
            default:
                throw NetworkError.serverError(httpResponse.statusCode)
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.connectionError(error)
        }
    }
    
    // Convenience methods for common operations
    func get<T: Decodable>(
        baseURL: String,
        path: String,
        token: String? = nil,
        queryItems: [URLQueryItem]? = nil,
        responseType: T.Type
    ) async throws -> T {
        var builder = RequestBuilder(baseURL: baseURL, path: path)
        builder.method = .get
        builder.queryItems = queryItems
        
        if let token = token {
            builder.setAuthToken(token)
        }
        
        return try await request(builder, responseType: responseType)
    }
    
    func post<T: Decodable, E: Encodable>(
        baseURL: String,
        path: String,
        body: E,
        token: String? = nil,
        responseType: T.Type
    ) async throws -> T {
        var builder = RequestBuilder(baseURL: baseURL, path: path)
        builder.method = .post
        
        if let token = token {
            builder.setAuthToken(token)
        }
        
        try builder.setJSONBody(body)
        
        return try await request(builder, responseType: responseType)
    }
}

struct AppleSignInRequest: Codable {
    let appleUserId: String
    let email: String?
    let fullName: String?
    let authorizationCode: String?
    let identityToken: String?
}

struct AppleSignInResponse: Codable {
    let access_token: String?
    let refresh_token: String?
    let username: String
    let user_id: String
    let has_active_game: Bool?
    let subadmin: Bool?
}

extension NetworkService {
    
    /// Sign in with Apple
    func signInWithApple(
        baseURL: String,
        appleUserId: String,
        email: String?,
        fullName: String?,
        authorizationCode: Data?,
        identityToken: Data?
    ) async throws -> AppleSignInResponse {
        
        var builder = RequestBuilder(baseURL: baseURL, path: "/auth/apple")
        builder.method = .post
        
        let request = AppleSignInRequest(
            appleUserId: appleUserId,
            email: email,
            fullName: fullName,
            authorizationCode: authorizationCode?.base64EncodedString(),
            identityToken: identityToken?.base64EncodedString()
        )
        
        try builder.setJSONBody(request)
        
        return try await self.request(builder, responseType: AppleSignInResponse.self)
    }
}
//
//  NetworkService.swift
//  loginboy
//
//  Created by Daniel Horsley on 13/05/2025.
//

