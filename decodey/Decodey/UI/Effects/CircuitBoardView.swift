import SwiftUI

struct CircuitBoardView: View {
    @State private var animate = false
    
    var body: some View {
        Canvas { context, size in
            // Parameters for the circuit
            let lineCount = 8
            let nodeCount = 12
            
            // Draw horizontal lines
            for i in 0..<lineCount {
                let y = size.height / CGFloat(lineCount - 1) * CGFloat(i)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                
                // Vary line thickness
                let lineWidth: CGFloat = i % 2 == 0 ? 1.0 : 0.5
                
                context.stroke(path, with: .color(.cyan.opacity(0.3)), lineWidth: lineWidth)
            }
            
            // Draw vertical lines
            for j in 0..<nodeCount {
                let x = size.width / CGFloat(nodeCount - 1) * CGFloat(j)
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                
                // Vary line thickness
                let lineWidth: CGFloat = j % 3 == 0 ? 1.0 : 0.5
                
                context.stroke(path, with: .color(.cyan.opacity(0.2)), lineWidth: lineWidth)
            }
            
            // Split the node drawing into smaller operations to avoid compiler complexity
            drawCircuitNodes(context: context, size: size, lineCount: lineCount, nodeCount: nodeCount)
        }
        .onAppear {
            // Start animation
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
    
    // Separated method to draw nodes to reduce expression complexity
    private func drawCircuitNodes(context: GraphicsContext, size: CGSize, lineCount: Int, nodeCount: Int) {
        for i in 0..<nodeCount {
            for j in 0..<lineCount {
                if (i + j) % 3 == 0 {
                    let x = size.width / CGFloat(nodeCount - 1) * CGFloat(i)
                    let y = size.height / CGFloat(lineCount - 1) * CGFloat(j)
                    
                    // Draw the node
                    let nodeRect = CGRect(x: x - 3, y: y - 3, width: 6, height: 6)
                    context.fill(Path(ellipseIn: nodeRect), with: .color(.cyan.opacity(0.6)))
                    
                    // Highlight some nodes with a glow
                    if (i * j) % 5 == 0 {
                        let glowRect = CGRect(x: x - 4, y: y - 4, width: 8, height: 8)
                        context.fill(Path(ellipseIn: glowRect), with: .color(.cyan.opacity(0.2 + (animate ? 0.4 : 0))))
                    }
                }
            }
        }
    }
}


