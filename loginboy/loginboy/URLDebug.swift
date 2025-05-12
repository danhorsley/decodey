// MARK: - Network Debug Helper Extension
// Add this to your test app for enhanced debugging

import Foundation

// Debug extension for URLSession
extension URLSession {
    static var debugSession: URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30
        
        // Add a tracking ID to all requests for debugging
        let sessionID = UUID().uuidString.prefix(8)
        configuration.httpAdditionalHeaders = ["X-Debug-ID": "iOS-\(sessionID)"]
        
        return URLSession(configuration: configuration)
    }
}

// Debug extension for URLRequest
extension URLRequest {
    func printDebugInfo(tag: String = "REQUEST") {
        print("\n--- \(tag) DEBUG INFO ---")
        print("URL: \(self.url?.absoluteString ?? "nil")")
        print("Method: \(self.httpMethod ?? "GET")")
        print("Headers: \(self.allHTTPHeaderFields ?? [:])")
        if let body = self.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("Body: \(bodyString)")
        } else if let body = self.httpBody {
            print("Body: \(body.count) bytes (binary)")
        } else {
            print("Body: nil")
        }
        print("Timeout: \(self.timeoutInterval)")
        print("------------------------\n")
    }
}

// Use this function to try multiple URL formats
func tryMultipleURLs(username: String, password: String, completion: @escaping (String?) -> Void) {
    // Create base URLs to try
    let urls = [
        "https://janeway.replit.app/login",
        "https://janeway.replit.app/api/login",
        "http://janeway.replit.app/login",
        "http://janeway.replit.app/api/login"
    ]
    
    // Login data
    let loginData: [String: Any] = [
        "username": username,
        "password": password,
        "rememberMe": true
    ]
    
    var attemptCount = 0
    var successURL: String?
    
    // Try each URL in sequence
    func tryNextURL() {
        guard attemptCount < urls.count else {
            // We've tried all URLs
            completion(successURL)
            return
        }
        
        let urlString = urls[attemptCount]
        attemptCount += 1
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            tryNextURL()
            return
        }
        
        print("🔄 Trying URL: \(urlString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add body
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: loginData)
        } catch {
            print("❌ Failed to serialize request: \(error)")
            tryNextURL()
            return
        }
        
        // Print request details
        request.printDebugInfo()
        
        // Make request
        URLSession.debugSession.dataTask(with: request) { data, response, error in
            // Check for connection error
            if let error = error {
                print("❌ Connection error for \(urlString): \(error.localizedDescription)")
                tryNextURL()
                return
            }
            
            // Check response status
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type for \(urlString)")
                tryNextURL()
                return
            }
            
            print("📊 Response status for \(urlString): \(httpResponse.statusCode)")
            
            // Print response body if any
            if let data = data, let bodyString = String(data: data, encoding: .utf8) {
                print("📝 Response body: \(bodyString)")
            }
            
            // Check if this is a valid endpoint (even if credentials are wrong)
            if 400...499 ~= httpResponse.statusCode {
                // Authentication error = valid endpoint
                print("✅ Found valid API endpoint at \(urlString) (authentication failed but endpoint exists)")
                successURL = urlString
                completion(successURL)
                return
            } else if 200...299 ~= httpResponse.statusCode {
                // Success
                print("✅ Authentication successful at \(urlString)")
                successURL = urlString
                completion(successURL)
                return
            }
            
            // Try next URL
            tryNextURL()
        }.resume()
    }
    
    // Start trying URLs
    tryNextURL()
}

//
//  URLDebug.swift
//  loginboy
//
//  Created by Daniel Horsley on 12/05/2025.
//

