import SwiftUI
import CoreData

/// A view for showing the data migration process from Realm to Core Data
struct MigrationView: View {
    // Access migration controller from the environment
    @EnvironmentObject var migration: MigrationController
    
    // Environment state
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background
            backgroundView
            
            // Content
            VStack(spacing: 30) {
                titleSection
                
                descriptionSection
                
                progressSection
                
                actionButton
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
            )
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut, value: migration.isMigrating)
        .animation(.easeInOut, value: migration.progress)
    }
    
    // MARK: - View Components
    
    private var backgroundView: some View {
        ZStack {
            // Base background
            Color(colorScheme == .dark ? UIColor.systemBackground : UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            // Matrix-inspired effect for darker mode
            if colorScheme == .dark {
                MatrixInspiredBackground()
                    .opacity(0.2)
                    .ignoresSafeArea()
            }
        }
    }
    
    private var titleSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding()
            
            Text("Data Migration")
                .font(.largeTitle)
                .fontWeight(.bold)
        }
    }
    
    private var descriptionSection: some View {
        VStack(spacing: 16) {
            Text("We're updating the app's database to a new format.")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("This is a one-time process to improve performance and reliability. Please don't close the app during this process.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: 15) {
            // Progress bar
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 12)
                
                // Progress indicator
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.7)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(12, CGFloat(migration.progress) * UIScreen.main.bounds.width * 0.7), height: 12)
                    .animation(.spring(), value: migration.progress)
            }
            .frame(height: 12)
            
            // Progress percentage
            Text("\(Int(migration.progress * 100))%")
                .font(.headline)
                .foregroundColor(.primary)
                .monospacedDigit()
            
            // Status message
            Text(migration.message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(height: 40)
                .fixedSize(horizontal: false, vertical: true)
            
            // Error message if any
            if let error = migration.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical)
    }
    
    private var actionButton: some View {
        Button(action: {
            if !migration.isMigrating {
                migration.startMigration()
            }
        }) {
            HStack {
                Text(migration.isMigrating ? "Migrating..." : "Start Migration")
                    .fontWeight(.semibold)
                
                if migration.isMigrating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                        .padding(.leading, 4)
                }
            }
            .frame(minWidth: 200)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(migration.isMigrating ? Color.gray : Color.blue)
            )
            .foregroundColor(.white)
        }
        .disabled(migration.isMigrating)
        .opacity(migration.isMigrating ? 0.7 : 1.0)
    }
}

// MARK: - Matrix-Inspired Background
struct MatrixInspiredBackground: View {
    // Number of matrix columns
    let columnCount = 20
    
    // State for animation
    @State private var columns: [MatrixColumn] = []
    @State private var animationPhase = 0.0
    
    // Matrix characters
    private let matrixChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+-=[]{}|;:,.<>/?`~"
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                // Update animation phase
                let now = timeline.date.timeIntervalSinceReferenceDate
                animationPhase = now.truncatingRemainder(dividingBy: 10)
                
                // Make sure we have columns
                if columns.isEmpty {
                    initializeColumns(size: size)
                }
                
                // Draw all columns
                for column in columns {
                    drawColumn(context: context, size: size, column: column)
                }
            }
        }
        .onAppear {
            // Initialize columns on appear (will be populated in Canvas draw)
        }
    }
    
    // Initialize matrix columns
    private func initializeColumns(size: CGSize) {
        columns = (0..<columnCount).map { _ in
            let x = CGFloat.random(in: 0..<size.width)
            let speed = Double.random(in: 0.5...2.0)
            let length = Int.random(in: 5...15)
            
            return MatrixColumn(
                x: x,
                speed: speed,
                chars: (0..<length).map { _ in
                    let char = String(matrixChars.randomElement()!)
                    let brightness = Double.random(in: 0.3...1.0)
                    return MatrixChar(value: char, brightness: brightness)
                }
            )
        }
    }
    
    // Draw a single matrix column
    private func drawColumn(context: GraphicsContext, size: CGSize, column: MatrixColumn) {
        let yOffset = size.height * (animationPhase * column.speed).truncatingRemainder(dividingBy: 1)
        
        for (i, matrixChar) in column.chars.enumerated() {
            let fontSize: CGFloat = 14
            let spacing = fontSize * 1.5
            
            let y = (yOffset + CGFloat(i) * spacing).truncatingRemainder(dividingBy: size.height)
            
            // Draw the character
            let text = Text(matrixChar.value)
                .font(.system(size: fontSize, design: .monospaced))
                .foregroundColor(Color.green.opacity(matrixChar.brightness))
            
            context.draw(text, at: CGPoint(x: column.x, y: y))
        }
    }
    
    // Data structures for matrix effect
    struct MatrixColumn {
        let x: CGFloat
        let speed: Double
        let chars: [MatrixChar]
    }
    
    struct MatrixChar {
        let value: String
        let brightness: Double
    }
}

// MARK: - Preview
struct MigrationView_Previews: PreviewProvider {
    static var previews: some View {
        MigrationView()
            .environmentObject(previewMigrationController())
            .preferredColorScheme(.dark)
        
        MigrationView()
            .environmentObject(previewMigrationController(migrating: true))
            .preferredColorScheme(.light)
    }
    
    static func previewMigrationController(migrating: Bool = false) -> MigrationController {
        let controller = MigrationController()
        controller.isMigrationNeeded = true
        
        if migrating {
            controller.isMigrating = true
            controller.progress = 0.65
            controller.message = "Converting user data..."
        }
        
        return controller
    }
}//
//  MigrationView.swift
//  loginboy
//
//  Created by Daniel Horsley on 19/05/2025.
//

