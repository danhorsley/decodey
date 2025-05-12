//
//  loginboyApp.swift
//  loginboy
//
//  Created by Daniel Horsley on 12/05/2025.
//

import SwiftUI

@main
struct AuthTestApp: App {
    @StateObject private var authService = AuthService()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(authService)
        }
    }
}
