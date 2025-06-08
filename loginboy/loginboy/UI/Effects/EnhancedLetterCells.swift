// EnhancedLetterCells.swift - Complete rewrite
import SwiftUI

// MARK: - Enhanced Encrypted Letter Cell
struct EnhancedEncryptedLetterCell: View {
   let letter: Character
   let isSelected: Bool
   let isGuessed: Bool
   let frequency: Int
   let action: () -> Void
   
   @Environment(\.colorScheme) var colorScheme
   @State private var isPressed = false
   @State private var showRipple = false
   
   private let colors = ColorSystem.shared
   private let fonts = FontSystem.shared
   
   var body: some View {
       Button(action: action) {
           ZStack {
               if colorScheme == .dark {
                   // Laser projection style
                   LaserKeyShape(isPressed: isPressed || isSelected)
                       .opacity(isGuessed ? 0.3 : 1.0)
               } else {
                   // Apple keyboard style
                   AppleKeyShape(isPressed: isPressed || isSelected)
                       .opacity(isGuessed ? 0.5 : 1.0)
               }
               
               // Key content
               VStack(spacing: 0) {
                   ZStack {
                       // Main letter
                       Text(String(letter))
                           .font(.system(size: 20, weight: .medium, design: .monospaced))
                           .foregroundColor(letterColor)
                       
                       // Frequency indicator (top-right superscript)
                       if frequency > 1 && !isGuessed {
                           VStack {
                               HStack {
                                   Spacer()
                                   Text("\(frequency)")
                                       .font(.system(size: 9, weight: .regular, design: .monospaced))
                                       .foregroundColor(letterColor.opacity(0.6)) // change opacity of freq
                                       .offset(x: -4, y: -2) // move frequency num around
                               }
                               Spacer()
                           }
                       }
                   }
               }
               .offset(y: isPressed || isSelected ? 0 : -1)
               
               // Holographic ripple effect for dark mode
               if colorScheme == .dark && showRipple {
                   LaserRippleEffect()
               }
               
               // Selected state border
               if isSelected {
                   RoundedRectangle(cornerRadius: 8)
                       .stroke(
                           colors.accent,
                           lineWidth: colorScheme == .dark ? 1.5 : 2
                       )
                       .shadow(
                           color: colors.accent.opacity(colorScheme == .dark ? 0.8 : 0.3),
                           radius: colorScheme == .dark ? 10 : 4
                       )
               }
           }
           .frame(width: 56, height: 44) // Keyboard key proportions
           .scaleEffect(isPressed ? 0.95 : 1.0)
           .animation(.easeOut(duration: 0.1), value: isPressed)
       }
       .buttonStyle(PlainButtonStyle())
       .disabled(isGuessed)
       .onLongPressGesture(
           minimumDuration: 0,
           maximumDistance: .infinity,
           pressing: { pressing in
               isPressed = pressing
               if pressing && colorScheme == .dark {
                   showRipple = true
                   DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                       showRipple = false
                   }
               }
           },
           perform: {}
       )
   }
   
   private var letterColor: Color {
       if isSelected {
           // Use subtle grays for contrast
           return colorScheme == .dark ? Color.gray : Color.gray.opacity(0.8)
       } else if isGuessed {
           return colors.guessedText(for: colorScheme)
       } else {
           // Match the encrypted text color from the display
           return colors.encryptedColor(for: colorScheme)
       }
   }
}

// MARK: - Enhanced Guess Letter Cell
struct EnhancedGuessLetterCell: View {
   let letter: Character
   let isUsed: Bool
   let isIncorrectForSelected: Bool
   let action: () -> Void
   
   @Environment(\.colorScheme) var colorScheme
   @State private var isPressed = false
   @State private var showRipple = false
   
   private let colors = ColorSystem.shared
   private let fonts = FontSystem.shared
   
   var body: some View {
       Button(action: action) {
           ZStack {
               if colorScheme == .dark {
                   LaserKeyShape(isPressed: isPressed)
                       .opacity(isUsed || isIncorrectForSelected ? 0.3 : 1.0)
               } else {
                   AppleKeyShape(isPressed: isPressed)
                       .opacity(isUsed || isIncorrectForSelected ? 0.5 : 1.0)
               }
               
               // Letter
               Text(String(letter))
                   .font(.system(size: 20, weight: .medium, design: .monospaced))
                   .foregroundColor(letterColor)
                   .offset(y: isPressed ? 0 : -1)
               
               // Holographic ripple
               if colorScheme == .dark && showRipple {
                   LaserRippleEffect()
               }
               
               // Red X for incorrect
               if isIncorrectForSelected {
                   Image(systemName: "xmark")
                       .font(.system(size: 18, weight: .semibold))
                       .foregroundColor(.red.opacity(0.8))
               }
           }
           .frame(width: 56, height: 44)
           .scaleEffect(isPressed ? 0.95 : 1.0)
           .animation(.easeOut(duration: 0.1), value: isPressed)
       }
       .buttonStyle(PlainButtonStyle())
       .disabled(isUsed || isIncorrectForSelected)
       .onLongPressGesture(
           minimumDuration: 0,
           maximumDistance: .infinity,
           pressing: { pressing in
               isPressed = pressing
               if pressing && colorScheme == .dark {
                   showRipple = true
                   DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                       showRipple = false
                   }
               }
           },
           perform: {}
       )
   }
   
   private var letterColor: Color {
       if isUsed || isIncorrectForSelected {
           return colors.guessedText(for: colorScheme)
       } else {
           // Match the guess text color from the display
           return colors.guessColor(for: colorScheme)
       }
   }
}

// MARK: - Laser Projection Key Shape (Dark Mode)
struct LaserKeyShape: View {
   let isPressed: Bool
   private let terminalGreen = Color(hex: "4cc9f0")
   
   var body: some View {
       ZStack {
           // Base projection area
           RoundedRectangle(cornerRadius: 8)
               .fill(
                   LinearGradient(
                       colors: [
                           Color.black.opacity(0.6),
                           Color.black.opacity(0.8)
                       ],
                       startPoint: .top,
                       endPoint: .bottom
                   )
               )
           
           // Laser edge glow
           RoundedRectangle(cornerRadius: 8)
               .stroke(
                   LinearGradient(
                       colors: [
                           ColorSystem.shared.encryptedColor(for: .dark).opacity(isPressed ? 0.9 : 0.7),
                           ColorSystem.shared.encryptedColor(for: .dark).opacity(isPressed ? 0.7 : 0.5)
                       ],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing
                   ),
                   lineWidth: isPressed ? 1.5 : 1
               )
               .shadow(color: ColorSystem.shared.encryptedColor(for: .dark).opacity(0.5), radius: isPressed ? 8 : 4)
           
           // Inner glow
           if !isPressed {
               RoundedRectangle(cornerRadius: 7)
                   .fill(
                       RadialGradient(
                           colors: [
                            ColorSystem.shared.encryptedColor(for: .dark).opacity(0.05),
                               Color.clear
                           ],
                           center: .center,
                           startRadius: 0,
                           endRadius: 30
                       )
                   )
                   .padding(1)
           }
       }
   }
}

// MARK: - Apple Keyboard Key Shape (Light Mode)
struct AppleKeyShape: View {
   let isPressed: Bool
   
   var body: some View {
       ZStack {
           // Shadow layer
           if !isPressed {
               RoundedRectangle(cornerRadius: 8)
                   .fill(Color.black.opacity(0.08))
                   .offset(y: 1)
           }
           
           // Main key
           RoundedRectangle(cornerRadius: 8)
               .fill(
                   LinearGradient(
                       colors: [
                           Color.white,
                           Color(hex: "F8F8F8")
                       ],
                       startPoint: .top,
                       endPoint: .bottom
                   )
               )
               .overlay(
                   RoundedRectangle(cornerRadius: 8)
                       .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
               )
       }
   }
}

// MARK: - Laser Ripple Effect
struct LaserRippleEffect: View {
   @State private var scale: CGFloat = 0.8
   @State private var opacity: Double = 0.8
   private let terminalGreen = Color(hex: "4cc9f0")
   
   var body: some View {
       RoundedRectangle(cornerRadius: 8)
           .stroke(terminalGreen, lineWidth: 1)
           .scaleEffect(scale)
           .opacity(opacity)
           .onAppear {
               withAnimation(.easeOut(duration: 0.3)) {
                   scale = 1.2
                   opacity = 0
               }
           }
           .allowsHitTesting(false)
   }
}
