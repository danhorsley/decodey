import Foundation
import SwiftUI

// Centralized error handling service
class ErrorHandler {
    static let shared = ErrorHandler()
    
    // MARK: - Error Logging
    
    func logError(_ error: Error, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let errorMessage = "\(fileName):\(line) - \(function): \(error.localizedDescription)"
        
        // Print to console - in a real app, send to your logging service
        print("🔴 ERROR: \(errorMessage)")
        
        // In production, you might want to send to a logging service
        #if !DEBUG
        // sendToLoggingService(errorMessage)
        #endif
    }
    
    // MARK: - User-Facing Error Presentation
    
    func presentError(_ error: Error, in context: ErrorPresentationContext) {
        let message = errorDescription(for: error)
        
        switch context {
        case .alert(let presenter):
            presenter.showErrorAlert(message: message)
        case .toast(let presenter):
            presenter.showErrorToast(message: message)
        case .inline(let presenter):
            presenter.showInlineError(message: message)
        case .silent:
            // Just log, don't present to user
            print("Silent error: \(message)")
        }
    }
    
    // MARK: - Error Classification and Description
    
    func errorDescription(for error: Error) -> String {
        // Check for localized errors first
        if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
            return description
        }
        
        // Handle specific error types
        switch error {
        case let networkError as NetworkError:
            return networkError.errorDescription ?? "Network error"
        case let repositoryError as RepositoryError:
            return repositoryError.errorDescription ?? "Data access error"
        case let keychain as KeychainManager.KeychainError:
            return keychainErrorDescription(keychain)
        default:
            // Generic fallback
            return "An error occurred: \(error.localizedDescription)"
        }
    }
    
    private func keychainErrorDescription(_ error: KeychainManager.KeychainError) -> String {
        switch error {
        case .duplicateEntry:
            return "Security error: Duplicate entry"
        case .noPassword:
            return "Security error: Password not found"
        case .unexpectedPasswordData:
            return "Security error: Unexpected password data"
        case .unhandledError(let status):
            return "Security error: \(status)"
        case .unknown(let status):
            return "Unknown security error: \(status)"
        }
    }
    
    // MARK: - RecoveryAction Types
    
    enum RecoveryAction {
        case retry
        case logout
        case ignore
        case customAction(() -> Void)
    }
    
    // MARK: - Error Presentation Contexts
    
    enum ErrorPresentationContext {
        case alert(AlertErrorPresenter)
        case toast(ToastErrorPresenter)
        case inline(InlineErrorPresenter)
        case silent
    }
    
    // MARK: - Error Presenter Protocols
    
    protocol AlertErrorPresenter {
        func showErrorAlert(message: String)
    }
    
    protocol ToastErrorPresenter {
        func showErrorToast(message: String)
    }
    
    protocol InlineErrorPresenter {
        func showInlineError(message: String)
    }
}

// Extension for common error handling in ViewModels
extension ErrorHandler {
    func handle<T>(_ result: Result<T, Error>, in context: ErrorPresentationContext) -> T? {
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            logError(error)
            presentError(error, in: context)
            return nil
        }
    }
    
    func handle(_ error: Error?, in context: ErrorPresentationContext) -> Bool {
        guard let error = error else { return false }
        
        logError(error)
        presentError(error, in: context)
        return true
    }
}

// SwiftUI View extension to simplify error showing
extension View {
    func errorAlert(isPresented: Binding<Bool>, error: Error?) -> some View {
        let errorMessage = error.map { ErrorHandler.shared.errorDescription(for: $0) } ?? "An unknown error occurred"
        return alert(isPresented: isPresented) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

//
//  ErrorHandler.swift
//  loginboy
//
//  Created by Daniel Horsley on 13/05/2025.
//

