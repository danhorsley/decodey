import SwiftUI

struct CodeRainView: View {
    @Binding var columns: [CodeColumn]
    // Remove the state variable that's causing issues
    // @State private var yOffset: CGFloat = 0
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                // Calculate animation values directly
                let duration: Double = 10.0
                let date = timeline.date
                let time = date.timeIntervalSinceReferenceDate
                let yOffset = CGFloat(time.truncatingRemainder(dividingBy: duration) / duration) * 50.0
                
                // Draw all columns using the calculated offset
                drawAllColumns(context: context, size: size, yOffset: yOffset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // Update method signature to accept yOffset as a parameter
    private func drawAllColumns(context: GraphicsContext, size: CGSize, yOffset: CGFloat) {
        // Process each column
        for column in columns {
            drawColumn(context: context, size: size, column: column, yOffset: yOffset)
        }
    }
    
    // Update this method as well
    private func drawColumn(context: GraphicsContext, size: CGSize, column: CodeColumn, yOffset: CGFloat) {
        // For each character in the column
        for (index, char) in column.chars.enumerated() {
            // Calculate vertical position with animation, passing yOffset
            let position = calculatePosition(index: index, column: column, size: size, yOffset: yOffset)
            
            // Calculate fade effect based on position
            let opacity = calculateOpacity(position.y, size: size)
            
            // Only draw if visible
            if opacity > 0.01 {
                drawCharacter(context: context, char: char, position: position, column: column, opacity: opacity)
            }
        }
    }
    
    // Update to accept yOffset as parameter
    private func calculatePosition(index: Int, column: CodeColumn, size: CGSize, yOffset: CGFloat) -> CGPoint {
        let baseY = CGFloat(index) * 20.0
        let animatedY = (baseY + yOffset * column.speed * 10.0).truncatingRemainder(dividingBy: size.height + 100) - 50
        return CGPoint(x: column.position, y: animatedY)
    }
    
    // Calculate opacity based on y position (fade at edges)
    private func calculateOpacity(_ y: CGFloat, size: CGSize) -> Double {
        // Fade at top and bottom of screen
        let distance = abs(y - size.height / 2) / (size.height / 2)
        return max(0, min(1, 1.0 - distance))
    }
    
    // Draw a single character
    private func drawCharacter(context: GraphicsContext, char: String, position: CGPoint, column: CodeColumn, opacity: Double) {
        // Create the text view with styling
        let text = Text(char).foregroundColor(characterColor(for: column.hue, opacity: opacity))
        
        // Draw at calculated position
        context.draw(text, at: position)
    }
    
    // Color for character
    private func characterColor(for hue: CGFloat, opacity: Double) -> Color {
        return Color(hue: hue, saturation: 0.8, brightness: 0.9).opacity(opacity)
    }
}

// Data structure for code rain columns
struct CodeColumn {
    var position: CGFloat
    var speed: Double
    var chars: [String]
    var hue: CGFloat
}
//
//  CodeRainView.swift
//  loginboy
//
//  Created by Daniel Horsley on 13/05/2025.
//

