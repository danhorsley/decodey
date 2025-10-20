// MARK: - Quote Disclaimer View
import SwiftUI

struct QuoteDisclaimerView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background
            Color.gameBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Quote Information")
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
                        // Disclaimer Section
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Usage Disclaimer", systemImage: "info.circle")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("All quotes used in this game are attributed where known and are intended for educational and entertainment purposes only. No endorsement by the original authors or rights holders is implied.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Divider()
                        
                        // Contact Section
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Removal Requests", systemImage: "envelope")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("If you would like to request the removal of a specific quote, please contact us at:")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            // Email as a button/link
                            Button(action: {
                                if let url = URL(string: "mailto:quotes@mail.decodey.game") {
                                    #if os(iOS)
                                    UIApplication.shared.open(url)
                                    #elseif os(macOS)
                                    NSWorkspace.shared.open(url)
                                    #endif
                                }
                            }) {
                                HStack {
                                    Image(systemName: "mail")
                                    Text("quotes@mail.decodey.game")
                                        .underline()
                                }
                                .font(.body)
                                .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                            
                            Text("We will review all removal requests and take appropriate action within a reasonable timeframe.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Divider()
                        
                        // Additional Info
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Content Sources", systemImage: "books.vertical")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Our quote collection includes:")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                bulletPoint("200+ free classic quotes")
                                bulletPoint("Public domain literature")
                                bulletPoint("Historical texts and speeches")
                                bulletPoint("Classical philosophy")
                                bulletPoint("Religious texts (King James Bible)")
                                bulletPoint("Famous wit and wisdom")
                            }
                        }
                    }
                    .padding()
                }
            }
            .frame(maxWidth: 600)
        }
    }
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.secondary)
            Text(text)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

