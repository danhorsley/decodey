import SwiftUI
import Network

struct ComprehensiveNetworkTest: View {
    @State private var serverOptions = [
        "https://7264097a-b4a2-42c7-988c-db8c0c9b107a-00-1lx57x7wg68m5.janeway.replit.dev",
        "https://7264097a-b4a2-42c7-988c-db8c0c9b107a-00-1lx57x7wg68m5.janeway.replit.dev/login",
        "https://janeway.replit.app",
        "http://janeway.replit.app"
    ]
    @State private var selectedServer = "https://7264097a-b4a2-42c7-988c-db8c0c9b107a-00-1lx57x7wg68m5.janeway.replit.dev"
    @State private var customServer = ""
    @State private var logMessages: [String] = []
    @State private var isTestingConnection = false
    @State private var username = "danielhorsley@mac.com"
    @State private var password = "test123!"
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Network Diagnostic Tool")
                    .font(.title)
                    .padding(.bottom)
                
                // Server selection
                Text("Select Server:")
                    .font(.headline)
                
                Picker("Server", selection: $selectedServer) {
                    ForEach(serverOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)
                
                // Custom server input
                HStack {
                    TextField("Or enter custom server URL", text: $customServer)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Add") {
                        if !customServer.isEmpty && !serverOptions.contains(customServer) {
                            serverOptions.append(customServer)
                            selectedServer = customServer
                            customServer = ""
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                // Credentials
                VStack(alignment: .leading) {
                    Text("Test Credentials:")
                        .font(.headline)
                    
                    TextField("Username", text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // Test actions
                HStack {
                    Button("Test Basic Connection") {
                        isTestingConnection = true
                        logMessages = []
                        addLog("🔄 Starting basic connection test to \(selectedServer)...")
                        testBasicConnection(to: selectedServer)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Test Login") {
                        isTestingConnection = true
                        logMessages = []
                        addLog("🔄 Testing login to \(selectedServer)...")
                        testLogin(server: selectedServer, username: username, password: password)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Try All Methods") {
                        isTestingConnection = true
                        logMessages = []
                        addLog("🔄 Testing with multiple methods...")
                        testWithAllMethods(server: selectedServer)
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                // Network info
                VStack(alignment: .leading) {
                    Text("Network Information:")
                        .font(.headline)
                    
                    Button("Show Network Details") {
                        logMessages = []
                        printNetworkDetails()
                    }
                    .buttonStyle(.bordered)
                }
                
                // Loading indicator
                if isTestingConnection {
                    HStack {
                        ProgressView()
                        Text("Testing connection...")
                    }
                    .padding()
                }
                
                // Log output
                VStack(alignment: .leading) {
                    Text("Log Output:")
                        .font(.headline)
                        .padding(.top)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(logMessages, id: \.self) { message in
                                if message.contains("✅") {
                                    Text(message)
                                        .foregroundStyle(.green)
                                } else if message.contains("❌") {
                                    Text(message)
                                        .foregroundStyle(.red)
                                } else {
                                    Text(message)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 300)
                    .padding()
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
    }
    
    // Add log message
    private func addLog(_ message: String) {
        logMessages.append(message)
    }
    
    // Test basic connection
    private func testBasicConnection(to server: String) {
        guard let url = URL(string: server) else {
            addLog("❌ Invalid URL format")
            isTestingConnection = false
            return
        }
        
        // Try multiple request types - first a simple HEAD request
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10
        
        // Add diagnostic headers
        request.addValue("loginboy-diagnostics", forHTTPHeaderField: "User-Agent")
        
        // Print request details
        addLog("📤 Request: \(request.httpMethod ?? "GET") \(url.absoluteString)")
        addLog("📤 Headers: \(request.allHTTPHeaderFields?.description ?? "none")")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    addLog("❌ Connection failed: \(error.localizedDescription)")
                    
                    // Additional error analysis
                    if let nsError = error as NSError? {
                        addLog("❌ Error domain: \(nsError.domain), code: \(nsError.code)")
                        addLog("❌ Error details: \(nsError.userInfo)")
                        
                        // Common error codes analysis
                        if nsError.domain == NSURLErrorDomain {
                            switch nsError.code {
                            case NSURLErrorNotConnectedToInternet:
                                addLog("💡 Diagnosis: Not connected to internet")
                            case NSURLErrorTimedOut:
                                addLog("💡 Diagnosis: Request timed out - server might be down")
                            case NSURLErrorCannotFindHost:
                                addLog("💡 Diagnosis: DNS lookup failed - check URL")
                            case NSURLErrorCannotConnectToHost:
                                addLog("💡 Diagnosis: Connection refused - server might be blocking connections")
                            case NSURLErrorSecureConnectionFailed:
                                addLog("💡 Diagnosis: SSL/TLS error - try with HTTP instead of HTTPS")
                            case NSURLErrorServerCertificateUntrusted:
                                addLog("💡 Diagnosis: Certificate issue - consider adding exception in Info.plist")
                            default:
                                break
                            }
                        }
                    }
                    
                    // Suggestion based on error
                    addLog("💡 Try switching to HTTP protocol if using HTTPS")
                    addLog("💡 Verify the Replit server is running")
                    
                    // Now try a GET request as well
                    testGETRequest(to: server)
                    
                } else if let httpResponse = response as? HTTPURLResponse {
                    addLog("✅ Connection successful! Status: \(httpResponse.statusCode)")
                    addLog("📥 Response headers: \(httpResponse.allHeaderFields)")
                    
                    // Now try a GET request to see the content
                    testGETRequest(to: server)
                }
            }
        }
        task.resume()
    }
    
    // Test with GET request
    private func testGETRequest(to server: String) {
        guard let url = URL(string: server) else { return }
        
        addLog("🔄 Trying GET request to \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    addLog("❌ GET request failed: \(error.localizedDescription)")
                } else if let httpResponse = response as? HTTPURLResponse {
                    addLog("✅ GET request successful! Status: \(httpResponse.statusCode)")
                    
                    if let data = data, let bodyString = String(data: data, encoding: .utf8) {
                        let previewLength = min(500, bodyString.count)
                        let startIndex = bodyString.startIndex
                        let endIndex = bodyString.index(startIndex, offsetBy: previewLength)
                        addLog("📥 Response preview: \(bodyString[startIndex..<endIndex])...")
                    }
                    
                    // Check if we're done testing
                    isTestingConnection = false
                }
            }
        }.resume()
    }
    
    // Test login functionality
    private func testLogin(server: String, username: String, password: String) {
        // Ensure URL ends with /login
        var loginURL = server
        if !loginURL.hasSuffix("/login") {
            loginURL = loginURL.hasSuffix("/") ? "\(loginURL)login" : "\(loginURL)/login"
        }
        
        guard let url = URL(string: loginURL) else {
            addLog("❌ Invalid login URL: \(loginURL)")
            isTestingConnection = false
            return
        }
        
        addLog("🔄 Attempting login at: \(loginURL)")
        
        // Create login data
        let loginData: [String: Any] = [
            "username": username,
            "password": password,
            "rememberMe": true
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        
        // Add detailed headers to mimic browser
        request.addValue("loginboy-test", forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // Serialize to JSON
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: loginData)
            request.httpBody = jsonData
            
            if let bodyString = String(data: jsonData, encoding: .utf8) {
                addLog("📤 Request body: \(bodyString)")
            }
        } catch {
            addLog("❌ JSON serialization error: \(error.localizedDescription)")
            isTestingConnection = false
            return
        }
        
        // Create a custom URLSession configuration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 20
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = .always
        
        let session = URLSession(configuration: config)
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    addLog("❌ Login request failed: \(error.localizedDescription)")
                    
                    // Additional error analysis
                    if let nsError = error as NSError? {
                        addLog("❌ Error domain: \(nsError.domain), code: \(nsError.code)")
                    }
                    
                    // Suggestions
                    addLog("💡 Try a direct API endpoint test")
                    testAPIEndpoint(baseServer: server)
                    
                } else if let httpResponse = response as? HTTPURLResponse {
                    addLog("📥 Login response status: \(httpResponse.statusCode)")
                    
                    // Check for specific status codes
                    if 200...299 ~= httpResponse.statusCode {
                        addLog("✅ Login request received successful status code")
                    } else if httpResponse.statusCode == 401 {
                        addLog("ℹ️ Server responded with 401 Unauthorized - this is expected with test credentials")
                        addLog("✅ Server connection is working correctly")
                    } else {
                        addLog("⚠️ Server responded with status \(httpResponse.statusCode)")
                    }
                    
                    // Print response headers
                    addLog("📥 Response headers: \(httpResponse.allHeaderFields)")
                    
                    // Parse response body
                    if let data = data, let bodyString = String(data: data, encoding: .utf8) {
                        addLog("📥 Response body: \(bodyString)")
                    } else if let data = data {
                        addLog("📥 Received \(data.count) bytes binary response")
                    } else {
                        addLog("📥 No response body received")
                    }
                    
                    isTestingConnection = false
                }
            }
        }.resume()
    }
    
    // Test a simpler API endpoint
    private func testAPIEndpoint(baseServer: String) {
        // Try a few different endpoint variations
        let endpoints = [
            "/api/status",
            "/api/health",
            "/health",
            "/status"
        ]
        
        var baseURL = baseServer
        if baseURL.hasSuffix("/") {
            baseURL.removeLast()
        }
        
        for endpoint in endpoints {
            guard let url = URL(string: "\(baseURL)\(endpoint)") else { continue }
            
            addLog("🔄 Testing endpoint: \(url.absoluteString)")
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 10
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        addLog("❌ Endpoint \(endpoint) failed: \(error.localizedDescription)")
                    } else if let httpResponse = response as? HTTPURLResponse {
                        addLog("✅ Endpoint \(endpoint) responded with status: \(httpResponse.statusCode)")
                        
                        if let data = data, let bodyString = String(data: data, encoding: .utf8) {
                            addLog("📥 Response: \(bodyString)")
                        }
                    }
                    
                    // Only mark testing complete after the last endpoint
                    if endpoint == endpoints.last {
                        isTestingConnection = false
                    }
                }
            }.resume()
        }
    }
    
    // Test with multiple methods
    private func testWithAllMethods(server: String) {
        // First check internet connection
        checkInternetConnection()
        
        // Test with basic HEAD
        addLog("🔄 Testing with HEAD request")
        testBasicConnection(to: server)
        
        // Test with lower-level API
        testWithNWConnection(server: server)
        
        // Test with URLSession debug mode
        testWithDebugSession(server: server)
    }
    
    // Test with NWConnection
    private func testWithNWConnection(server: String) {
        guard let url = URL(string: server),
              let host = url.host else {
            addLog("❌ NWConnection: Invalid URL format")
            return
        }
        
        let port = url.port ?? (url.scheme == "https" ? 443 : 80)
        let nwPort = NWEndpoint.Port(integerLiteral: UInt16(port))
        
        addLog("🔄 Testing with NWConnection to \(host):\(port)")
        
        let parameters = NWParameters.tcp
        if url.scheme == "https" {
            // For HTTPS connections, add TLS
            let options = NWProtocolTLS.Options()
            parameters.defaultProtocolStack.applicationProtocols.insert(options, at: 0)
        }
        
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: nwPort,
            using: parameters
        )
        
        connection.stateUpdateHandler = { state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self.addLog("✅ NWConnection: Successfully connected to \(host):\(port)")
                    connection.cancel()
                    
                case .failed(let error):
                    self.addLog("❌ NWConnection: Failed to connect: \(error.localizedDescription)")
                    
                case .waiting(let error):
                    self.addLog("⏳ NWConnection: Waiting: \(error.localizedDescription)")
                    
                case .preparing:
                    self.addLog("⏳ NWConnection: Preparing connection...")
                    
                case .setup:
                    self.addLog("⏳ NWConnection: Setting up...")
                    
                case .cancelled:
                    self.addLog("ℹ️ NWConnection: Connection cancelled")
                    
                @unknown default:
                    self.addLog("ℹ️ NWConnection: Unknown state")
                }
            }
        }
        
        connection.start(queue: .global())
        
        // Add a timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if connection.state != .cancelled && connection.state != .ready {
                self.addLog("⏱️ NWConnection: Timed out after 10 seconds")
                connection.cancel()
            }
        }
    }
    
    // Test with debug session
    private func testWithDebugSession(server: String) {
        guard let url = URL(string: server) else {
            addLog("❌ Invalid URL format")
            return
        }
        
        addLog("🔄 Testing with debug URLSession")
        
        // Create a specialized session
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 15
        
        // Add unique debugging headers
        let sessionID = UUID().uuidString.prefix(8)
        configuration.httpAdditionalHeaders = [
            "X-Debug-ID": "iOS-\(sessionID)",
            "X-Debug-Client": "loginboy-app"
        ]
        
        let session = URLSession(configuration: configuration)
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Add detailed request info
        addLog("📤 Debug request to: \(url.absoluteString)")
        addLog("📤 Debug headers: \(configuration.httpAdditionalHeaders ?? [:])")
        
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.addLog("❌ Debug session error: \(error.localizedDescription)")
                    
                    // Mark testing complete
                    self.isTestingConnection = false
                } else if let httpResponse = response as? HTTPURLResponse {
                    self.addLog("✅ Debug session success! Status: \(httpResponse.statusCode)")
                    
                    // Print response headers
                    self.addLog("📥 Debug response headers: \(httpResponse.allHeaderFields)")
                    
                    // Print response body
                    if let data = data, let bodyString = String(data: data, encoding: .utf8) {
                        let previewLength = min(300, bodyString.count)
                        let startIndex = bodyString.startIndex
                        let endIndex = bodyString.index(startIndex, offsetBy: previewLength)
                        self.addLog("📥 Debug response preview: \(bodyString[startIndex..<endIndex])...")
                    }
                    
                    // Mark testing complete
                    self.isTestingConnection = false
                }
            }
        }.resume()
    }
    
    // Check basic internet connection
    private func checkInternetConnection() {
        addLog("🔄 Checking basic internet connectivity...")
        
        let googleURL = URL(string: "https://www.google.com")!
        
        var request = URLRequest(url: googleURL)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.addLog("❌ Internet connection test failed: \(error.localizedDescription)")
                    self.addLog("⚠️ Device may not have internet connectivity!")
                } else if let httpResponse = response as? HTTPURLResponse {
                    self.addLog("✅ Internet connectivity confirmed! Google responded with status: \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
    
    // Print network details
    private func printNetworkDetails() {
        addLog("📱 Device Network Information:")
        
        // Check for VPN
        let vpnProtocols = [
            "tap", "tun", "ppp", "ipsec", "utun"
        ]
        
        var hasVPN = false
        
        // Log Info.plist settings
        if let infoDict = Bundle.main.infoDictionary {
            addLog("📄 Info.plist Network Settings:")
            
            if let ats = infoDict["NSAppTransportSecurity"] as? [String: Any] {
                if let allowsArbitraryLoads = ats["NSAllowsArbitraryLoads"] as? Bool {
                    addLog("   NSAllowsArbitraryLoads: \(allowsArbitraryLoads)")
                }
                
                if let exceptionDomains = ats["NSExceptionDomains"] as? [String: Any] {
                    addLog("   Exception Domains: \(exceptionDomains.keys.joined(separator: ", "))")
                }
            } else {
                addLog("   No App Transport Security settings found")
            }
        }
        
        // Log entitlements
        addLog("📄 App Entitlements:")
        addLog("   Sandbox Enabled: true (from uploaded code)")
        addLog("   User-Selected Files (Read): true (from uploaded code)")
        
        // Check proxy settings
        let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as NSDictionary?
        addLog("📄 System Proxy Settings: \(proxySettings != nil ? "Active" : "None")")
        
        // Internet connectivity path monitor
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    self.addLog("✅ Internet connection is available")
                    
                    // Connection type
                    if path.usesInterfaceType(.wifi) {
                        self.addLog("   Connection type: WiFi")
                    } else if path.usesInterfaceType(.cellular) {
                        self.addLog("   Connection type: Cellular")
                    } else if path.usesInterfaceType(.wiredEthernet) {
                        self.addLog("   Connection type: Wired Ethernet")
                    } else if path.usesInterfaceType(.loopback) {
                        self.addLog("   Connection type: Loopback")
                    } else {
                        self.addLog("   Connection type: Other")
                    }
                    
                    // Connection properties
                    self.addLog("   Expensive: \(path.isExpensive)")
                    self.addLog("   Constrained: \(path.isConstrained)")
                    
                } else {
                    self.addLog("❌ No internet connection available")
                }
                
                monitor.cancel()
            }
        }
        monitor.start(queue: .global())
        
        // Final advice
        addLog("")
        addLog("💡 RECOMMENDATIONS:")
        addLog("1. Try using HTTP instead of HTTPS for development")
        addLog("2. Check if your Replit server is running")
        addLog("3. Try a simpler URL format")
        addLog("4. Ensure server has CORS configured properly")
        addLog("5. Consider using a local development server")
    }
}

//
//  CompNetTest.swift
//  loginboy
//
//  Created by Daniel Horsley on 12/05/2025.
//

