// TextAlignmentManager.swift
// Handles all text alignment logic for encrypted/solution text display

import SwiftUI
import os.log

final class TextAlignmentManager: ObservableObject {
    private let logger = Logger(subsystem: "com.decodey.app", category: "TextAlignment")
    
    // MARK: - Aligned Text Container
    struct AlignedText: Equatable {
        let encrypted: String
        let solution: String
        let isValid: Bool
        
        init(encrypted: String, solution: String) {
            self.encrypted = encrypted
            self.solution = solution
            self.isValid = Self.verify(encrypted: encrypted, solution: solution)
        }
        
        static func verify(encrypted: String, solution: String) -> Bool {
            // Basic length check
            guard encrypted.count == solution.count else {
                return false
            }
            
            // Verify character-by-character alignment
            return encrypted.indices.allSatisfy { index in
                let e = encrypted[index]
                let s = solution[index]
                // Both should be letters or both should be non-letters
                return (!e.isLetter && !s.isLetter) || (e.isLetter && s.isLetter)
            }
        }
    }
    
    // MARK: - Main Processing Method
    func processQuoteForDisplay(_ text: String, cipher: [Character: Character]) -> AlignedText {
        let uppercasedText = text.uppercased()
        
        // Process both strings in lock-step to ensure alignment
        var encryptedChars: [Character] = []
        var solutionChars: [Character] = []
        
        // Note: cipher is [encrypted: original], so we need to reverse it for encryption
        let reversedCipher = Dictionary(uniqueKeysWithValues: cipher.map { ($1, $0) })
        
        for char in uppercasedText {
            if char.isLetter {
                // Apply cipher - use reversed mapping to encrypt
                let encrypted = reversedCipher[char] ?? char
                encryptedChars.append(encrypted)
                solutionChars.append(char)
            } else {
                // Non-letters stay the same in both
                encryptedChars.append(char)
                solutionChars.append(char)
            }
        }
        
        let result = AlignedText(
            encrypted: String(encryptedChars),
            solution: String(solutionChars)
        )
        
        // Log if we detect misalignment
        if !result.isValid {
            logger.error("Text alignment verification failed!")
            logger.debug("Encrypted: \(result.encrypted)")
            logger.debug("Solution: \(result.solution)")
            
            // Attempt recovery
            return recoverAlignment(text: uppercasedText, cipher: cipher)
        }
        
        return result
    }
    
    // MARK: - Update Methods for GameState
    func atomicUpdate(
        encrypted: inout String,
        solution: inout String,
        with alignedText: AlignedText
    ) {
        // Ensure we're on main thread for UI updates
        assert(Thread.isMainThread, "Text updates must occur on main thread")
        
        // Update both values atomically
        encrypted = alignedText.encrypted
        solution = alignedText.solution
        
        #if DEBUG
        // Debug verification
        if !alignedText.isValid {
            print("⚠️ Warning: Updating with invalid aligned text")
        }
        #endif
    }
    
    // MARK: - Recovery Method
    private func recoverAlignment(text: String, cipher: [Character: Character]) -> AlignedText {
        logger.warning("Attempting alignment recovery...")
        
        // Reverse the cipher for encryption
        let reversedCipher = Dictionary(uniqueKeysWithValues: cipher.map { ($1, $0) })
        
        // Strip all non-letters and rebuild
        let lettersOnly = text.filter { $0.isLetter }
        var encryptedLetters = ""
        var solutionLetters = ""
        
        for char in lettersOnly {
            let encrypted = reversedCipher[char] ?? char
            encryptedLetters.append(encrypted)
            solutionLetters.append(char)
        }
        
        // Now re-insert non-letters at original positions
        var encryptedResult = ""
        var solutionResult = ""
        var letterIndex = 0
        
        for char in text {
            if char.isLetter && letterIndex < encryptedLetters.count {
                let idx = encryptedLetters.index(encryptedLetters.startIndex, offsetBy: letterIndex)
                encryptedResult.append(encryptedLetters[idx])
                solutionResult.append(solutionLetters[idx])
                letterIndex += 1
            } else {
                encryptedResult.append(char)
                solutionResult.append(char)
            }
        }
        
        let recovered = AlignedText(encrypted: encryptedResult, solution: solutionResult)
        
        if recovered.isValid {
            logger.info("Alignment recovery successful")
        } else {
            logger.error("Alignment recovery failed - using fallback")
            // Last resort: just use the original text for both
            return AlignedText(encrypted: text, solution: text)
        }
        
        return recovered
    }
    
    // MARK: - Preload Fonts (call in GameView.onAppear)
    func preloadFonts() {
        // Force font loading to prevent render-time alignment issues
        _ = Font.custom("Courier New", size: 16)
        _ = Font.system(size: 16, weight: .regular, design: .monospaced)
    }
}

// MARK: - Extension for Easy Integration
extension TextAlignmentManager {
    /// Convenience method for GameState to update its display
    func updateGameDisplay(
        gameState: GameState,
        text: String,
        cipher: [Character: Character]
    ) {
        let aligned = processQuoteForDisplay(text, cipher: cipher)
        
        DispatchQueue.main.async {
            // Update the current game's encrypted and solution
            if var game = gameState.currentGame {
                game.encrypted = aligned.encrypted
                game.solution = aligned.solution
                gameState.currentGame = game
            }
        }
    }
}
