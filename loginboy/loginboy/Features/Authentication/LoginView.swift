import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthenticationCoordinator
    @State private var username = ""
    @State private var password = ""
    @State private var rememberMe = true
    @State private var backendURL = "https://7264097a-b4a2-42c7-988c-db8c0c9b107a-00-1lx57x7wg68m5.janeway.replit.dev/login"
    
    @FocusState private var isURLFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Auth Test")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Backend URL (for testing)
            VStack(alignment: .leading) {
                Text("Backend URL")
                    .font(.caption)
                
                TextField("Backend URL", text: $backendURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
                    .focused($isURLFieldFocused)
                    .onSubmit {
                        auth.setBaseURL(backendURL)
                    }
                
                Button("Update URL") {
                    auth.setBaseURL(backendURL)
                }
                .font(.caption)
                .padding(.top, 4)
            }
            .padding(.bottom, 10)
            
            // Username field
            VStack(alignment: .leading) {
                Text("Username or Email")
                    .font(.caption)
                TextField("Username or Email", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
            }
            
            // Password field
            VStack(alignment: .leading) {
                Text("Password")
                    .font(.caption)
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // Remember me toggle
            Toggle(isOn: $rememberMe) {
                Text("Remember me")
            }
            
            // Login button
            Button(action: {
                auth.login(username: username, password: password, rememberMe: rememberMe) { success, error in
                    if success {
                        print("Login successful!")
                    } else {
                        print("Login failed: \(error ?? "Unknown error")")
                    }
                }
            }) {
                if auth.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                } else {
                    Text("Login")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .disabled(username.isEmpty || password.isEmpty || auth.isLoading)
            
            // Error message
            if let errorMessage = auth.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            // Success message
            if auth.isAuthenticated {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Logged in successfully!")
                        .foregroundColor(.green)
                        .fontWeight(.bold)
                    
                    Text("Username: \(auth.username)")
                    Text("User ID: \(auth.userId)")
                    Text("Admin access: \(auth.isSubadmin ? "Yes" : "No")")
                    Text("Has active game: \(auth.hasActiveGame ? "Yes" : "No")")
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                
                // Logout button
                Button(action: {
                    auth.logout()
                }) {
                    Text("Logout")
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.top)
            }
            
            Spacer()
            
            // Debug section
            VStack(alignment: .leading, spacing: 4) {
                Text("Debug Info")
                    .font(.caption)
                    .fontWeight(.bold)
                
                Text("Try using http:// instead of https:// if you experience connection issues")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("For Replit URLs, make sure your server is running")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .onAppear {
            isURLFieldFocused = true
        }
    }
}
//
//  LoginView.swift
//  loginboy
//
//  Created by Daniel Horsley on 13/05/2025.
//

