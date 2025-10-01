import SwiftUI

// Simple InfoRow structure for displaying key-value pairs
struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

//
//  InfoRow.swift
//  loginboy
//
//  Created by Daniel Horsley on 13/05/2025.
//

