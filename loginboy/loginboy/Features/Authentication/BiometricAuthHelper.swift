import SwiftUI

class BiometricAuthHelper {
    static let shared = BiometricAuthHelper()
    
    // Check if biometric auth is available
    func biometricAuthAvailable() -> (Bool, String) {
        #if os(iOS)
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let biometryType = context.biometryType
            switch biometryType {
            case .faceID:
                return (true, "Face ID")
            case .touchID:
                return (true, "Touch ID")
            default:
                return (false, "None")
            }
        } else {
            // Handle error
            let errorMessage = error?.localizedDescription ?? "Biometric authentication not available"
            return (false, errorMessage)
        }
        #else
        // For macOS, return false for now
        return (false, "Not supported on this platform")
        #endif
    }
}

//
//  BiometricAuthHelper.swift
//  loginboy
//
//  Created by Daniel Horsley on 13/05/2025.
//

