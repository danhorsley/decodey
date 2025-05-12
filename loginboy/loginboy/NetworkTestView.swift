// Create a new Swift file called NetworkTest.swift with this content

import SwiftUI
import Network

struct NetworkTestView: View {
    @State private var reachable = false
    @State private var testing = false
    @State private var testResult = ""
    @State private var urlToTest = "https://7264097a-b4a2-42c7-988c-db8c0c9b107a-00-1lx57x7wg68m5.janeway.replit.dev"
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Network Connectivity Test")
                .font(.title)
            
            // URL input
            TextField("URL to test", text: $urlToTest)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            // Using multiple testing methods for redundancy
            VStack(spacing: 10) {
                Button("Test with URLSession") {
                    testURLSession()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                Button("Test with NWConnection") {
                    testNWConnection()
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                Button("Test with Simple Domains") {
                    testSimpleDomains()
                }
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            if testing {
                ProgressView("Testing connectivity...")
            }
            
            Text(testResult)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(testResult.contains("Success") ? Color.green.opacity(0.2) :
                             testResult.contains("Failed") ? Color.red.opacity(0.2) : Color.gray.opacity(0.2))
                )
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            Text("This test app is specifically for troubleshooting network connectivity issues in macOS sandboxed apps.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
        .padding()
    }
    
    // Test using URLSession
    private func testURLSession() {
        testing = true
        testResult = "Testing with URLSession...\n"
        
        // First try a very simple URL known to work
        let googleURL = URL(string: "https://www.google.com")!
        
        var request = URLRequest(url: googleURL)
        request.httpMethod = "HEAD" // Just check headers, don't download content
        request.timeoutInterval = 5
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.testResult += "Google test failed: \(error.localizedDescription)\n"
                } else if let httpResponse = response as? HTTPURLResponse {
                    self.testResult += "Google test success! Status: \(httpResponse.statusCode)\n"
                }
                
                // Now test the actual URL
                guard let url = URL(string: self.urlToTest) else {
                    self.testResult += "Invalid URL format\n"
                    self.testing = false
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "HEAD"
                request.timeoutInterval = 5
                
                URLSession.shared.dataTask(with: request) { _, response, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self.testResult += "Replit URL test failed: \(error.localizedDescription)\n"
                        } else if let httpResponse = response as? HTTPURLResponse {
                            self.testResult += "Replit URL test success! Status: \(httpResponse.statusCode)\n"
                        }
                        self.testing = false
                    }
                }.resume()
            }
        }.resume()
    }
    
    // Test using NWConnection (lower level)
    private func testNWConnection() {
        testing = true
        testResult = "Testing with NWConnection...\n"
        
        // Parse the URL to get the hostname
        guard let url = URL(string: urlToTest),
              let host = url.host else {
            testResult += "Invalid URL format\n"
            testing = false
            return
        }
        
        // Get the port from the URL or default to 443 for HTTPS, 80 for HTTP
        let port = url.port ?? (url.scheme == "https" ? 443 : 80)
        let nwPort = NWEndpoint.Port(integerLiteral: UInt16(port))
        
        // Create a connection to the host
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: nwPort,
            using: .tls // Use TLS for secure connections
        )
        
        // Set up state handling
        connection.stateUpdateHandler = { state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self.testResult += "NWConnection successful: Connected to \(host):\(port)\n"
                    connection.cancel()
                    self.testing = false
                    
                case .failed(let error):
                    self.testResult += "NWConnection failed: \(error.localizedDescription)\n"
                    self.testing = false
                    
                case .waiting(let error):
                    self.testResult += "NWConnection waiting: \(error.localizedDescription)\n"
                    
                case .cancelled:
                    self.testResult += "NWConnection cancelled\n"
                    self.testing = false
                    
                default:
                    break
                }
            }
        }
        
        // Start the connection
        connection.start(queue: .global())
        
        // Add a timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if self.testing {
                self.testResult += "NWConnection timed out after 10 seconds\n"
                connection.cancel()
                self.testing = false
            }
        }
    }
    
    // Test simple domains to see if any network access works
    private func testSimpleDomains() {
        testing = true
        testResult = "Testing simple domains...\n"
        
        // Create simpler domain formats to test
        let simpleHost = urlToTest.replacingOccurrences(of: "https://", with: "")
                                  .replacingOccurrences(of: "http://", with: "")
                                  .components(separatedBy: "/").first ?? ""
        
        let domains = [
            "https://www.google.com",
            "https://replit.com",
            "https://\(simpleHost.components(separatedBy: ".").suffix(2).joined(separator: "."))" // Try domain without subdomain
        ]
        
        testResult += "Testing domains:\n"
        for domain in domains {
            testResult += "- \(domain)\n"
        }
        
        // Test each domain
        var remainingTests = domains.count
        
        for domain in domains {
            guard let url = URL(string: domain) else { continue }
            
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 5
            
            URLSession.shared.dataTask(with: request) { _, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.testResult += "Failed: \(domain) - \(error.localizedDescription)\n"
                    } else if let httpResponse = response as? HTTPURLResponse {
                        self.testResult += "Success: \(domain) - Status \(httpResponse.statusCode)\n"
                    }
                    
                    remainingTests -= 1
                    if remainingTests == 0 {
                        self.testing = false
                    }
                }
            }.resume()
        }
    }
}

//
//  NetworkTestView.swift
//  loginboy
//
//  Created by Daniel Horsley on 12/05/2025.
//

