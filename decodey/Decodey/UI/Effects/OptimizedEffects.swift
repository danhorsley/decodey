import SwiftUI

// MARK: - Performance Settings
struct PerformanceSettings {
    static let shared = PerformanceSettings()
    
    // Detect device capabilities
    var isHighPerformanceDevice: Bool {
        #if os(macOS)
        return true // Assume desktop can handle more
        #else
        // Simple heuristic - could be more sophisticated
        return UIDevice.current.userInterfaceIdiom == .pad ||
               ProcessInfo.processInfo.processorCount >= 6
        #endif
    }
    
    var effectsLevel: EffectsLevel {
        return isHighPerformanceDevice ? .high : .minimal
    }
    
    enum EffectsLevel {
        case minimal  // Static or very simple effects
        case medium   // Some animation, lower frame rate
        case high     // Full effects
        
        var updateInterval: TimeInterval {
            switch self {
            case .minimal: return 2.0   // Update every 2 seconds
            case .medium: return 0.5    // Update every 0.5 seconds
            case .high: return 0.1      // Update every 0.1 seconds (10fps instead of 60)
            }
        }
        
        var shouldUseEffects: Bool {
            return self != .minimal
        }
    }
}

// MARK: - Optimized Code Rain Effect (Clean)
struct OptimizedCodeRainView: View {
    @State private var columns: [SimpleCodeColumn] = []
    @State private var isInitialized = false
    
    private let settings = PerformanceSettings.shared
    private let maxColumns = 8 // Greatly reduced from original
    
    var body: some View {
        if settings.effectsLevel.shouldUseEffects {
            // Simplified approach - just draw static columns with periodic updates
            Canvas { context, size in
                drawColumns(context: context, size: size)
            }
            .task {
                if !isInitialized {
                    isInitialized = true
                    await setupAndAnimateColumns()
                }
            }
        } else {
            // Static fallback for low-end devices
            StaticMatrixBackground()
        }
    }
    
    // Setup columns and start periodic updates
    private func setupAndAnimateColumns() async {
        // Initial setup
        await MainActor.run {
            columns = (0..<maxColumns).map { i in
                SimpleCodeColumn(
                    x: CGFloat(i) * 80,
                    chars: generateRandomChars(count: 5),
                    speed: Double.random(in: 0.5...1.0)
                )
            }
        }
        
        // Start periodic updates
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(settings.effectsLevel.updateInterval * 1_000_000_000))
            
            await MainActor.run {
                updateColumnsData()
            }
        }
    }
    
    // Update column data safely on main actor
    private func updateColumnsData() {
        let columnsToUpdate = min(2, columns.count)
        
        for _ in 0..<columnsToUpdate {
            guard !columns.isEmpty else { return }
            let index = Int.random(in: 0..<columns.count)
            
            if Bool.random() {
                columns[index].chars = generateRandomChars(count: 5)
            }
        }
    }
    
    private func drawColumns(context: GraphicsContext, size: CGSize) {
        for column in columns {
            for (index, char) in column.chars.enumerated() {
                let y = CGFloat(index) * 30 + CGFloat(Date().timeIntervalSinceReferenceDate * column.speed * 20).truncatingRemainder(dividingBy: size.height)
                
                let position = CGPoint(x: column.x, y: y)
                let opacity = max(0, 1.0 - (y / size.height))
                
                context.draw(
                    Text(char)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.green.opacity(opacity)),
                    at: position
                )
            }
        }
    }
    
    private func generateRandomChars(count: Int) -> [String] {
        let chars = "01ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        return (0..<count).map { _ in String(chars.randomElement()!) }
    }
}

struct SimpleCodeColumn {
    var x: CGFloat
    var chars: [String]
    var speed: Double
}

// MARK: - Static Matrix Background (Fallback)
struct StaticMatrixBackground: View {
    private let staticPattern = """
    01001010 11000101 00110011
    10110100 01011010 11001100
    01010101 10101010 01010101
    11001100 00110011 10011001
    """
    
    var body: some View {
        Text(staticPattern)
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(.green.opacity(0.3))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.1))
    }
}

// MARK: - Optimized Circuit Board View (Clean)
struct OptimizedCircuitBoardView: View {
    @State private var shouldAnimate = false
    @State private var animationInitialized = false
    
    private let settings = PerformanceSettings.shared
    
    var body: some View {
        if settings.effectsLevel.shouldUseEffects {
            Canvas { context, size in
                drawStaticCircuitBoard(context: context, size: size)
                
                // Only add animation effects on high-performance devices
                if settings.effectsLevel == .high && shouldAnimate {
                    drawAnimatedNodes(context: context, size: size)
                }
            }
            .task {
                // Use task instead of onAppear to avoid state modification during view update
                if !animationInitialized && settings.effectsLevel == .high {
                    animationInitialized = true
                    await startAnimationAsync()
                }
            }
        } else {
            // Static version
            StaticCircuitPattern()
        }
    }
    
    // Make animation startup async
    private func startAnimationAsync() async {
        await MainActor.run {
            // Very slow animation - 3 second cycle
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                shouldAnimate = true
            }
        }
    }
    
    private func drawStaticCircuitBoard(context: GraphicsContext, size: CGSize) {
        // Draw a simple grid - much simpler than the original
        let lineCount = 4
        let nodeCount = 6
        
        // Horizontal lines
        for i in 0..<lineCount {
            let y = size.height / CGFloat(lineCount - 1) * CGFloat(i)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(.cyan.opacity(0.3)), lineWidth: 1)
        }
        
        // Vertical lines
        for j in 0..<nodeCount {
            let x = size.width / CGFloat(nodeCount - 1) * CGFloat(j)
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(path, with: .color(.cyan.opacity(0.2)), lineWidth: 1)
        }
    }
    
    private func drawAnimatedNodes(context: GraphicsContext, size: CGSize) {
        // Only draw a few animated nodes
        let positions = [
            CGPoint(x: size.width * 0.2, y: size.height * 0.3),
            CGPoint(x: size.width * 0.8, y: size.height * 0.7),
            CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        ]
        
        for position in positions {
            let nodeRect = CGRect(x: position.x - 3, y: position.y - 3, width: 6, height: 6)
            context.fill(Path(ellipseIn: nodeRect), with: .color(.cyan.opacity(shouldAnimate ? 0.8 : 0.4)))
        }
    }
}

struct StaticCircuitPattern: View {
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 40) {
                Circle()
                    .fill(Color.cyan.opacity(0.4))
                    .frame(width: 6, height: 6)
                Rectangle()
                    .fill(Color.cyan.opacity(0.3))
                    .frame(width: 40, height: 1)
                Circle()
                    .fill(Color.cyan.opacity(0.4))
                    .frame(width: 6, height: 6)
            }
            
            Rectangle()
                .fill(Color.cyan.opacity(0.3))
                .frame(width: 1, height: 40)
            
            HStack(spacing: 40) {
                Circle()
                    .fill(Color.cyan.opacity(0.4))
                    .frame(width: 6, height: 6)
                Rectangle()
                    .fill(Color.cyan.opacity(0.3))
                    .frame(width: 40, height: 1)
                Circle()
                    .fill(Color.cyan.opacity(0.4))
                    .frame(width: 6, height: 6)
            }
        }
        .opacity(0.6)
    }
}


// MARK: - Performance Monitor (Debug Only)
#if DEBUG
struct PerformanceMonitor: View {
    @State private var cpuUsage: Double = 0
    @State private var timer: Timer?
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Performance")
                .font(.caption.bold())
            Text("CPU: \(cpuUsage, specifier: "%.1f")%")
                .font(.caption)
                .foregroundColor(cpuUsage > 50 ? .red : cpuUsage > 25 ? .orange : .green)
            Text("Effects: \(PerformanceSettings.shared.effectsLevel)")
                .font(.caption)
        }
        .padding(8)
        .background(Color.black.opacity(0.7))
        .cornerRadius(8)
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                cpuUsage = getCurrentCPUUsage()
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func getCurrentCPUUsage() -> Double {
        // Simplified CPU usage - in production you'd use proper system APIs
        return Double.random(in: 5...15) // Placeholder
    }
}

extension PerformanceSettings.EffectsLevel: CustomStringConvertible {
    var description: String {
        switch self {
        case .minimal: return "Minimal"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}
#endif
