// PrivacyPolicyView.swift
// Decodey
//
// In-app privacy policy view

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background
            Color.gameBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Privacy Policy")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Last Updated
                        Text("Last updated: October 2025")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Main Privacy Statement
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.blue)
                                Text("Privacy First")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            
                            Text("Decodey does not collect, store, or have access to any of your personal data. We don't have servers, we don't track you, and we can't see your information.")
                                .font(.body)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        // What We Don't Do
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What We DON'T Do")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                bulletPoint("We don't collect any personal information", isNegative: true)
                                bulletPoint("We don't track your activity", isNegative: true)
                                bulletPoint("We don't have access to your data", isNegative: true)
                                bulletPoint("We don't run any servers or databases", isNegative: true)
                                bulletPoint("We don't use analytics or advertising", isNegative: true)
                            }
                        }
                        
                        Divider()
                        
                        // Local Storage Only
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Local Storage Only", systemImage: "iphone")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("All game data stays on YOUR device:")
                                .font(.body)
                                .fontWeight(.medium)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                bulletPoint("Game progress and statistics")
                                bulletPoint("Settings and preferences")
                                bulletPoint("Daily challenge completion")
                                bulletPoint("Tutorial status")
                            }
                            
                            Text("This data never leaves your device and we have no way to access it.")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                                .padding(.top, 8)
                        }
                        
                        Divider()
                        
                        // Game Center Section
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Apple Game Center Integration", systemImage: "gamecontroller")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("If you choose to sign in to Game Center:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    bulletPoint("Your game scores are sent directly to Apple's Game Center service")
                                    bulletPoint("Your Game Center nickname may appear on public leaderboards")
                                    bulletPoint("This is completely optional - you can play without Game Center")
                                    bulletPoint("This data goes directly to Apple, not to us")
                                    bulletPoint("We never receive or have access to your Game Center information")
                                }
                                
                                HStack {
                                    Text("Game Center is governed by")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Button(action: {
                                        if let url = URL(string: "https://www.apple.com/legal/privacy/") {
                                            #if os(iOS)
                                            UIApplication.shared.open(url)
                                            #elseif os(macOS)
                                            NSWorkspace.shared.open(url)
                                            #endif
                                        }
                                    }) {
                                        Text("Apple's Privacy Policy")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                            .underline()
                                    }
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        Divider()
                        
                        // Sign in with Apple
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Sign in with Apple (Optional)", systemImage: "applelogo")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("If you use Sign in with Apple:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                bulletPoint("Authentication is handled entirely by Apple")
                                bulletPoint("We only receive a unique identifier to save your progress")
                                bulletPoint("Your email and personal details are never shared with us")
                                bulletPoint("This is optional - you can play as a guest")
                            }
                        }
                        
                        Divider()
                        
                        // Children's Privacy
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Children's Privacy", systemImage: "figure.2.and.child.holdinghands")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Decodey is safe for all ages. Since we don't collect or have access to any personal data, children's privacy is inherently protected.")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        // Data Deletion
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Data Deletion", systemImage: "trash")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Since all data is stored locally on your device:")
                                .font(.body)
                                .fontWeight(.medium)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                bulletPoint("Deleting the app removes all game data")
                                bulletPoint("You can reset progress in the app settings")
                                bulletPoint("Game Center scores can be managed through your Apple ID settings")
                            }
                        }
                        
                        Divider()
                        
                        // Changes to Policy
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Changes to This Policy")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Any updates to this policy will be posted here with an updated date.")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        // Contact
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Contact", systemImage: "envelope")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Questions or concerns?")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                // Update with your actual email
                                if let url = URL(string: "mailto:privacy@mail.decodey.game") {
                                            #if os(iOS)
                                            UIApplication.shared.open(url)
                                            #elseif os(macOS)
                                            NSWorkspace.shared.open(url)
                                            #endif
                                }
                            }) {
                                HStack {
                                    Image(systemName: "mail")
                                    Text("privacy@mail.decodey.game")
                                        .underline()
                                }
                                .font(.body)
                                .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // GitHub Link
                        VStack(spacing: 12) {
                            Text("View on GitHub")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                if let url = URL(string: "https://github.com/danhorsley/decodey-privacy-policy") {
                                            #if os(iOS)
                                            UIApplication.shared.open(url)
                                            #elseif os(macOS)
                                            NSWorkspace.shared.open(url)
                                            #endif
                                }
                            }) {
                                Label("Open GitHub Version", systemImage: "arrow.up.right.square")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 20)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding()
                }
            }
            .frame(maxWidth: 600)
        }
    }
    
    private func bulletPoint(_ text: String, isNegative: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: isNegative ? "xmark.circle.fill" : "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(isNegative ? .red : .green)
            Text(text)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}
