// NavigationViewWrapper.swift
// Decodey
//
// Cross-platform navigation wrapper for iOS and macOS compatibility

import SwiftUI

struct NavigationViewWrapper<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        #if os(iOS)
        NavigationView {
            content
        }
        .navigationViewStyle(StackNavigationViewStyle())
        #else
        // For macOS, don't use NavigationView at all
        content
            .frame(minWidth: 600, idealWidth: 800, maxWidth: .infinity,
                   minHeight: 500, idealHeight: 700, maxHeight: .infinity)
        #endif
    }
}
